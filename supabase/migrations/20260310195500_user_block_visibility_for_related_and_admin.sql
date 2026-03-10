drop policy if exists user_blocks_select_own on public.user_blocks;
drop policy if exists user_blocks_select_related_or_admin on public.user_blocks;

create policy user_blocks_select_related_or_admin
on public.user_blocks
for select
to authenticated
using (
  auth.uid() = blocker_id
  or auth.uid() = blocked_id
  or exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and coalesce(p.is_admin, false) = true
  )
);
