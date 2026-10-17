-- Phase 3 calling hardening.
-- Call status transitions are performed by livekit-update-call (service role).
-- Clients keep SELECT access for history/realtime but cannot bypass server-side
-- authorization by updating call_sessions directly.
DROP POLICY IF EXISTS "Call participants update sessions" ON public.call_sessions;

-- Supports history views ordered newest first for each participant.
CREATE INDEX IF NOT EXISTS call_sessions_caller_created_idx
  ON public.call_sessions (caller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS call_sessions_callee_created_idx
  ON public.call_sessions (callee_id, created_at DESC);
