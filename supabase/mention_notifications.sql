create or replace function public.create_mention_notification(
  p_recipient_id uuid,
  p_actor_id uuid,
  p_post_id uuid,
  p_comment_id uuid default null
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
    comment_id,
    type
  )
  values (
    p_recipient_id,
    p_actor_id,
    p_post_id,
    p_comment_id,
    'mention'
  );
end;
$$;

grant execute on function public.create_mention_notification(uuid, uuid, uuid, uuid)
  to authenticated;
