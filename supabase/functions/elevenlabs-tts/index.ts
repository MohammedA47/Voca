import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-supabase-client-platform, x-supabase-client-platform-version, x-supabase-client-runtime, x-supabase-client-runtime-version',
};

// Rate limits per 15 minutes
const RATE_LIMIT_ANONYMOUS = 5;
const RATE_LIMIT_AUTHENTICATED = 15;
const RATE_WINDOW_MS = 15 * 60 * 1000; // 15 minutes

// Simple bot detection patterns
const BOT_USER_AGENTS = [
  /bot/i, /crawler/i, /spider/i, /scraper/i, /curl/i, /wget/i,
  /python-requests/i, /httpie/i, /postman/i, /insomnia/i,
];

function isBot(userAgent: string | null): boolean {
  if (!userAgent) return true; // No user agent = suspicious
  return BOT_USER_AGENTS.some(pattern => pattern.test(userAgent));
}

function getClientIp(req: Request): string {
  return req.headers.get('x-forwarded-for')?.split(',')[0]?.trim()
    || req.headers.get('x-real-ip')
    || 'unknown';
}

async function checkRateLimit(
  supabaseAdmin: ReturnType<typeof createClient>,
  identifier: string,
  identifierType: 'user' | 'ip',
  limit: number,
): Promise<{ allowed: boolean; remaining: number }> {
  const windowStart = new Date(Date.now() - RATE_WINDOW_MS).toISOString();

  // Get current count in window
  const { data, error } = await supabaseAdmin
    .from('tts_rate_limits')
    .select('request_count')
    .eq('identifier', identifier)
    .eq('identifier_type', identifierType)
    .gte('window_start', windowStart)
    .order('window_start', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error('Rate limit check error:', error.message);
    // Fail open but log - don't block legitimate users on DB errors
    return { allowed: true, remaining: limit };
  }

  const currentCount = data?.request_count || 0;

  if (currentCount >= limit) {
    return { allowed: false, remaining: 0 };
  }

  // Increment or create rate limit record
  if (data) {
    await supabaseAdmin
      .from('tts_rate_limits')
      .update({ request_count: currentCount + 1 })
      .eq('identifier', identifier)
      .eq('identifier_type', identifierType)
      .gte('window_start', windowStart);
  } else {
    await supabaseAdmin
      .from('tts_rate_limits')
      .insert({
        identifier,
        identifier_type: identifierType,
        request_count: 1,
        window_start: new Date().toISOString(),
      });
  }

  return { allowed: true, remaining: limit - currentCount - 1 };
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const userAgent = req.headers.get('user-agent');

    // Block bots
    if (isBot(userAgent)) {
      console.warn('Blocked bot request:', userAgent);
      return new Response(
        JSON.stringify({ error: 'Forbidden' }),
        {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const { text, speed, voiceId: requestedVoiceId } = await req.json();

    // Input validation
    if (!text || typeof text !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Text is required and must be a string' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    const cleanText = text.trim();
    if (cleanText.length === 0) {
      return new Response(
        JSON.stringify({ error: 'Text cannot be empty' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (cleanText.length > 500) {
      return new Response(
        JSON.stringify({ error: 'Text too long (max 500 characters)' }),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      );
    }

    if (speed !== undefined && speed !== null) {
      if (typeof speed !== 'number' || speed < 0.5 || speed > 2.0) {
        return new Response(
          JSON.stringify({ error: 'Speed must be a number between 0.5 and 2.0' }),
          {
            status: 400,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          }
        );
      }
    }

    const ELEVENLABS_API_KEY = Deno.env.get("ELEVENLABS_API_KEY");
    if (!ELEVENLABS_API_KEY) {
      console.error("ELEVENLABS_API_KEY is not configured");
      throw new Error("ELEVENLABS_API_KEY is not configured");
    }

    // Create admin client for rate limiting (uses service role to bypass RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Check authentication
    let userId: string | null = null;
    const authHeader = req.headers.get('Authorization');

    if (authHeader?.startsWith('Bearer ')) {
      const token = authHeader.replace('Bearer ', '');
      // Use anon key client with user's token for auth check
      const supabaseAuth = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        { global: { headers: { Authorization: authHeader } } }
      );
      const { data, error } = await supabaseAuth.auth.getUser(token);
      if (!error && data?.user) {
        userId = data.user.id;
      }
    }

    // Apply rate limiting based on auth status
    const identifier = userId || getClientIp(req);
    const identifierType: 'user' | 'ip' = userId ? 'user' : 'ip';
    const limit = userId ? RATE_LIMIT_AUTHENTICATED : RATE_LIMIT_ANONYMOUS;

    const { allowed, remaining } = await checkRateLimit(
      supabaseAdmin, identifier, identifierType, limit
    );

    if (!allowed) {
      console.warn(`Rate limit exceeded for ${identifierType}: ${identifier}`);
      return new Response(
        JSON.stringify({
          error: 'Rate limit exceeded. Please try again later.',
          ...(userId ? {} : { hint: 'Sign in for a higher usage limit.' }),
        }),
        {
          status: 429,
          headers: {
            ...corsHeaders,
            'Content-Type': 'application/json',
            'Retry-After': '3600',
          },
        }
      );
    }

    // Validate voiceId
    const allowedVoiceIds = [
      'JBFqnCBsd6RMkjVDRZzb', // George - British male
      'cjVigY5qzO86Huf0OWal', // Eric - American male
    ];

    const voiceId = requestedVoiceId && allowedVoiceIds.includes(requestedVoiceId)
      ? requestedVoiceId
      : 'JBFqnCBsd6RMkjVDRZzb';

    console.log(`TTS request: user=${userId || 'anonymous'}, text="${cleanText.substring(0, 30)}...", remaining=${remaining}`);

    const response = await fetch(
      `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}?output_format=mp3_44100_128`,
      {
        method: "POST",
        headers: {
          "xi-api-key": ELEVENLABS_API_KEY,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          text: cleanText,
          model_id: "eleven_turbo_v2_5",
          voice_settings: {
            stability: 0.5,
            similarity_boost: 0.75,
            style: 0.3,
            use_speaker_boost: true,
            speed: speed || 1.0,
          },
        }),
      }
    );

    if (!response.ok) {
      const contentType = response.headers.get("content-type") || "";
      let errorBody: unknown = null;
      try {
        if (contentType.includes("application/json")) {
          errorBody = await response.json();
        } else {
          errorBody = await response.text();
        }
      } catch {
        // ignore parse errors
      }

      console.error("ElevenLabs API error:", response.status, errorBody);

      return new Response(
        JSON.stringify({
          error: `TTS service error`,
          status: response.status,
        }),
        {
          status: response.status,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const audioBuffer = await response.arrayBuffer();

    return new Response(audioBuffer, {
      headers: {
        ...corsHeaders,
        "Content-Type": "audio/mpeg",
      },
    });
  } catch (error) {
    console.error("TTS error:", error);
    return new Response(
      JSON.stringify({ error: "An unexpected error occurred" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
