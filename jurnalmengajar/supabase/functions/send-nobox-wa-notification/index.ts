import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Nobox AI WhatsApp Service Configuration
const NOBOX_API_KEY = Deno.env.get("NOBOX_WA_API_KEY") || "Nobox-2e4323d173294c3ab4a72709740af1cf";
const NOBOX_API_URL = Deno.env.get("NOBOX_WA_API_URL") || "https://id.nobox.ai/Inbox/Send";
const NOBOX_ACCOUNT_ID = Deno.env.get("NOBOX_ACCOUNT_ID") || "829936240919301";
const NOBOX_CHANNEL_ID = Deno.env.get("NOBOX_CHANNEL_ID") || "1";

// Default test phone number if student parent phone is not explicitly set
const DEFAULT_PARENT_PHONE = "082230090067";

serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Received Nobox AI WA Trigger Payload:", JSON.stringify(payload));

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { student_name, student_id, status_type, date, subject_name, class_name, parent_phone, note } = payload;

    // ExtId is the recipient phone number (e.g. 082230090067)
    let rawPhone = parent_phone ? String(parent_phone).trim() : "";
    if (!rawPhone || rawPhone === "" || rawPhone === "null" || rawPhone === "undefined") {
      rawPhone = DEFAULT_PARENT_PHONE;
    }

    // Determine message content (use custom_message if provided, else format exact absence template)
    let waMessage = payload.custom_message || payload.message;

    if (!waMessage) {
      const reasonText =
        status_type === "S" || status_type === "Sakit"
          ? "Sakit"
          : status_type === "I" || status_type === "Izin"
          ? "Izin"
          : "Tanpa Keterangan (Alpha)";

      // Build User Requested WhatsApp Absence Template
      waMessage = `📢 *NOTIFIKASI ABSENSI SISWA*

Yth. Orang Tua/Wali dari *${student_name || "Siswa"}*,

Menginfokan bahwa pada:
📅 Tanggal: ${date || new Date().toLocaleDateString("id-ID")}
📚 Mata Pelajaran: ${subject_name || "Mata Pelajaran"}${class_name ? ` (${class_name})` : ""}

Pemberitahuan: Anak Anda tidak masuk karena: *${reasonText}*

Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.
Terima kasih.

_Auto-Notifier powered by Nobox AI_`;
    }

    // Prepare exact Postman body structure for Nobox API
    const noboxPayload = {
      ExtId: rawPhone,
      ChannelId: NOBOX_CHANNEL_ID,
      AccountIds: NOBOX_ACCOUNT_ID,
      BodyType: "Text",
      Body: waMessage,
      Attachment: "",
    };

    console.log(`Sending Nobox AI WA to ${rawPhone} via ${NOBOX_API_URL}...`);

    let apiResult = null;
    let isSuccess = false;

    try {
      const response = await fetch(NOBOX_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${NOBOX_API_KEY}`,
          "api-key": NOBOX_API_KEY,
          "x-api-key": NOBOX_API_KEY,
          "Token": NOBOX_API_KEY,
        },
        body: JSON.stringify(noboxPayload),
      });

      const textResponse = await response.text();
      console.log(`Nobox Response [Status ${response.status}]:`, textResponse);

      try {
        apiResult = JSON.parse(textResponse);
      } catch (_) {
        apiResult = { status: response.status, body: textResponse };
      }
      isSuccess = response.ok || response.status === 200 || response.status === 201;
    } catch (err: any) {
      console.error("Failed connecting to Nobox API:", err.message);
      apiResult = { error: err.message };
    }

    return new Response(
      JSON.stringify({
        success: isSuccess,
        recipient_ext_id: rawPhone,
        nobox_response: apiResult,
        message_sent: waMessage,
      }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    console.error("Error in send-nobox-wa-notification Edge Function:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
