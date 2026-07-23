import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Firebase Admin Service Account details (can be set via Deno environment secrets or fallback)
const SERVICE_ACCOUNT = JSON.parse(
  Deno.env.get("FCM_SERVICE_ACCOUNT") ||
    `{
  "type": "service_account",
  "project_id": "jurnal-mengajar-ebcc6",
  "private_key_id": "582ecb638a12d9a2d5784b43894e070fba37a6c8",
  "client_email": "firebase-adminsdk-fbsvc@jurnal-mengajar-ebcc6.iam.gserviceaccount.com"
}`
);

// Private Key for JWT generation
const PRIVATE_KEY_PEM = Deno.env.get("FCM_PRIVATE_KEY") ||
  `-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQCxNq1lb5uYaGX2
D32qVBVcB2y4qJ6B2TdXeujQXwbzm/f9bECcVOqiNLtxlQMW6lzGUnjX2LngC39k
aWfjb4J6UCKp+7muqSFqv/AWld7y5cj1FGSiGSgBg7/2UkmKCkyeWtEHNRiTeSBW
kGV4D/bUCcgTy+pLEV3UOYNHnbcksToiFeSKcz01IM/rf1RPcTidTpO8VYJ8BsZ2
b/5YPHMs1WvaLy0I4CJW8TnOC6HcIi6jvEoL7PKF4bVvnjGsXFlgAdr4jnxy3wPr
WO+GJH5H5V/ymv2sRwFYdkbgfvK3ekCA3gdp82r01IXSf2OBb+fF/HPrUd9SERrP
YtjTYAtvAgMBAAECggEAAIb8Hxgk62AsJX5ITnBvm9V90lLWHebKjl0UQkJ2H9Vv
+HYQ/yYViKQFhsH9v1y1J/Xo3CON8ge2ulLB92BGkBya7cyM8eMY8Vte2IJbpnde
kLQd1Imkn9SHhrEZ/Ooo7jOw+YeD6jRrDzbgxmmtv1XEHaL2sIB9ufrt1BG5EMfg
8ZJZuJvF6ztnrSsw8r51Df0LqP8osEI25mWh9qn1yca/t5gihT/zoIG0seCpUeo0
Q8qaVqLUpFtD6EspDsqwMhUggz+rb1dhkQx+betVlLpNkuCrGIIkCbA1i91M6irX
uipA0SHFomzo6F+Oan7ZyGYvc0zFVJCPfrEDOGpVkQKBgQDpTig1YenhBN2dUJJs
8RwdCR0zGNm+FZifEQ4CdB64kk59SCONQDJF1LIA60H0jW04FOafLeqdig7w/GEM
HEWKDa7foBpYS98wmuLnfeSZM6bwe11MOukWxG2HsDxRuGWDejyr5RcObwMe0EeS
BgSYwG3z+JX4wCwEmaHqFY229wKBgQDCc7TZOPRRrd47CrBcS2uwp8Dvrjk6AXhy
vKR26CejUZ3qLncf73GiJJmK0+EMYwYfQt1fuQc32x/gmTi/Oca+jkpSz65SFiyV
DB1x1AwJwbBBR6lhIPlsxZjZWSipkm92H5mBFc+KNlWPVaEe3tfoSy2McHluqas+
k5xKE71ZSQKBgQCLS5/UJ461S+tpVsbmBpsLdvqZHHg89rX2Gv+rVVtWRfxY7q5T
UoXxjYlt5QivE5WnS0tatNaEkv5SwczLp0GZqIvFdtjj6QDsCz34iwDmu6ErqexN
bErozgS7Y+zPufHaKyx4UUKP2pYZWq+wrqkl7pZ3eO9J4qslX/j9QzsmhwKBgH43
Mn0I7fUSgTwbnQvbXKRGzwIEOVsAV1lKPwp7eDcXJAQ8ctBE0KJpVUx6aQpsQC4M
bbrTU+8aiV90tRPSgcFwhKep7EGV6Qw51+bpt4KhuTE2PagxChVjUOpLaAxhY33t
1uql6JeS2wh1kWaDSOub2I3e98Mv2Fp+36Rpma8ZAoGBANmFW9Z4hgUOy8C+m6lV
SNKD5HmZR5vLq7dryQMRAVm/MIKgkxWulbXLTgYGxNlajUNelYBzCjM4wgZuJgwx
KU4tq/gDCClFBvcu+GCc0CJp3U6tjZiBXvjmXXvojSV3Ht8dQaw5yysXx/164q1j
QYpNQmpPJtQheqxFwR2slT1O
-----END PRIVATE KEY-----`;

// Helper: Convert PEM to CryptoKey for Web Crypto API
async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const binaryDer = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const binaryString = atob(binaryDer);
  const bytes = new Uint8Array(binaryString.length);
  for (let i = 0; i < binaryString.length; i++) {
    bytes[i] = binaryString.charCodeAt(i);
  }

  return await crypto.subtle.importKey(
    "pkcs8",
    bytes.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );
}

// Helper: Base64Url encode
function base64UrlEncode(data: Uint8Array | string): string {
  const str = typeof data === "string" ? data : String.fromCharCode(...data);
  return btoa(str)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

// Helper: Generate OAuth2 Access Token for FCM v1 API
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const claimSet = {
    iss: SERVICE_ACCOUNT.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedClaimSet = base64UrlEncode(JSON.stringify(claimSet));
  const signatureInput = `${encodedHeader}.${encodedClaimSet}`;

  const privateKey = await importPrivateKey(PRIVATE_KEY_PEM);
  const encoder = new TextEncoder();
  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    privateKey,
    encoder.encode(signatureInput)
  );

  const signature = base64UrlEncode(new Uint8Array(signatureBuffer));
  const jwt = `${signatureInput}.${signature}`;

  // Exchange JWT for Access Token
  const tokenResponse = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  return tokenData.access_token;
}

// Serve Supabase Edge Function
serve(async (req) => {
  try {
    const payload = await req.json();
    console.log("Received Webhook Payload:", JSON.stringify(payload));

    const { type, table, record, old_record } = payload;

    // Initialize Supabase Admin Client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    let targetUserId: string | null = null;
    let title = "Notifikasi Jurnal Mengajar";
    let body = "Anda mendapatkan pembaruan data baru.";
    let notificationData: Record<string, string> = {};

    // 1. Webhook Journal Trigger
    if (table === "journals") {
      if (type === "UPDATE" && record.status !== old_record?.status) {
        targetUserId = record.teacher_id;
        const isVerified = record.status === "approved" || record.status === "verified";
        const isRejected = record.status === "rejected";

        if (isVerified) {
          title = "Jurnal Terverifikasi ✅";
          body = `Selamat! Jurnal mengajar Anda pada tanggal ${record.date || ''} telah disetujui/terverifikasi.`;
        } else if (isRejected) {
          title = "Jurnal Ditolak ❌";
          const reason = record.rejection_note ? ` Catatan: "${record.rejection_note}"` : "";
          body = `Jurnal mengajar Anda pada tanggal ${record.date || ''} ditolak.${reason}`;
        } else {
          title = "Status Jurnal Diperbarui 📝";
          body = `Status jurnal mengajar Anda pada tanggal ${record.date || ''} diubah menjadi ${record.status}.`;
        }

        notificationData = {
          route: `/guru/dashboard`,
          journalId: record.id,
          status: record.status,
        };
      } else if (type === "INSERT") {
        // Find admin users to notify about new journal submission
        const { data: adminUsers } = await supabase
          .from("users")
          .select("id, fcm_token")
          .eq("role", "admin");

        if (adminUsers && adminUsers.length > 0) {
          const accessToken = await getAccessToken();

          for (const admin of adminUsers) {
            if (admin.fcm_token) {
              await sendFcmMessage(
                accessToken,
                admin.fcm_token,
                "Jurnal Baru Dibuat 📝",
                `Jurnal baru telah diisi untuk jadwal ${record.date}.`,
                { route: "/admin/verifikasi-jurnal", journalId: record.id }
              );
            }
          }

          return new Response(
            JSON.stringify({ success: true, message: "Notifications sent to admins" }),
            { headers: { "Content-Type": "application/json" } }
          );
        }
      }
    }
    // 2. Webhook Warning Letter Trigger
    else if (table === "warning_letters") {
      targetUserId = record.teacher_id;
      title = "Surat Peringatan (SP) Diterbitkan ⚠️";
      body = `Anda menerima Surat Peringatan baru: ${record.title || "Mohon periksa detail"}.`;
      notificationData = {
        route: "/guru/warning-letters",
        warningLetterId: record.id,
      };
    }
    // 3. Direct API Call (Explicit parameters)
    else if (payload.fcm_token || payload.user_id) {
      if (payload.user_id) {
        targetUserId = payload.user_id;
      }
      title = payload.title || title;
      body = payload.body || body;
      notificationData = payload.data || {};
    }

    // Retrieve FCM Token if targetUserId is available
    let fcmToken = payload.fcm_token;
    if (!fcmToken && targetUserId) {
      const { data: user } = await supabase
        .from("users")
        .select("fcm_token")
        .eq("id", targetUserId)
        .single();

      if (user) {
        fcmToken = user.fcm_token;
      }
    }

    if (!fcmToken) {
      return new Response(
        JSON.stringify({ success: false, reason: "No FCM token found for user" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // Get OAuth2 Token & Send FCM HTTP v1 Notification
    const accessToken = await getAccessToken();
    const result = await sendFcmMessage(accessToken, fcmToken, title, body, notificationData);

    return new Response(JSON.stringify({ success: true, result }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (error: any) {
    console.error("Error in Edge Function send-fcm-notification:", error);
    return new Response(
      JSON.stringify({ success: false, error: error.message || String(error) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

// Helper: Send FCM Message using FCM HTTP v1 API
async function sendFcmMessage(
  accessToken: string,
  fcmToken: string,
  title: string,
  body: string,
  data: Record<string, string>
) {
  const projectId = SERVICE_ACCOUNT.project_id || "jurnal-mengajar-ebcc6";
  const fcmEndpoint = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

  const messagePayload = {
    message: {
      token: fcmToken,
      notification: {
        title: title,
        body: body,
      },
      data: data,
      android: {
        priority: "HIGH",
        notification: {
          sound: "default",
          channel_id: "jurnal_mengajar_notifications",
        },
      },
    },
  };

  const response = await fetch(fcmEndpoint, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(messagePayload),
  });

  return await response.json();
}
