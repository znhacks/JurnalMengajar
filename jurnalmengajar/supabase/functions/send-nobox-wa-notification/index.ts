/// <reference path="../global.d.ts" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOBOX_API_URL = Deno.env.get("NOBOX_WA_API_URL") || "https://id.nobox.ai/Inbox/Send";
const DEFAULT_PARENT_PHONE = "6282230090067";

serve(async (req: Request) => {
  // CORS Headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload = await req.json();
    const action = payload.action || "send_absence_notification";
    const schoolId = payload.school_id;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Resolve school-specific NoBox config
    let apiKey = "";
    let channelId = "1";
    let accountId = "";

    if (schoolId) {
      const { data: config, error: configErr } = await supabase
        .from("school_nobox_configs")
        .select("api_key, channel_id, account_id, is_active")
        .eq("school_id", schoolId)
        .maybeSingle();

      if (!configErr && config && config.api_key && config.is_active !== false) {
        apiKey = config.api_key.trim();
        channelId = config.channel_id || "1";
        accountId = config.account_id || "";
      }
    }

    // Fallback to environment variable if single-tenant environment fallback is set
    if (!apiKey) {
      apiKey = Deno.env.get("NOBOX_WA_API_KEY") || "";
      channelId = Deno.env.get("NOBOX_CHANNEL_ID") || "1";
      accountId = Deno.env.get("NOBOX_ACCOUNT_ID") || "";
    }

    // ─── ACTION: TEST CONNECTION ─────────────────────────────────────────────
    if (action === "test_connection") {
      if (!apiKey) {
        return new Response(
          JSON.stringify({
            success: false,
            message: "API Key NoBox belum disimpan untuk sekolah ini.",
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      // Test payload ping to NoBox API
      const testPhone = payload.test_phone ? String(payload.test_phone).replace(/\D/g, "") : DEFAULT_PARENT_PHONE;
      const testPayload = {
        ExtId: testPhone.startsWith("0") ? "62" + testPhone.slice(1) : testPhone,
        ChannelId: channelId || "1",
        AccountIds: accountId || "",
        BodyType: "Text",
        Body: "🔔 Tes Koneksi Integrasi NoBox.ai Jurnal Mengajar berhasil terhubung.",
        Attachment: "",
      };

      let isSuccess = false;
      let statusText = "Gagal terhubung ke NoBox.ai";

      try {
        const testRes = await fetch(NOBOX_API_URL, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${apiKey}`,
            "api-key": apiKey,
            "x-api-key": apiKey,
            "Token": apiKey,
          },
          body: JSON.stringify(testPayload),
        });

        const rawText = await testRes.text();
        // Status 200, 201 or 202 is considered healthy
        if (testRes.ok || testRes.status === 200 || testRes.status === 201 || testRes.status === 202) {
          isSuccess = true;
          statusText = "Koneksi NoBox.ai berhasil diverifikasi!";
        } else {
          statusText = `NoBox API mengembalikan respon status: ${testRes.status}`;
        }
      } catch (connErr: any) {
        statusText = `Koneksi timeout / gagal: ${connErr.message || "Tidak dapat mencapai server NoBox"}`;
      }

      // Update school_nobox_configs with test result
      if (schoolId) {
        await supabase
          .from("school_nobox_configs")
          .update({
            connection_status: isSuccess ? "connected" : "failed",
            last_tested_at: new Date().toISOString(),
            last_error_message: isSuccess ? null : statusText,
          })
          .eq("school_id", schoolId);
      }

      return new Response(
        JSON.stringify({
          success: isSuccess,
          message: statusText,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ─── ACTION: SEND ABSENCE NOTIFICATION ────────────────────────────────────
    if (!apiKey) {
      console.log(`ℹ️ Skip sending NoBox WA: No API Key configured for school_id=${schoolId}`);
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "NoBox API Key belum dikonfigurasi untuk sekolah ini.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const { student_name, student_id, status_type, date, subject_name, class_name, parent_phone } = payload;

    let rawPhone = parent_phone ? String(parent_phone).trim() : "";
    if (!rawPhone || rawPhone === "" || rawPhone === "null" || rawPhone === "undefined") {
      rawPhone = DEFAULT_PARENT_PHONE;
    }

    let cleanPhone = rawPhone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "62" + cleanPhone.slice(1);
    }

    // Determine message content
    let waMessage = payload.custom_message || payload.message;
    if (!waMessage) {
      const reasonText =
        status_type === "S" || status_type === "Sakit"
          ? "Sakit"
          : status_type === "I" || status_type === "Izin"
          ? "Izin"
          : "Tanpa Keterangan (Alpha)";

      waMessage = `📢 *NOTIFIKASI ABSENSI SISWA*

Yth. Orang Tua/Wali dari *${student_name || "Siswa"}*,

Kami informasikan bahwa pada:
📅 Tanggal: ${date || new Date().toLocaleDateString("id-ID")}
📚 Mata Pelajaran: ${subject_name || "Mata Pelajaran"}${class_name ? ` (${class_name})` : ""}

Keterangan Kehadiran: *${reasonText}*

Mohon kerjasamanya untuk memantau kehadiran ananda di sekolah.
Terima kasih.

_Jurnal Mengajar - Notifikasi Otomatis_`;
    }

    const noboxPayload = {
      ExtId: cleanPhone,
      ChannelId: channelId,
      AccountIds: accountId,
      BodyType: "Text",
      Body: waMessage,
      Attachment: "",
    };

    let apiResult = null;
    let isSuccess = false;

    try {
      const response = await fetch(NOBOX_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${apiKey}`,
          "api-key": apiKey,
          "x-api-key": apiKey,
          "Token": apiKey,
        },
        body: JSON.stringify(noboxPayload),
      });

      const textResponse = await response.text();
      try {
        apiResult = JSON.parse(textResponse);
      } catch (_) {
        apiResult = { status: response.status, body: textResponse };
      }
      isSuccess = response.ok || response.status === 200 || response.status === 201;
    } catch (err: any) {
      apiResult = { error: err.message };
    }

    // Audit log without leaking credentials
    try {
      await supabase.from("notification_delivery_logs").insert({
        channel: "whatsapp",
        category: "student_absence",
        title: `Notifikasi Absensi: ${student_name || "Siswa"}`,
        status: isSuccess ? "delivered" : "failed",
        error: isSuccess ? null : (apiResult?.error || "Gagal mengirim ke gateway"),
        provider: "nobox_ai",
        source: "attendance_absence",
        source_ref: student_id || null,
        school_id: schoolId || null,
        user_id: payload.user_id || "00000000-0000-0000-0000-000000000000",
      });
    } catch (logErr) {
      console.warn("Could not insert notification delivery log:", logErr);
    }

    return new Response(
      JSON.stringify({
        success: isSuccess,
        recipient: cleanPhone.length > 6 ? cleanPhone.slice(0, 4) + "••••" + cleanPhone.slice(-3) : cleanPhone,
        nobox_response: apiResult,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error: any) {
    return new Response(
      JSON.stringify({ success: false, error: error.message || String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
