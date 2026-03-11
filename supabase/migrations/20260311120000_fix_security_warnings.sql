do $$
begin
  if exists (
    select 1
    from pg_views
    where schemaname = 'public'
      and viewname = 'conversation_list'
  ) then
    execute 'alter view public.conversation_list set (security_invoker = true)';
  end if;
end
$$;

do $$
begin
  begin
    if exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = 'spatial_ref_sys'
        and c.relkind = 'r'
    ) then
      execute 'alter table public.spatial_ref_sys enable row level security';

      if not exists (
        select 1
        from pg_policies
        where schemaname = 'public'
          and tablename = 'spatial_ref_sys'
          and policyname = 'spatial_ref_sys_read_only'
      ) then
        execute $policy$
          create policy spatial_ref_sys_read_only
          on public.spatial_ref_sys
          for select
          to anon, authenticated
          using (true)
        $policy$;
      end if;
    end if;
  exception
    when insufficient_privilege then
      raise notice 'Skipping spatial_ref_sys RLS change because the migration role is not the table owner.';
  end;
end
$$;
