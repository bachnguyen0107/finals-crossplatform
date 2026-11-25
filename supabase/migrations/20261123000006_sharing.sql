-- Migration 20261123000006: Note sharing RLS, permission helpers, shared_with_me RPC,
-- shared attachments/labels access, and Supabase Realtime publication.

-- ============================================================================
-- 1. SECURITY DEFINER HELPER FUNCTIONS (AVOID RLS RECURSION BETWEEN NOTES & SHARES)
-- ============================================================================

-- Returns true if the current authenticated user owns the note OR has a 'read' or 'edit' share.
create or replace function public.can_read_note(p_note_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.notes n
        where n.id = p_note_id
          and n.owner_id = auth.uid()
    )
    or exists (
        select 1
        from public.shares s
        where s.note_id = p_note_id
          and s.recipient_id = auth.uid()
          and s.permission in ('read', 'edit')
    );
$$;

-- Returns true if the current authenticated user owns the note OR has an 'edit' share.
create or replace function public.can_edit_note(p_note_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
    select exists (
        select 1
        from public.notes n
        where n.id = p_note_id
          and n.owner_id = auth.uid()
    )
    or exists (
        select 1
        from public.shares s
        where s.note_id = p_note_id
          and s.recipient_id = auth.uid()
          and s.permission = 'edit'
    );
$$;

revoke all on function public.can_read_note(uuid) from public;
revoke all on function public.can_edit_note(uuid) from public;
grant execute on function public.can_read_note(uuid) to authenticated, service_role;
grant execute on function public.can_edit_note(uuid) to authenticated, service_role;

-- ============================================================================
-- 2. NOTES POLICIES & COLUMN / PERMISSION ENFORCEMENT TRIGGER
-- ============================================================================

-- Allow owners and shared recipients ('read' or 'edit') to read notes.
drop policy if exists "Owners can select notes" on public.notes;
create policy "Users with read access can select notes"
on public.notes
for select
to authenticated
using (public.can_read_note(id));

-- Allow owners and shared recipients with 'edit' permission to update notes.
-- Database-level trigger below enforces column-level restrictions for non-owners.
drop policy if exists "Owners can update notes" on public.notes;
create policy "Users with edit access can update notes"
on public.notes
for update
to authenticated
using (public.can_edit_note(id))
with check (public.can_edit_note(id));

-- Trigger runs BEFORE UPDATE on public.notes (alphabetically before protect_locked_notes
-- if needed, though both are BEFORE UPDATE row triggers; protect_locked_notes also runs).
-- Ensures non-owners with 'edit' permission can only edit content/title and cannot alter
-- ownership, pin state, or lock state, and cannot modify content while locked.
create or replace function public.enforce_shared_note_update_rules()
returns trigger
language plpgsql
set search_path = public
as $$
declare
    v_is_privileged boolean := (
        current_user in ('service_role', 'postgres', 'supabase_admin')
        or coalesce(auth.role(), '') = 'service_role'
    );
begin
    if v_is_privileged then
        return new;
    end if;

    -- Non-owners must have explicit 'edit' permission (double guard beyond RLS).
    if old.owner_id is distinct from auth.uid() then
        if not public.can_edit_note(old.id) then
            raise exception 'Read-only or unauthorized users cannot update this note.'
                using errcode = '42501';
        end if;

        if new.owner_id is distinct from old.owner_id then
            raise exception 'Shared recipients cannot change note owner_id.'
                using errcode = '42501';
        end if;

        if new.is_pinned is distinct from old.is_pinned
           or new.pinned_at is distinct from old.pinned_at then
            raise exception 'Shared recipients cannot change pin state of a note.'
                using errcode = '42501';
        end if;

        if new.is_locked is distinct from old.is_locked then
            raise exception 'Shared recipients cannot change lock state of a note.'
                using errcode = '42501';
        end if;

        if (old.is_locked or new.is_locked) and (new.content is distinct from old.content) then
            raise exception 'Cannot modify content of a locked note.'
                using errcode = '42501';
        end if;
    end if;

    return new;
end;
$$;

drop trigger if exists enforce_shared_note_update_rules on public.notes;
create trigger enforce_shared_note_update_rules
    before update on public.notes
    for each row
    execute function public.enforce_shared_note_update_rules();

-- Note: "Owners can delete notes" policy remains owner-only (auth.uid() = owner_id),
-- so shared recipients cannot delete notes.

-- ============================================================================
-- 3. SHARES POLICIES (OWNER MANAGES, RECIPIENT READS OWN SHARES)
-- ============================================================================

-- Keep owner full management policy and add recipient SELECT-only policy.
drop policy if exists "Recipients can select own shares" on public.shares;
create policy "Recipients can select own shares"
on public.shares
for select
to authenticated
using (recipient_id = auth.uid());

-- ============================================================================
-- 4. FIND USER BY EMAIL & SHARED_WITH_ME RPC FUNCTIONS
-- ============================================================================

-- Looks up a registered auth user's UUID by email for authenticated callers only.
-- Returns NULL if not found (never exposes auth.users rows directly).
create or replace function public.find_user_id_by_email(p_email text)
returns uuid
language plpgsql
stable
security definer
set search_path = public, auth
as $$
declare
    v_user_id uuid;
begin
    if auth.uid() is null then
        raise exception 'Authentication required.'
            using errcode = '42501';
    end if;

    if p_email is null or btrim(p_email) = '' then
        return null;
    end if;

    select u.id
    into v_user_id
    from auth.users u
    where lower(u.email) = lower(btrim(p_email))
    limit 1;

    return v_user_id;
end;
$$;

revoke all on function public.find_user_id_by_email(text) from public;
grant execute on function public.find_user_id_by_email(text) to authenticated, service_role;

-- Returns notes shared with the current user along with share metadata and sharer info.
-- Never exposes locked content (when is_locked = true, content is returned as empty '').
create or replace function public.shared_with_me()
returns table (
    share_id uuid,
    note_id uuid,
    owner_id uuid,
    sharer_email text,
    sharer_display_name text,
    permission text,
    shared_at timestamptz,
    title text,
    content text,
    is_pinned boolean,
    pinned_at timestamptz,
    is_locked boolean,
    version integer,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
stable
security definer
set search_path = public, auth
as $$
    select
        s.id as share_id,
        n.id as note_id,
        n.owner_id,
        coalesce(u.email::text, '') as sharer_email,
        coalesce(
            nullif(u.raw_user_meta_data->>'display_name', ''),
            nullif(u.raw_user_meta_data->>'full_name', ''),
            nullif(u.raw_user_meta_data->>'name', ''),
            split_part(coalesce(u.email::text, ''), '@', 1)
        ) as sharer_display_name,
        s.permission,
        s.created_at as shared_at,
        n.title,
        case when n.is_locked then '' else n.content end as content,
        n.is_pinned,
        n.pinned_at,
        n.is_locked,
        n.version,
        n.created_at,
        n.updated_at
    from public.shares s
    join public.notes n on n.id = s.note_id
    left join auth.users u on u.id = n.owner_id
    where s.recipient_id = auth.uid()
      and s.permission in ('read', 'edit')
    order by s.created_at desc;
$$;

revoke all on function public.shared_with_me() from public;
grant execute on function public.shared_with_me() to authenticated, service_role;

-- ============================================================================
-- 5. ATTACHMENTS & NOTE_LABELS READ ACCESS FOR SHARED USERS + STORAGE POLICY
-- ============================================================================

-- Allow users who can read a note to view its attachments metadata rows.
drop policy if exists "Users with read access can select attachments" on public.attachments;
create policy "Users with read access can select attachments"
on public.attachments
for select
to authenticated
using (public.can_read_note(note_id));

-- Allow users who can read a note to view its note_labels rows.
drop policy if exists "Users with read access can select note_labels" on public.note_labels;
create policy "Users with read access can select note_labels"
on public.note_labels
for select
to authenticated
using (public.can_read_note(note_id));

-- Update storage SELECT policy on 'attachments' bucket so recipients who can read
-- the parent note (path convention: <owner_id>/<note_id>/<file_name> or <note_id>/...)
-- can download/sign attachment objects.
-- Supports both '<owner_id>/<note_id>/...' and '<note_id>/...' path layouts safely.
drop policy if exists "Users can read own attachment objects" on storage.objects;
drop policy if exists "Users with note read access can read attachment objects" on storage.objects;
create policy "Users with note read access can read attachment objects"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'attachments'
    and (
        (storage.foldername(name))[1] = auth.uid()::text
        or exists (
            select 1
            from public.attachments a
            where a.storage_path = name
              and public.can_read_note(a.note_id)
        )
    )
);

-- ============================================================================
-- 6. SUPABASE REALTIME PUBLICATION
-- ============================================================================

do $$
begin
    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'notes'
    ) then
        alter publication supabase_realtime add table public.notes;
    end if;

    if not exists (
        select 1
        from pg_publication_tables
        where pubname = 'supabase_realtime'
          and schemaname = 'public'
          and tablename = 'shares'
    ) then
        alter publication supabase_realtime add table public.shares;
    end if;
end;
$$;