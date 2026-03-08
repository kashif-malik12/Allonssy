alter table public.post_comments
  add column if not exists parent_comment_id uuid references public.post_comments(id) on delete cascade;

create index if not exists post_comments_parent_comment_id_idx
  on public.post_comments(parent_comment_id);

create table if not exists public.post_comment_likes (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.post_comments(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (comment_id, user_id)
);

create index if not exists post_comment_likes_comment_id_idx
  on public.post_comment_likes(comment_id);

alter table public.post_comment_likes enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'post_comment_likes'
      and policyname = 'post_comment_likes_select_authenticated'
  ) then
    create policy post_comment_likes_select_authenticated
      on public.post_comment_likes
      for select
      to authenticated
      using (true);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'post_comment_likes'
      and policyname = 'post_comment_likes_insert_own'
  ) then
    create policy post_comment_likes_insert_own
      on public.post_comment_likes
      for insert
      to authenticated
      with check (auth.uid() = user_id);
  end if;

  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'post_comment_likes'
      and policyname = 'post_comment_likes_delete_own'
  ) then
    create policy post_comment_likes_delete_own
      on public.post_comment_likes
      for delete
      to authenticated
      using (auth.uid() = user_id);
  end if;
end
$$;

create or replace function public.create_comment_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_post_id uuid,
  p_comment_id uuid,
  p_type text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_id is null or p_actor_id is null or p_post_id is null or p_comment_id is null then
    return;
  end if;

  if p_recipient_id = p_actor_id then
    return;
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    post_id,
    comment_id,
    type
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_post_id,
    p_comment_id,
    p_type
  );
end;
$$;

grant execute on function public.create_comment_notification(uuid, uuid, uuid, uuid, text)
  to authenticated;
