create or replace function public.get_offer_chat_list()
returns table (
  conversation_id uuid,
  post_id uuid,
  post_type text,
  post_title text,
  market_price numeric,
  other_user_id uuid,
  other_full_name text,
  last_message text,
  unread_count bigint,
  current_offer_amount numeric,
  current_offer_status text,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
as $$
  with base as (
    select
      c.id as conversation_id,
      c.post_id,
      p.post_type,
      coalesce(nullif(trim(p.market_title), ''), nullif(trim(p.content), ''), 'Listing') as post_title,
      p.market_price,
      c.current_offer_amount,
      c.current_offer_status,
      c.updated_at,
      case
        when auth.uid() = c.buyer_id then c.seller_id
        else c.buyer_id
      end as other_user_id,
      case
        when auth.uid() = c.buyer_id then seller.full_name
        else buyer.full_name
      end as other_full_name
    from public.offer_conversations c
    join public.posts p on p.id = c.post_id
    join public.profiles buyer on buyer.id = c.buyer_id
    join public.profiles seller on seller.id = c.seller_id
    where auth.uid() in (c.buyer_id, c.seller_id)
      and coalesce(buyer.is_disabled, false) = false
      and coalesce(seller.is_disabled, false) = false
  ),
  last_msg as (
    select distinct on (m.conversation_id)
      m.conversation_id,
      case
        when m.message_type in ('offer', 'counter') then concat(initcap(m.message_type), ': EUR ', m.offer_amount)
        when m.message_type = 'accepted' then 'Offer accepted'
        when m.message_type = 'rejected' then 'Offer rejected'
        else m.content
      end as content,
      m.created_at
    from public.offer_messages m
    order by m.conversation_id, m.created_at desc, m.id desc
  ),
  unread as (
    select
      m.conversation_id,
      count(*)::bigint as unread_count
    from public.offer_messages m
    join public.offer_conversations c on c.id = m.conversation_id
    where m.sender_id <> auth.uid()
      and m.read_at is null
      and auth.uid() in (c.buyer_id, c.seller_id)
    group by m.conversation_id
  )
  select
    b.conversation_id,
    b.post_id,
    b.post_type,
    b.post_title,
    b.market_price,
    b.other_user_id,
    b.other_full_name,
    lm.content as last_message,
    coalesce(u.unread_count, 0) as unread_count,
    b.current_offer_amount,
    b.current_offer_status,
    coalesce(lm.created_at, b.updated_at) as updated_at
  from base b
  left join last_msg lm on lm.conversation_id = b.conversation_id
  left join unread u on u.conversation_id = b.conversation_id
  order by updated_at desc nulls last;
$$;

grant execute on function public.get_offer_chat_list() to authenticated;
