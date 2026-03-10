do $$
declare
  constraint_name text;
begin
  for constraint_name in
    select c.conname
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'profiles'
      and c.contype = 'c'
      and pg_get_constraintdef(c.oid) ilike '%org_kind%'
  loop
    execute format('alter table public.profiles drop constraint %I', constraint_name);
  end loop;
end
$$;

alter table public.profiles
  add constraint profiles_org_kind_check
  check (
    org_kind is null or org_kind in ('government', 'nonprofit', 'news_agency')
  ) not valid;
