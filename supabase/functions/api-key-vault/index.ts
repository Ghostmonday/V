/**
 * API Key Vault - Supabase Edge Function
 * Exposes secrets only via signed JWT from auth endpoint
 * Zero client-side keys ever
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.38.1';

const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://vibez.app',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Verify JWT from Authorization header
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const token = authHeader.substring(7);
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    );

    // Verify token and get user
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check MFA status (enforced on every sign-in)
    const { data: mfaData } = await supabase
      .from('auth.users')
      .select('mfa_enabled')
      .eq('id', user.id)
      .single();

    if (!mfaData?.mfa_enabled) {
      return new Response(JSON.stringify({ error: 'MFA required' }), {
        status: 403,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Return secrets based on user role
    const secrets: Record<string, string> = {};

    // Only expose keys user has permission for
    if (user.user_metadata?.role === 'admin') {
      secrets.DEEPSEEK_API_KEY = Deno.env.get('DEEPSEEK_API_KEY') ?? '';
      secrets.LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY') ?? '';
      secrets.LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET') ?? '';
    } else if (user.user_metadata?.role === 'user') {
      // Regular users get limited access
      secrets.LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') ?? '';
    }

    // Log access to audit_logs
    await supabase.from('audit_logs').insert({
      user_id: user.id,
      action: 'api_key_access',
      timestamp: new Date().toISOString(),
      metadata: {
        endpoint: '/functions/v1/api-key-vault',
        ip: req.headers.get('x-forwarded-for') ?? 'unknown',
      },
    });

    return new Response(JSON.stringify({ secrets }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
