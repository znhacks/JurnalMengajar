-- ============================================================================
-- SUPABASE FCM PUSH NOTIFICATIONS SETUP SCRIPT
-- ============================================================================

-- 1. Add fcm_token Column to public.users Table
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS fcm_token TEXT;

COMMENT ON COLUMN public.users.fcm_token IS 'Firebase Cloud Messaging Device Token for Push Notifications';

-- 2. Create Index on fcm_token for Fast Queries
CREATE INDEX IF NOT EXISTS idx_users_fcm_token ON public.users(fcm_token);

-- ============================================================================
-- DATABASE WEBHOOK CONFIGURATION INSTRUCTIONS
-- ============================================================================
-- Webhook Name: send-fcm-notification-webhook
-- Target URL: https://<YOUR_SUPABASE_PROJECT_REF>.supabase.co/functions/v1/send-fcm-notification
-- HTTP Method: POST
-- Headers:
--   Content-Type: application/json
--   Authorization: Bearer <YOUR_SUPABASE_ANON_OR_SERVICE_ROLE_KEY>

-- Table 1: journals
-- Events: INSERT, UPDATE
-- Filter / Conditions: Notify on insert or when status changes (approved/rejected)

-- Table 2: warning_letters
-- Events: INSERT
-- Filter / Conditions: Notify on new warning letter issued
