-- 1. Bảng shares (Chia sẻ ghi chú với người dùng khác)
create table public.shares (
    id uuid primary key default gen_random_uuid(),
    note_id uuid not null references public.notes(id) on delete cascade,
    owner_id uuid not null default auth.uid() references auth.users(id),
    recipient_id uuid not null references auth.users(id) on delete cascade,
    permission text not null check (permission in ('read', 'edit')),
    created_at timestamptz not null default now(),
    constraint unique_note_recipient unique (note_id, recipient_id),
    constraint check_owner_not_recipient check (owner_id <> recipient_id)
);

-- 2. Bảng attachments (Tệp đính kèm trong ghi chú)
create table public.attachments (
    id uuid primary key default gen_random_uuid(),
    note_id uuid not null references public.notes(id) on delete cascade,
    owner_id uuid not null default auth.uid() references auth.users(id),
    storage_path text not null,
    file_name text not null,
    mime_type text not null,
    size_bytes bigint not null check (size_bytes > 0),
    created_at timestamptz not null default now()
);

-- ==========================================
-- BẢO MẬT: ROW LEVEL SECURITY (RLS) POLICIES
-- ==========================================

-- Bật RLS trên toàn bộ 5 bảng của hệ thống
alter table public.notes enable row level security;
alter table public.labels enable row level security;
alter table public.note_labels enable row level security;
alter table public.shares enable row level security;
alter table public.attachments enable row level security;

-- --- POLICIES CHO BẢNG NOTES ---
create policy "Owners can select notes" on public.notes for select using (auth.uid() = owner_id);
create policy "Owners can insert notes" on public.notes for insert with check (auth.uid() = owner_id);
create policy "Owners can update notes" on public.notes for update using (auth.uid() = owner_id);
create policy "Owners can delete notes" on public.notes for delete using (auth.uid() = owner_id);

-- --- POLICIES CHO BẢNG LABELS ---
create policy "Owners can select labels" on public.labels for select using (auth.uid() = owner_id);
create policy "Owners can insert labels" on public.labels for insert with check (auth.uid() = owner_id);
create policy "Owners can update labels" on public.labels for update using (auth.uid() = owner_id);
create policy "Owners can delete labels" on public.labels for delete using (auth.uid() = owner_id);

-- --- POLICIES CHO BẢNG NOTE_LABELS ---
create policy "Owners can access note_labels" on public.note_labels
    for all using (
        exists (select 1 from public.notes where id = note_id and owner_id = auth.uid())
        and exists (select 1 from public.labels where id = label_id and owner_id = auth.uid())
    );

-- --- POLICIES CHO BẢNG SHARES ---
create policy "Owners can manage shares" on public.shares for all using (auth.uid() = owner_id);

-- --- POLICIES CHO BẢNG ATTACHMENTS ---
create policy "Owners can manage attachments" on public.attachments for all using (auth.uid() = owner_id);

-- Lưu ý: Quyền truy cập dành cho người được chia sẻ sẽ được bổ sung sau bằng hàm security definer
-- nhằm tránh lỗi vòng lặp đệ quy vô hạn (infinite recursion) giữa notes và shares.