-- Migration 20261123000005: Create note_locks table and protect locked notes on public.notes

-- 1. Tạo bảng note_locks lưu mật khẩu đã băm (password_hash) và nội dung gốc đã khóa (locked_content).
-- Khi khóa ghi chú, Edge Function sẽ chuyển nội dung từ notes.content sang note_locks.locked_content,
-- đồng thời đặt notes.content = '' và notes.is_locked = true để nội dung nhạy cảm không bao giờ
-- lộ ra danh sách ghi chú, tìm kiếm, bộ nhớ đệm offline (offline cache) hay tính năng AI.
create table public.note_locks (
    note_id uuid primary key references public.notes(id) on delete cascade,
    owner_id uuid not null references auth.users(id),
    password_hash text not null,
    locked_content text not null default '',
    updated_at timestamptz not null default now()
);

-- Index hỗ trợ truy vấn nhanh các bản ghi khóa theo chủ sở hữu
create index idx_note_locks_owner_id on public.note_locks(owner_id);

-- 2. Bật Row Level Security (RLS) trên note_locks và KHÔNG tạo bất kỳ policy nào.
-- Trong PostgreSQL, khi RLS được bật mà không có policy nào đi kèm, mọi truy vấn từ các role
-- thông thường (anon, authenticated) đều bị từ chối mặc định (deny-all): SELECT trả về 0 dòng,
-- còn INSERT/UPDATE/DELETE bị báo lỗi quyền. Chỉ các Edge Function sử dụng Supabase service_role
-- (có thuộc tính BYPASSRLS) mới có thể đọc/ghi bảng này.
alter table public.note_locks enable row level security;

-- 3. Hàm trigger ngăn người dùng thông thường tự ý thay đổi trạng thái khóa (is_locked)
-- hoặc sửa nội dung (content) khi ghi chú đang bị khóa.
create or replace function public.protect_locked_note_fields()
returns trigger as $$
declare
    -- Xác định xem lệnh UPDATE hiện tại có đang được thực thi bởi service_role (Edge Function)
    -- hoặc quản trị viên cơ sở dữ liệu (postgres / supabase_admin) hay không.
    v_is_service_role boolean := (
        current_user in ('service_role', 'postgres', 'supabase_admin')
        or coalesce(auth.role(), '') = 'service_role'
    );
begin
    -- Nếu không phải service_role (tức là client Flutter gọi qua PostgREST với role authenticated/anon)
    if not v_is_service_role then
        -- Chặn mọi thao tác thay đổi cờ is_locked trực tiếp từ client
        if new.is_locked is distinct from old.is_locked then
            raise exception 'Only server Edge Functions (service_role) can change is_locked.'
                using errcode = '42501';
        end if;

        -- Chặn mọi thao tác sửa nội dung (content) khi ghi chú đang ở trạng thái khóa
        if (old.is_locked or new.is_locked) and (new.content is distinct from old.content) then
            raise exception 'Cannot modify content of a locked note directly.'
                using errcode = '42501';
        end if;
    end if;

    return new;
end;
$$ language plpgsql;

-- Gắn trigger BEFORE UPDATE lên bảng public.notes
-- (Tên trigger bắt đầu bằng "protect_" nên sẽ chạy sau "on_note_updated" theo thứ tự bảng chữ cái)
create trigger protect_locked_notes
    before update on public.notes
    for each row
    execute function public.protect_locked_note_fields();