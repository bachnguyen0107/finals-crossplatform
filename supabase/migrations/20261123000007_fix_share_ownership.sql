-- Only the real owner of a note can share it or attach files to it.
create or replace function public.owns_note(p_note_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1 from public.notes
        where id = p_note_id and owner_id = auth.uid()
    );
$$;

revoke all on function public.owns_note(uuid) from public;
grant execute on function public.owns_note(uuid) to authenticated, service_role;

drop policy if exists "Owners can manage shares" on public.shares;
create policy "Owners can manage shares"
on public.shares
for all
to authenticated
using (owner_id = auth.uid() and public.owns_note(note_id))
with check (owner_id = auth.uid() and public.owns_note(note_id));

drop policy if exists "Owners can manage attachments" on public.attachments;
create policy "Owners can manage attachments"
on public.attachments
for all
to authenticated
using (owner_id = auth.uid() and public.owns_note(note_id))
with check (owner_id = auth.uid() and public.owns_note(note_id));