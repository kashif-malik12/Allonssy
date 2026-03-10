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
  select
    p_recipient_id,
    p_actor_id,
    p_post_id,
    p_comment_id,
    p_type
  where not exists (
    select 1
    from public.notifications n
    where n.recipient_id = p_recipient_id
      and n.actor_id = p_actor_id
      and n.post_id = p_post_id
      and n.comment_id = p_comment_id
      and n.type = p_type
  );
end;
$$;

grant execute on function public.create_comment_notification(uuid, uuid, uuid, uuid, text)
  to authenticated;
