-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- 1. Bảng notes (Ghi chú)
create table public.notes (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    title text not null,
    content text not null default '',
    is_pinned boolean not null default false,
    pinned_at timestamptz,
    is_locked boolean not null default false,
    version integer not null default 1,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- 2. Trigger tự động cập nhật updated_at và tăng version trên mỗi lần update note
create or replace function public.handle_note_update()
returns trigger as $$
begin
    new.updated_at = now();
    new.version = old.version + 1;
    return new;
end;
$$ language plpgsql;

create trigger on_note_updated
    before update on public.notes
    for each row
    execute function public.handle_note_update();

-- 3. Bảng labels (Nhãn / Thẻ)
create table public.labels (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
    name text not null,
    created_at timestamptz not null default now(),
    constraint unique_owner_label_name unique (owner_id, name)
);

-- 4. Bảng trung gian note_labels
create table public.note_labels (
    note_id uuid not null references public.notes(id) on delete cascade,
    label_id uuid not null references public.labels(id) on delete cascade,
    primary key (note_id, label_id)
);

-- 5. Indexes tối ưu hiệu năng
create index idx_notes_owner_id on public.notes(owner_id);
create index idx_notes_pinned_updated on public.notes(owner_id, is_pinned desc, updated_at desc);
create index idx_labels_owner_id on public.labels(owner_id);