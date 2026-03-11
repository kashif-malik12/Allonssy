create or replace function public.notification_setting_key_for_type(
  p_type text
)
returns text
language sql
immutable
as $$
  select case p_type
    when 'chat_message' then 'in_app_chat_messages'
    when 'offer_message' then 'in_app_offer_messages'
    when 'offer_sent' then 'in_app_offer_updates'
    when 'offer_accepted' then 'in_app_offer_updates'
    when 'offer_rejected' then 'in_app_offer_updates'
    when 'comment' then 'in_app_comments'
    when 'comment_reply' then 'in_app_replies'
    when 'comment_like' then 'in_app_replies'
    when 'mention' then 'in_app_mentions'
    when 'follow_request' then 'in_app_follow_requests'
    when 'follow' then 'in_app_new_followers'
    when 'follow_accepted' then 'in_app_new_followers'
    when 'admin_update' then 'in_app_admin_updates'
    when 'safety_update' then 'in_app_admin_updates'
    else null
  end
$$;

create or replace function public.notification_in_app_enabled(
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

  v_key := public.notification_setting_key_for_type(p_type);
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

create or replace function public.filter_notification_inserts_by_settings()
returns trigger
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if not public.notification_in_app_enabled(new.recipient_id, new.type) then
    return null;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_notifications_filter_by_settings on public.notifications;
create trigger trg_notifications_filter_by_settings
before insert on public.notifications
for each row
execute function public.filter_notification_inserts_by_settings();
