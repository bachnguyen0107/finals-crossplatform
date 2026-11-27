-- Creating a note failed with 403: INSERT ... RETURNING checks the SELECT
-- policy, and can_read_note(id) cannot see the row that is being inserted.
-- Owners are now checked directly on the row, shares still go through the helper.
drop policy if exists "Users with read access can select notes" on public.notes;
create policy "Users with read access can select notes"
on public.notes
for select
to authenticated
using (owner_id = auth.uid() or public.can_read_note(id));