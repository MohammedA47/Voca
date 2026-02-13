
-- Table to track TTS API usage per IP (anonymous) and per user (authenticated)
CREATE TABLE public.tts_rate_limits (
  id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  identifier TEXT NOT NULL, -- user_id for logged-in, IP for anonymous
  identifier_type TEXT NOT NULL CHECK (identifier_type IN ('user', 'ip')),
  request_count INTEGER NOT NULL DEFAULT 1,
  window_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Index for fast lookups
CREATE INDEX idx_tts_rate_limits_lookup ON public.tts_rate_limits (identifier, identifier_type, window_start);

-- Enable RLS
ALTER TABLE public.tts_rate_limits ENABLE ROW LEVEL SECURITY;

-- Only service role can access this table (edge functions use service role)
-- No public policies needed - this is managed server-side only
