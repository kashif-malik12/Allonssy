alter table public.posts
  add column if not exists share_scope text not null default 'none';

alter table public.posts
  add column if not exists shared_post_id uuid references public.posts(id) on delete cascade;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'posts_share_scope_check'
  ) then
    alter table public.posts
      add constraint posts_share_scope_check
      check (share_scope in ('none', 'followers', 'connections', 'public'));
  end if;
end
$$;

create index if not exists posts_shared_post_id_idx
  on public.posts(shared_post_id);

create or replace function public.create_share_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_post_id uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_recipient_id is null or p_actor_id is null or p_post_id is null then
    return;
  end if;

  if p_recipient_id = p_actor_id then
    return;
  end if;

  insert into public.notifications (
    recipient_id,
    actor_id,
    post_id,
    type
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_post_id,
    'share'
  );
end;
$$;

grant execute on function public.create_share_notification(uuid, uuid, uuid)
  to authenticated;
