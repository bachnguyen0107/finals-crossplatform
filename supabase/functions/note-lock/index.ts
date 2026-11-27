import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PBKDF2_ITERATIONS = 100_000;
const SALT_LENGTH_BYTES = 16;
const HASH_LENGTH_BITS = 256;

function jsonResponse(
  status: number,
  payload: Record<string, unknown>,
): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function bytesToBase64(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

function base64ToBytes(base64: string): Uint8Array {
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  const maxLen = Math.max(a.length, b.length);
  let diff = a.length ^ b.length;
  for (let i = 0; i < maxLen; i++) {
    const byteA = i < a.length ? a[i] : 0;
    const byteB = i < b.length ? b[i] : 0;
    diff |= byteA ^ byteB;
  }
  return diff === 0;
}

async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(SALT_LENGTH_BYTES));
  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt,
      iterations: PBKDF2_ITERATIONS,
      hash: "SHA-256",
    },
    keyMaterial,
    HASH_LENGTH_BITS,
  );
  const hashBytes = new Uint8Array(derivedBits);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${bytesToBase64(salt)}$${bytesToBase64(hashBytes)}`;
}

async function verifyPassword(
  password: string,
  storedHash: string,
): Promise<boolean> {
  const parts = storedHash.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2") {
    return false;
  }

  const iterations = Number.parseInt(parts[1], 10);
  if (!Number.isFinite(iterations) || iterations <= 0) {
    return false;
  }

  let salt: Uint8Array;
  let expectedHash: Uint8Array;
  try {
    salt = base64ToBytes(parts[2]);
    expectedHash = base64ToBytes(parts[3]);
  } catch {
    return false;
  }

  const keyMaterial = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const derivedBits = await crypto.subtle.deriveBits(
    {
      name: "PBKDF2",
      salt,
      iterations,
      hash: "SHA-256",
    },
    keyMaterial,
    expectedHash.length * 8,
  );
  const actualHash = new Uint8Array(derivedBits);
  return constantTimeEqual(actualHash, expectedHash);
}

Deno.serve(async (req: Request): Promise<Response> => {
  // Xử lý CORS preflight cho nền tảng Web
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseAnonKey || !supabaseServiceRoleKey) {
    return jsonResponse(500, { error: "server_misconfigured" });
  }

  // 1. Xác thực người dùng qua JWT trong header Authorization bằng anon client
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const anonClient = createClient(supabaseUrl, supabaseAnonKey, {
    global: {
      headers: { Authorization: authHeader },
    },
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  const {
    data: { user },
    error: authError,
  } = await anonClient.auth.getUser();

  if (authError || !user) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  // 2. Đọc và kiểm tra JSON body
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "invalid_json" });
  }

  const action = body.action;
  const noteId = body.note_id;
  const password = body.password;
  const newPassword = body.new_password;
  const content = body.content;

  if (typeof action !== "string" || !action) {
    return jsonResponse(400, { error: "invalid_action" });
  }

  if (typeof noteId !== "string" || !noteId.trim()) {
    return jsonResponse(400, { error: "invalid_note_id" });
  }

  // 3. Khởi tạo service_role client để đọc/ghi notes và note_locks
  const adminClient = createClient(supabaseUrl, supabaseServiceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });

  // 4. Kiểm tra note tồn tại và thuộc quyền sở hữu của user hiện tại
  const { data: note, error: noteError } = await adminClient
    .from("notes")
    .select("id, owner_id, content, is_locked")
    .eq("id", noteId)
    .maybeSingle();

  if (noteError) {
    return jsonResponse(500, { error: "db_error" });
  }

  if (!note) {
    return jsonResponse(404, { error: "not_found" });
  }

  if (note.owner_id !== user.id) {
    return jsonResponse(403, { error: "forbidden" });
  }

  // 5. Xử lý action "lock"
  if (action === "lock") {
    if (note.is_locked) {
      return jsonResponse(400, { error: "already_locked" });
    }

    if (typeof password !== "string" || password.length < 4) {
      return jsonResponse(400, { error: "weak_password" });
    }

    const passwordHash = await hashPassword(password);
    const nowIso = new Date().toISOString();

    const { error: insertError } = await adminClient
      .from("note_locks")
      .insert({
        note_id: noteId,
        owner_id: user.id,
        password_hash: passwordHash,
        locked_content: note.content ?? "",
        updated_at: nowIso,
      });

    if (insertError) {
      return jsonResponse(400, { error: "lock_failed" });
    }

    const { error: updateNoteError } = await adminClient
      .from("notes")
      .update({
        content: "",
        is_locked: true,
      })
      .eq("id", noteId)
      .eq("owner_id", user.id);

    if (updateNoteError) {
      await adminClient.from("note_locks").delete().eq("note_id", noteId);
      return jsonResponse(500, { error: "lock_failed" });
    }

    return jsonResponse(200, { ok: true });
  }

  // Các action còn lại đều yêu cầu note đang khóa và kiểm tra mật khẩu hiện tại
  if (typeof password !== "string" || password.length === 0) {
    return jsonResponse(400, { error: "wrong_password" });
  }

  const { data: lockRow, error: lockFetchError } = await adminClient
    .from("note_locks")
    .select("note_id, owner_id, password_hash, locked_content")
    .eq("note_id", noteId)
    .maybeSingle();

  if (lockFetchError) {
    return jsonResponse(500, { error: "db_error" });
  }

  if (!lockRow || !note.is_locked) {
    return jsonResponse(400, { error: "not_locked" });
  }

  const passwordValid = await verifyPassword(password, lockRow.password_hash);
  if (!passwordValid) {
    return jsonResponse(400, { error: "wrong_password" });
  }

  switch (action) {
    case "open": {
      return jsonResponse(200, {
        content: lockRow.locked_content ?? "",
      });
    }

    case "save": {
      if (typeof content !== "string") {
        return jsonResponse(400, { error: "invalid_content" });
      }

      const { error: saveError } = await adminClient
        .from("note_locks")
        .update({
          locked_content: content,
          updated_at: new Date().toISOString(),
        })
        .eq("note_id", noteId);

      if (saveError) {
        return jsonResponse(500, { error: "save_failed" });
      }

      return jsonResponse(200, { ok: true });
    }

    case "change_password": {
      if (typeof newPassword !== "string" || newPassword.length < 4) {
        return jsonResponse(400, { error: "weak_password" });
      }

      const newHash = await hashPassword(newPassword);
      const { error: changeError } = await adminClient
        .from("note_locks")
        .update({
          password_hash: newHash,
          updated_at: new Date().toISOString(),
        })
        .eq("note_id", noteId);

      if (changeError) {
        return jsonResponse(500, { error: "change_password_failed" });
      }

      return jsonResponse(200, { ok: true });
    }

    case "unlock": {
      const restoredContent = lockRow.locked_content ?? "";

      const { error: restoreNoteError } = await adminClient
        .from("notes")
        .update({
          content: restoredContent,
          is_locked: false,
        })
        .eq("id", noteId)
        .eq("owner_id", user.id);

      if (restoreNoteError) {
        return jsonResponse(500, { error: "unlock_failed" });
      }

      const { error: deleteLockError } = await adminClient
        .from("note_locks")
        .delete()
        .eq("note_id", noteId);

      if (deleteLockError) {
        return jsonResponse(500, { error: "unlock_cleanup_failed" });
      }

      return jsonResponse(200, { ok: true, content: restoredContent });
    }

    default:
      return jsonResponse(400, { error: "invalid_action" });
  }
});