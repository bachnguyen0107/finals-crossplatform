import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const MAX_NOTE_CHARS = 12_000;
const MIN_CONTENT_CHARS = 20;
const GEMINI_TIMEOUT_MS = 30_000;

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

Deno.serve(async (req: Request): Promise<Response> => {
  // 1. Xử lý CORS preflight cho Web
  if (req.method === "OPTIONS") {
    return new Response("ok", { status: 200, headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return jsonResponse(405, { error: "method_not_allowed" });
  }

  // 2. Kiểm tra header Authorization
  const authHeader = req.headers.get("Authorization");
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
  const geminiApiKey = Deno.env.get("GEMINI_API_KEY");
  const geminiModel = Deno.env.get("GEMINI_MODEL") ?? "gemini-flash-latest";

  if (!supabaseUrl || !supabaseAnonKey || !geminiApiKey) {
    console.error("Missing required environment variables for ai-summary");
    return jsonResponse(502, { error: "ai_failed" });
  }

  // 3. Đọc và kiểm tra JSON body { note_id }
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return jsonResponse(400, { error: "bad_request" });
  }

  const noteId = body.note_id;
  if (typeof noteId !== "string" || !noteId.trim()) {
    return jsonResponse(400, { error: "bad_request" });
  }

  // 4. Tạo Supabase client với anon key + JWT của user (không dùng service_role).
  // RLS trên bảng notes tự kiểm tra quyền đọc của chủ sở hữu hoặc người được share.
  const supabase = createClient(supabaseUrl, supabaseAnonKey, {
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
  } = await supabase.auth.getUser();

  if (authError || !user) {
    return jsonResponse(401, { error: "unauthorized" });
  }

  const { data: note, error: noteError } = await supabase
    .from("notes")
    .select("title, content, is_locked")
    .eq("id", noteId.trim())
    .maybeSingle();

  if (noteError) {
    console.error("Error querying note for ai-summary:", noteError.message);
    if (noteError.code === "22P02") {
      return jsonResponse(404, { error: "not_found" });
    }
    return jsonResponse(500, { error: "db_error" });
  }

  if (!note) {
    return jsonResponse(404, { error: "not_found" });
  }

  // 5. Không tóm tắt note đang khóa và kiểm tra độ dài tối thiểu
  if (note.is_locked === true) {
    return jsonResponse(400, { error: "locked" });
  }

  const title = typeof note.title === "string" ? note.title : "";
  const content = typeof note.content === "string" ? note.content : "";

  if (content.trim().length < MIN_CONTENT_CHARS) {
    return jsonResponse(400, { error: "too_short" });
  }

  const combinedText = `${title}\n\n${content}`.slice(0, MAX_NOTE_CHARS);
  const prompt =
    "Summarize the following note in 2-4 short bullet points. Write in the same language as the note. Only use information in the note, do not add anything.\n\n---\n" +
    combinedText;

  // 6. Gọi Google Gemini API với timeout 30 giây
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), GEMINI_TIMEOUT_MS);

  try {
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(geminiModel)}:generateContent`;

    const geminiRes = await fetch(geminiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": geminiApiKey,
      },
      body: JSON.stringify({
        contents: [
          {
            role: "user",
            parts: [{ text: prompt }],
          },
        ],
      }),
      signal: controller.signal,
    });

    if (!geminiRes.ok) {
      const errText = await geminiRes.text();
      console.error(
        `Gemini API returned HTTP ${geminiRes.status}:`,
        errText,
      );
      return jsonResponse(502, { error: "ai_failed" });
    }

    const data = await geminiRes.json();
    const parts = data?.candidates?.[0]?.content?.parts;
    const summary = Array.isArray(parts)
      ? parts
          .map((p: { text?: unknown }) =>
            typeof p?.text === "string" ? p.text : "",
          )
          .join("")
          .trim()
      : "";

    if (!summary) {
      console.error("Gemini API returned empty summary payload");
      return jsonResponse(502, { error: "ai_failed" });
    }

    return jsonResponse(200, { summary });
  } catch (err) {
    console.error("Gemini API request failed or timed out:", err);
    return jsonResponse(502, { error: "ai_failed" });
  } finally {
    clearTimeout(timeoutId);
  }
});