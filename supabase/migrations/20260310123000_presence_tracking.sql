alter table public.profiles
  add column if not exists last_seen_at timestamptz;

create index if not exists profiles_last_seen_at_idx
  on public.profiles (last_seen_at desc);

create or replace function public.touch_my_presence()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  update public.profiles
  set last_seen_at = now()
  where id = auth.uid();
end;
$$;

grant execute on function public.touch_my_presence() to authenticated;
