alter table public.profiles
  add column if not exists is_disabled boolean not null default false;

create index if not exists profiles_is_disabled_idx
  on public.profiles (is_disabled);

create or replace function public.delete_post_with_dependencies(
  p_post_id uuid,
  p_allow_admin boolean default false
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  select p.user_id
  into v_owner_id
  from public.posts p
  where p.id = p_post_id;

  if v_owner_id is null then
    raise exception 'Post not found';
  end if;

  if p_allow_admin then
    if not exists (
      select 1
      from public.profiles admin_profile
      where admin_profile.id = auth.uid()
        and admin_profile.is_admin = true
    ) then
      raise exception 'Admin access required';
    end if;
  elsif v_owner_id <> auth.uid() then
    raise exception 'You can only delete your own posts';
  end if;

  delete from public.notifications
  where post_id = p_post_id
     or comment_id in (
       select id
       from public.post_comments
       where post_id = p_post_id
     );

  delete from public.post_reports
  where post_id = p_post_id;

  delete from public.offer_conversations
  where post_id = p_post_id;

  delete from public.post_comment_likes
  where comment_id in (
    select id
    from public.post_comments
    where post_id = p_post_id
  );

  delete from public.post_comments
  where post_id = p_post_id;

  delete from public.post_likes
  where post_id = p_post_id;

  delete from public.posts
  where id = p_post_id;

  if not found then
    raise exception 'Post not found';
  end if;
end;
$$;

grant execute on function public.delete_post_with_dependencies(uuid, boolean) to authenticated;

create or replace function public.delete_own_post(
  p_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.delete_post_with_dependencies(p_post_id, false);
end;
$$;

grant execute on function public.delete_own_post(uuid) to authenticated;

create or replace function public.admin_soft_delete_post(
  p_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.delete_post_with_dependencies(p_post_id, true);
end;
$$;

grant execute on function public.admin_soft_delete_post(uuid) to authenticated;

create or replace function public.can_message_me(
  p_other_user_id uuid
)
returns boolean
language sql
security definer
set search_path = public
as $$
  select
    auth.uid() is not null
    and p_other_user_id is not null
    and p_other_user_id <> auth.uid()
    and exists (
      select 1
      from public.profiles me
      join public.profiles other on other.id = p_other_user_id
      where me.id = auth.uid()
        and coalesce(me.is_disabled, false) = false
        and coalesce(other.is_disabled, false) = false
    )
    and exists (
      select 1
      from public.follows f1
      join public.follows f2
        on f2.follower_id = p_other_user_id
       and f2.followed_profile_id = auth.uid()
       and f2.status = 'accepted'
      where f1.follower_id = auth.uid()
        and f1.followed_profile_id = p_other_user_id
        and f1.status = 'accepted'
    )
    and not exists (
      select 1
      from public.user_blocks ub
      where (ub.blocker_id = auth.uid() and ub.blocked_id = p_other_user_id)
         or (ub.blocker_id = p_other_user_id and ub.blocked_id = auth.uid())
    );
$$;

grant execute on function public.can_message_me(uuid) to authenticated;

create or replace function public.get_or_create_conversation(
  p_other_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_a uuid;
  v_b uuid;
  v_conv_id uuid;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  if p_other_user_id is null or p_other_user_id = v_me then
    raise exception 'Invalid chat target';
  end if;

  if not exists (
    select 1
    from public.profiles me
    join public.profiles other on other.id = p_other_user_id
    where me.id = v_me
      and coalesce(me.is_disabled, false) = false
      and coalesce(other.is_disabled, false) = false
  ) then
    raise exception 'Chat unavailable';
  end if;

  if exists (
    select 1
    from public.user_blocks ub
    where (ub.blocker_id = v_me and ub.blocked_id = p_other_user_id)
       or (ub.blocker_id = p_other_user_id and ub.blocked_id = v_me)
  ) then
    raise exception 'Chat unavailable';
  end if;

  v_a := least(v_me, p_other_user_id);
  v_b := greatest(v_me, p_other_user_id);

  select c.id
  into v_conv_id
  from public.conversations c
  where c.user1 = v_a
    and c.user2 = v_b
  limit 1;

  if v_conv_id is not null then
    return v_conv_id;
  end if;

  begin
    insert into public.conversations (user1, user2)
    values (v_a, v_b)
    returning id into v_conv_id;
  exception
    when unique_violation then
      select c.id
      into v_conv_id
      from public.conversations c
      where c.user1 = v_a
        and c.user2 = v_b
      limit 1;
  end;

  return v_conv_id;
end;
$$;

grant execute on function public.get_or_create_conversation(uuid) to authenticated;

create or replace function public.get_or_create_offer_conversation(
  p_post_id uuid,
  p_other_user_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_me uuid := auth.uid();
  v_post record;
  v_conv_id uuid;
begin
  if v_me is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.profiles me
    join public.profiles other on other.id = p_other_user_id
    where me.id = v_me
      and coalesce(me.is_disabled, false) = false
      and coalesce(other.is_disabled, false) = false
  ) then
    raise exception 'Offer chat unavailable';
  end if;

  if exists (
    select 1
    from public.user_blocks ub
    where (ub.blocker_id = v_me and ub.blocked_id = p_other_user_id)
       or (ub.blocker_id = p_other_user_id and ub.blocked_id = v_me)
  ) then
    raise exception 'Offer chat unavailable';
  end if;

  select p.id, p.user_id, p.post_type
  into v_post
  from public.posts p
  join public.profiles seller on seller.id = p.user_id
  where p.id = p_post_id
    and p.post_type in ('market', 'service_offer', 'service_request')
    and coalesce(seller.is_disabled, false) = false;

  if not found then
    raise exception 'Listing not found';
  end if;

  if v_post.user_id = v_me then
    raise exception 'You cannot start an offer chat on your own listing';
  end if;

  if v_post.user_id <> p_other_user_id then
    raise exception 'Offer chats must target the listing owner';
  end if;

  insert into public.offer_conversations (post_id, buyer_id, seller_id)
  values (p_post_id, v_me, v_post.user_id)
  on conflict (post_id, buyer_id, seller_id) do update
    set updated_at = now()
  returning id into v_conv_id;

  return v_conv_id;
end;
$$;

grant execute on function public.get_or_create_offer_conversation(uuid, uuid) to authenticated;

create or replace function public.admin_delete_user_account(
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_avatar_objects text[];
  v_portfolio_objects text[];
  v_post_media_objects text[];
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (
    select 1
    from public.profiles admin_profile
    where admin_profile.id = auth.uid()
      and admin_profile.is_admin = true
  ) then
    raise exception 'Admin access required';
  end if;

  if p_user_id is null then
    raise exception 'User id is required';
  end if;

  if p_user_id = auth.uid() then
    raise exception 'You cannot delete your own account';
  end if;

  if not exists (
    select 1
    from auth.users
    where id = p_user_id
  ) then
    raise exception 'User not found';
  end if;

  select coalesce(array_agg(name), array[]::text[])
  into v_avatar_objects
  from storage.objects
  where bucket_id = 'avatars'
    and name like p_user_id::text || '/%';

  select coalesce(array_agg(name), array[]::text[])
  into v_portfolio_objects
  from storage.objects
  where bucket_id = 'portfolio-images'
    and name like 'portfolio/' || p_user_id::text || '/%';

  select coalesce(array_agg(name), array[]::text[])
  into v_post_media_objects
  from storage.objects
  where bucket_id = 'post-images'
    and name like p_user_id::text || '/%';

  delete from public.notifications
  where recipient_id = p_user_id
     or actor_id = p_user_id;

  delete from public.user_reports
  where reporter_id = p_user_id
     or reported_user_id = p_user_id;

  delete from public.post_reports
  where reporter_id = p_user_id
     or post_id in (
       select id
       from public.posts
       where user_id = p_user_id
     );

  delete from public.user_blocks
  where blocker_id = p_user_id
     or blocked_id = p_user_id;

  delete from public.follows
  where follower_id = p_user_id
     or followed_profile_id = p_user_id;

  delete from public.profile_portfolio
  where profile_id = p_user_id;

  delete from public.post_comment_likes
  where user_id = p_user_id
     or comment_id in (
       select id
       from public.post_comments
       where user_id = p_user_id
     );

  delete from public.post_comments
  where user_id = p_user_id
     or post_id in (
       select id
       from public.posts
       where user_id = p_user_id
     );

  delete from public.post_likes
  where user_id = p_user_id
     or post_id in (
       select id
       from public.posts
       where user_id = p_user_id
     );

  delete from public.messages
  where sender_id = p_user_id
     or conversation_id in (
       select id
       from public.conversations
       where user1 = p_user_id
          or user2 = p_user_id
     );

  delete from public.conversations
  where user1 = p_user_id
     or user2 = p_user_id;

  delete from public.offer_messages
  where sender_id = p_user_id
     or conversation_id in (
       select id
       from public.offer_conversations
       where buyer_id = p_user_id
          or seller_id = p_user_id
     );

  delete from public.offer_conversations
  where buyer_id = p_user_id
     or seller_id = p_user_id;

  delete from public.posts
  where user_id = p_user_id;

  delete from public.profiles
  where id = p_user_id;

  if array_length(v_avatar_objects, 1) is not null then
    delete from storage.objects
    where bucket_id = 'avatars'
      and name = any(v_avatar_objects);
  end if;

  if array_length(v_portfolio_objects, 1) is not null then
    delete from storage.objects
    where bucket_id = 'portfolio-images'
      and name = any(v_portfolio_objects);
  end if;

  if array_length(v_post_media_objects, 1) is not null then
    delete from storage.objects
    where bucket_id = 'post-images'
      and name = any(v_post_media_objects);
  end if;

  delete from auth.users
  where id = p_user_id;
end;
$$;

grant execute on function public.admin_delete_user_account(uuid) to authenticated;
