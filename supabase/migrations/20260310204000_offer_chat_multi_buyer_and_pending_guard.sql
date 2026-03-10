do $$
declare
  v_constraint record;
begin
  for v_constraint in
    select conname
    from pg_constraint
    where conrelid = 'public.offer_conversations'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) like 'UNIQUE (post_id%'
      and pg_get_constraintdef(oid) not like '%buyer_id%'
  loop
    execute format(
      'alter table public.offer_conversations drop constraint %I',
      v_constraint.conname
    );
  end loop;

  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.offer_conversations'::regclass
      and contype = 'u'
      and pg_get_constraintdef(oid) = 'UNIQUE (post_id, buyer_id, seller_id)'
  ) then
    alter table public.offer_conversations
      add constraint offer_conversations_unique unique (post_id, buyer_id, seller_id);
  end if;
end;
$$;

create or replace function public.submit_offer_amount(
  p_conversation_id uuid,
  p_amount numeric
)
returns table (
  id uuid,
  conversation_id uuid,
  sender_id uuid,
  message_type text,
  content text,
  offer_amount numeric,
  created_at timestamptz,
  read_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_conversation public.offer_conversations%rowtype;
  v_kind text;
  v_recipient_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  if p_amount is null or p_amount <= 0 then
    raise exception 'Offer amount must be greater than zero';
  end if;

  select *
  into v_conversation
  from public.offer_conversations c
  where c.id = p_conversation_id
    and auth.uid() in (c.buyer_id, c.seller_id);

  if not found then
    raise exception 'Offer chat unavailable';
  end if;

  if v_conversation.current_offer_status = 'pending'
     and v_conversation.current_offer_by = auth.uid() then
    raise exception 'Wait for the other person to respond to your offer';
  end if;

  v_kind := case
    when v_conversation.current_offer_amount is null then 'offer'
    else 'counter'
  end;

  v_recipient_id := case
    when auth.uid() = v_conversation.buyer_id then v_conversation.seller_id
    else v_conversation.buyer_id
  end;

  update public.offer_conversations
  set current_offer_amount = p_amount,
      current_offer_status = 'pending',
      current_offer_by = auth.uid(),
      updated_at = now()
  where public.offer_conversations.id = p_conversation_id;

  return query
  insert into public.offer_messages (
    conversation_id,
    sender_id,
    message_type,
    offer_amount,
    content
  )
  values (
    p_conversation_id,
    auth.uid(),
    v_kind,
    p_amount,
    ''
  )
  returning
    offer_messages.id,
    offer_messages.conversation_id,
    offer_messages.sender_id,
    offer_messages.message_type,
    offer_messages.content,
    offer_messages.offer_amount,
    offer_messages.created_at,
    offer_messages.read_at;

  perform public.create_offer_notification(
    v_recipient_id,
    auth.uid(),
    v_conversation.post_id,
    'offer_sent'
  );
end;
$$;

grant execute on function public.submit_offer_amount(uuid, numeric) to authenticated;
