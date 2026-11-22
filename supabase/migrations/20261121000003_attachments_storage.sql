-- Tạo bucket lưu trữ tệp đính kèm ở chế độ private (không công khai)
insert into storage.buckets (id, name, public)
values ('attachments', 'attachments', false)
on conflict (id) do nothing;

-- Policy cho phép người dùng ĐỌC (tải/xem) file trong thư mục <user_id>/ của chính họ
create policy "Users can read own attachment objects"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy cho phép người dùng UPLOAD file vào thư mục <user_id>/ của chính họ
create policy "Users can upload own attachment objects"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy cho phép người dùng CẬP NHẬT file trong thư mục <user_id>/ của chính họ (nếu cần)
create policy "Users can update own attachment objects"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
)
with check (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy cho phép người dùng XÓA file trong thư mục <user_id>/ của chính họ
create policy "Users can delete own attachment objects"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'attachments'
    and (storage.foldername(name))[1] = auth.uid()::text
);