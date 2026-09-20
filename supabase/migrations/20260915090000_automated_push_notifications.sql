-- Migration: Automated Push Notifications Dispatch via pg_net
-- Date: 2026-09-15

-- 1. Helper function: map notification type to user push setting key
create or replace function public.notification_push_setting_key_for_type(
  p_type text
)
returns text
language sql
immutable
as $$
  select case p_type
    when 'chat_message' then 'push_chat_messages'
    when 'offer_message' then 'push_offer_messages'
    when 'offer_sent' then 'push_offer_updates'
    when 'offer_accepted' then 'push_offer_updates'
    when 'offer_rejected' then 'push_offer_updates'
    when 'comment' then 'push_comments'
    when 'comment_reply' then 'push_replies'
    when 'comment_like' then 'push_replies'
    when 'like' then 'push_comments'
    when 'mention' then 'push_mentions'
    when 'follow_request' then 'push_follow_requests'
    when 'follow' then 'push_new_followers'
    when 'follow_accepted' then 'push_new_followers'
    when 'admin_update' then 'push_admin_updates'
    when 'safety_update' then 'push_admin_updates'
    else null
  end
$$;

-- 2. Helper function: check if recipient has push notifications enabled for this type
create or replace function public.notification_push_enabled(
  p_user_id uuid,
  p_type text
)
returns boolean
language plpgsql
security definer
set search_path = public, auth
as $$
declare
  v_key text;
  v_settings jsonb := '{}'::jsonb;
  v_raw text;
begin
  if p_user_id is null then
    return true;
  end if;

  v_key := public.notification_push_setting_key_for_type(p_type);
  if v_key is null then
    return true;
  end if;

  select coalesce(raw_user_meta_data -> 'app_settings', '{}'::jsonb)
  into v_settings
  from auth.users
  where id = p_user_id;

  if not (v_settings ? v_key) then
    return true;
  end if;

  v_raw := v_settings ->> v_key;
  if v_raw is null then
    return true;
  end if;

  return coalesce(v_raw::boolean, true);
exception
  when others then
    return true;
end;
$$;

-- Private schema and table for internal operational secrets
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.app_secrets (
  key text primary key,
  value text not null
);
revoke all on table private.app_secrets from public, anon, authenticated;

-- 3. Push dispatcher function via pg_net
create or replace function public.send_push_notification(
  p_recipient_id uuid,
  p_title text,
  p_body text,
  p_route text default null
)
returns void
language plpgsql
security definer
set search_path = public, private, net
as $$
declare
  v_data jsonb;
  v_secret text := '';
begin
  if p_recipient_id is null or p_title is null or p_body is null then
    return;
  end if;

  -- Only attempt dispatch if user has registered device tokens
  if not exists (
    select 1 from public.device_push_tokens where user_id = p_recipient_id
  ) then
    return;
  end if;

  -- Read dispatch secret from secure private schema
  select value into v_secret
  from private.app_secrets
  where key = 'push_dispatch_secret';

  v_data := jsonb_build_object(
    'click_action', 'FLUTTER_NOTIFICATION_CLICK'
  );
  if p_route is not null and length(trim(p_route)) > 0 then
    v_data := v_data || jsonb_build_object('route', p_route);
  end if;

  perform net.http_post(
    url := 'http://kong:8000/functions/v1/push-dispatch',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-secret', coalesce(v_secret, '')
    ),
    body := jsonb_build_object(
      'recipientId', p_recipient_id,
      'title', p_title,
      'body', p_body,
      'data', v_data
    )
  );
exception
  when others then
    -- Never abort the enclosing transaction if push dispatch fails
    raise warning 'Push notification dispatch failed for user %: %', p_recipient_id, sqlerrm;
end;
$$;

-- 4. Trigger on public.notifications (AFTER INSERT)
create or replace function public.trg_push_on_notification_handler()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_actor_name text := 'Someone';
  v_body text := '';
  v_route text := '/notifications';
begin
  if not public.notification_push_enabled(new.recipient_id, new.type) then
    return new;
  end if;

  if new.actor_id is not null then
    select coalesce(nullif(trim(business_name), ''), nullif(trim(full_name), ''), 'Someone')
    into v_actor_name
    from public.profiles
    where id = new.actor_id;
  end if;

  case new.type
    when 'comment' then
      v_body := v_actor_name || ' commented on your post';
    when 'comment_reply' then
      v_body := v_actor_name || ' replied to your comment';
    when 'comment_like' then
      v_body := v_actor_name || ' liked your comment';
    when 'like' then
      v_body := v_actor_name || ' liked your post';
    when 'mention' then
      v_body := v_actor_name || ' mentioned you';
    when 'share' then
      v_body := v_actor_name || ' shared your post';
    when 'follow' then
      v_body := v_actor_name || ' started following you';
    when 'follow_request' then
      v_body := v_actor_name || ' requested to follow you';
    when 'follow_accepted' then
      v_body := v_actor_name || ' accepted your follow request';
    when 'offer_sent' then
      v_body := v_actor_name || ' sent you an offer';
    when 'offer_accepted' then
      v_body := v_actor_name || ' accepted your offer!';
    when 'offer_rejected' then
      v_body := v_actor_name || ' rejected your offer';
    when 'offer_message' then
      v_body := v_actor_name || ': ' || coalesce(new.data->>'content', 'Sent an offer message');
    when 'admin_update' then
      v_body := coalesce(new.data->>'title', 'Announcement from Allonssy');
    when 'safety_update' then
      v_body := coalesce(new.data->>'title', 'Important notice from Allonssy');
    else
      v_body := v_actor_name || ' sent you a notification';
  end case;

  if new.post_id is not null then
    v_route := '/post/' || new.post_id::text;
  end if;

  perform public.send_push_notification(new.recipient_id, 'Allonssy', v_body, v_route);

  return new;
end;
$$;

drop trigger if exists trg_push_on_notification on public.notifications;
create trigger trg_push_on_notification
after insert on public.notifications
for each row
execute function public.trg_push_on_notification_handler();

-- 5. Trigger on public.messages (AFTER INSERT for direct chat)
create or replace function public.trg_push_on_message_handler()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_id uuid;
  v_sender_name text := 'New message';
  v_preview text;
begin
  select case when c.user1 = new.sender_id then c.user2 else c.user1 end
  into v_recipient_id
  from public.conversations c
  where c.id = new.conversation_id;

  if v_recipient_id is null then
    return new;
  end if;

  if not public.notification_push_enabled(v_recipient_id, 'chat_message') then
    return new;
  end if;

  select coalesce(nullif(trim(business_name), ''), nullif(trim(full_name), ''), 'Someone')
  into v_sender_name
  from public.profiles
  where id = new.sender_id;

  v_preview := left(trim(new.content), 120);

  perform public.send_push_notification(v_recipient_id, v_sender_name, v_preview, '/chat');

  return new;
end;
$$;

drop trigger if exists trg_push_on_message on public.messages;
create trigger trg_push_on_message
after insert on public.messages
for each row
execute function public.trg_push_on_message_handler();

-- 6. Trigger on public.offer_messages (AFTER INSERT for offer chat)
create or replace function public.trg_push_on_offer_message_handler()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_recipient_id uuid;
  v_sender_name text := 'Offer update';
  v_body text;
begin
  select case when oc.buyer_id = new.sender_id then oc.seller_id else oc.buyer_id end
  into v_recipient_id
  from public.offer_conversations oc
  where oc.id = new.conversation_id;

  if v_recipient_id is null then
    return new;
  end if;

  if not public.notification_push_enabled(v_recipient_id, 'offer_message') then
    return new;
  end if;

  select coalesce(nullif(trim(business_name), ''), nullif(trim(full_name), ''), 'Someone')
  into v_sender_name
  from public.profiles
  where id = new.sender_id;

  case new.message_type
    when 'offer' then
      v_body := v_sender_name || ' sent an offer of €' || coalesce(new.offer_amount::text, '');
    when 'counter' then
      v_body := v_sender_name || ' sent a counter-offer of €' || coalesce(new.offer_amount::text, '');
    when 'accepted' then
      v_body := v_sender_name || ' accepted the offer!';
    when 'rejected' then
      v_body := v_sender_name || ' declined the offer';
    else
      v_body := v_sender_name || ': ' || left(trim(new.content), 100);
  end case;

  perform public.send_push_notification(v_recipient_id, 'Allonssy Offer', v_body, '/chat');

  return new;
end;
$$;

drop trigger if exists trg_push_on_offer_message on public.offer_messages;
create trigger trg_push_on_offer_message
after insert on public.offer_messages
for each row
execute function public.trg_push_on_offer_message_handler();