create or replace function public.admin_delete_user_account_data_only(
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
end;
$$;

grant execute on function public.admin_delete_user_account_data_only(uuid) to authenticated;
