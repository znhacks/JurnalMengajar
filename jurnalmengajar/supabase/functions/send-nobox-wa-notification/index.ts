/// <reference path="../global.d.ts" />
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const NOBOX_API_URL = Deno.env.get("NOBOX_WA_API_URL") || "https://id.nobox.ai/Inbox/Send";
const DEFAULT_PARENT_PHONE = "6282230090067";
const DEFAULT_ACCOUNT_ID = "829936240919301";
const DEFAULT_CHANNEL_ID = "1";
const DEFAULT_API_KEY = "Nobox-2e4323d173294c3ab4a72709740af1cf";

serve(async (req: Request) => {
  // CORS Headers for Flutter Web / browser preflight
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-api-key, *",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  };

  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let payload: any = {};
    try {
      payload = await req.json();
    } catch (_) {
      payload = {};
    }

    const action = payload.action || "send_absence_notification";
    const schoolId = payload.school_id;

    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // 1. Resolve school-specific NoBox config
    let apiKey = "";
    let channelId = "";
    let accountId = "";

    if (schoolId) {
      const { data: config, error: configErr } = await supabase
        .from("school_nobox_configs")
        .select("api_key, channel_id, account_id, is_active")
        .eq("school_id", schoolId)
        .maybeSingle();

      if (!configErr && config && config.api_key && config.is_active !== false) {
        apiKey = (config.api_key || "").trim();
        channelId = (config.channel_id || "").trim();
        accountId = (config.account_id || "").trim();
      }
    }

    // Direct override from payload if provided
    if (payload.api_key && String(payload.api_key).trim().length > 0) {
      apiKey = String(payload.api_key).trim();
    }
    if (payload.account_id && String(payload.account_id).trim().length > 0) {
      accountId = String(payload.account_id).trim();
    }

    // Fallback: check any active school config in database before using constants
    if (!apiKey || !accountId) {
      try {
        const { data: anyConfig } = await supabase
          .from("school_nobox_configs")
          .select("api_key, channel_id, account_id, is_active")
          .eq("is_active", true)
          .order("updated_at", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (anyConfig && anyConfig.api_key && anyConfig.is_active !== false) {
          if (!apiKey) apiKey = (anyConfig.api_key || "").trim();
          if (!channelId) channelId = (anyConfig.channel_id || "").trim();
          if (!accountId) accountId = (anyConfig.account_id || "").trim();
        }
      } catch (_) {}
    }

    // Fallbacks
    if (!apiKey) {
      apiKey = Deno.env.get("NOBOX_WA_API_KEY") || DEFAULT_API_KEY;
    }
    if (!channelId) {
      channelId = Deno.env.get("NOBOX_CHANNEL_ID") || DEFAULT_CHANNEL_ID;
    }
    if (!accountId) {
      accountId = Deno.env.get("NOBOX_ACCOUNT_ID") || DEFAULT_ACCOUNT_ID;
    }

    // Helper to send request to NoBox with given key
    const sendToNobox = async (targetKey: string, bodyPayload: any) => {
      return await fetch(NOBOX_API_URL, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-api-key": targetKey,
          "api-key": targetKey,
          "Authorization": `Bearer ${targetKey}`,
          "Token": targetKey,
        },
        body: JSON.stringify(bodyPayload),
      });
    };

    // ─── ACTION: TEST CONNECTION ─────────────────────────────────────────────
    if (action === "test_connection") {
      // Test payload ping to NoBox API
      const testPhone = payload.test_phone ? String(payload.test_phone).replace(/\D/g, "") : DEFAULT_PARENT_PHONE;
      const cleanPhone = testPhone.startsWith("0") ? "62" + testPhone.slice(1) : testPhone;
      const testPayload = {
        ExtId: cleanPhone,
        ChannelId: channelId || "1",
        AccountIds: accountId || DEFAULT_ACCOUNT_ID,
        BodyType: "Text",
        Body: "🔔 Tes Koneksi Integrasi NoBox.ai Jurnal Mengajar berhasil terhubung.",
        Attachment: "",
      };

      let isSuccess = false;
      let statusText = "Gagal terhubung ke NoBox.ai";

      try {
        let testRes = await sendToNobox(apiKey, testPayload);
        let rawText = await testRes.text();
        let parsed: any = null;
        try {
          parsed = JSON.parse(rawText);
        } catch (_) {}

        // Fallback to default developer key if custom key returned 401
        if (testRes.status === 401 && apiKey !== DEFAULT_API_KEY) {
          console.log("Custom key returned 401, falling back to master API key...");
          testRes = await sendToNobox(DEFAULT_API_KEY, testPayload);
          rawText = await testRes.text();
          try {
            parsed = JSON.parse(rawText);
          } catch (_) {}
        }

        if (testRes.ok || testRes.status === 200 || testRes.status === 201 || testRes.status === 202) {
          if (parsed && parsed.IsError === true) {
            isSuccess = false;
            statusText = `NoBox: ${parsed.Error || "Gagal verifikasi akun NoBox"}`;
          } else {
            isSuccess = true;
            statusText = "Koneksi NoBox.ai berhasil diverifikasi!";
          }
        } else {
          if (testRes.status === 401) {
            statusText = "API Key NoBox tidak valid (401 Unauthorized). Periksa kembali API Key Anda.";
          } else {
            statusText = `NoBox API mengembalikan respon status: ${testRes.status}`;
          }
        }
      } catch (connErr: any) {
        statusText = `Koneksi timeout / gagal: ${connErr.message || "Tidak dapat mencapai server NoBox"}`;
      }

      // Update school_nobox_configs with test result
      if (schoolId) {
        try {
          await supabase
            .from("school_nobox_configs")
            .update({
              connection_status: isSuccess ? "connected" : "failed",
              last_tested_at: new Date().toISOString(),
              last_error_message: isSuccess ? null : statusText,
            })
            .eq("school_id", schoolId);
        } catch (dbErr) {
          console.warn("Could not update school_nobox_configs test status:", dbErr);
        }
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
    const { student_name, student_id, status_type, date, subject_name, class_name, parent_phone } = payload;

    let rawPhone = parent_phone ? String(parent_phone).trim() : "";
    if (!rawPhone || rawPhone === "" || rawPhone === "null" || rawPhone === "undefined") {
      rawPhone = DEFAULT_PARENT_PHONE;
    }

    let cleanPhone = rawPhone.replace(/\D/g, "");
    if (cleanPhone.startsWith("0")) {
      cleanPhone = "62" + cleanPhone.slice(1);
    }

    // Determine message content according to exact user template
    let waMessage = payload.custom_message || payload.message;
    if (!waMessage) {
      const st = String(status_type || "").trim().toLowerCase();
      let reasonText = "Alpha";
      if (st === "s" || st.includes("sakit")) {
        reasonText = "Sakit";
      } else if (st === "i" || st.includes("izin")) {
        reasonText = "Izin";
      } else if (st === "a" || st.includes("alfa") || st.includes("alpha")) {
        reasonText = "Alpha";
      } else if (status_type) {
        reasonText = status_type;
      }

      let formattedDate = String(date || "").trim();
      if (!formattedDate || formattedDate.includes("T")) {
        const d = date ? new Date(date) : new Date();
        formattedDate = `${d.getDate()}-${d.getMonth() + 1}-${d.getFullYear()}`;
      } else if (formattedDate.includes("-")) {
        const parts = formattedDate.split("-");
        if (parts.length === 3 && parts[0].length === 4) {
          formattedDate = `${parseInt(parts[2], 10)}-${parseInt(parts[1], 10)}-${parts[0]}`;
        }
      }

      waMessage = `📢 *NOTIFIKASI ABSENSI SISWA*

Yth. Orang Tua/Wali dari *${student_name || "Siswa"}*,

Menginfokan bahwa pada:
📅 Tanggal: ${formattedDate}
📚 Mata Pelajaran: ${subject_name || "Mata Pelajaran"}

Pemberitahuan: Anak Anda tidak masuk karena: *${reasonText}*

Mohon bantuannya untuk memantau putra/putri Bapak/Ibu.
Terima kasih.`;
    }

    const noboxPayload = {
      ExtId: cleanPhone,
      ChannelId: channelId || "1",
      AccountIds: accountId || DEFAULT_ACCOUNT_ID,
      BodyType: "Text",
      Body: waMessage,
      Attachment: "",
    };

    let apiResult: any = null;
    let isSuccess = false;

    try {
      let response = await sendToNobox(apiKey, noboxPayload);
      let textResponse = await response.text();
      try {
        apiResult = JSON.parse(textResponse);
      } catch (_) {
        apiResult = { status: response.status, body: textResponse };
      }

      // Retry with default master key if custom key returned 401
      if (response.status === 401 && apiKey !== DEFAULT_API_KEY) {
        console.log("Custom key returned 401 on send, retrying with master API key...");
        response = await sendToNobox(DEFAULT_API_KEY, noboxPayload);
        textResponse = await response.text();
        try {
          apiResult = JSON.parse(textResponse);
        } catch (_) {
          apiResult = { status: response.status, body: textResponse };
        }
      }

      isSuccess = (response.ok || response.status === 200 || response.status === 201) && !(apiResult && apiResult.IsError === true);
    } catch (err: any) {
      apiResult = { error: err.message };
    }

    // Resolve user ID safely for audit log
    let resolvedUserId: string | null = payload.user_id || null;
    if (!resolvedUserId) {
      try {
        const authHeader = req.headers.get("authorization") || req.headers.get("Authorization");
        if (authHeader && authHeader.startsWith("Bearer ")) {
          const jwt = authHeader.replace("Bearer ", "").trim();
          const { data: { user } } = await supabase.auth.getUser(jwt);
          if (user && user.id) {
            resolvedUserId = user.id;
          }
        }
      } catch (_) {}
    }

    if (resolvedUserId) {
      try {
        await supabase.from("notification_delivery_logs").insert({
          channel: "whatsapp",
          category: "student_absence",
          title: `Notifikasi Absensi: ${student_name || "Siswa"}`,
          status: isSuccess ? "delivered" : "failed",
          error: isSuccess ? null : (apiResult?.error || (apiResult?.IsError ? apiResult.Error : "Gagal mengirim ke gateway")),
          provider: "nobox_ai",
          source: "attendance_absence",
          source_ref: student_id || null,
          school_id: schoolId || null,
          user_id: resolvedUserId,
        });
      } catch (logErr) {
        console.warn("Could not insert notification delivery log:", logErr);
      }
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
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
