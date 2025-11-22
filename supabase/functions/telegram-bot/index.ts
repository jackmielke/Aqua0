import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface TelegramUpdate {
  update_id: number;
  message?: {
    message_id: number;
    from: {
      id: number;
      is_bot: boolean;
      first_name: string;
      last_name?: string;
      username?: string;
    };
    chat: {
      id: number;
      type: string;
    };
    text?: string;
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const TELEGRAM_BOT_TOKEN = Deno.env.get('TELEGRAM_BOT_TOKEN');
    const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
    const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

    if (!TELEGRAM_BOT_TOKEN || !SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
      throw new Error('Missing required environment variables');
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Parse Telegram update
    const update: TelegramUpdate = await req.json();
    console.log('Received update:', JSON.stringify(update, null, 2));

    if (!update.message) {
      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const message = update.message;
    const user = message.from;
    const chatId = message.chat.id;
    const text = message.text || '';

    // Store or update user in database
    const { data: existingUser, error: fetchError } = await supabase
      .from('users')
      .select('*')
      .eq('telegram_id', user.id)
      .maybeSingle();

    if (fetchError) {
      console.error('Error fetching user:', fetchError);
    }

    if (!existingUser) {
      // Create new user
      const { error: insertError } = await supabase
        .from('users')
        .insert({
          telegram_id: user.id,
          telegram_username: user.username,
          telegram_first_name: user.first_name,
          telegram_last_name: user.last_name,
        });

      if (insertError) {
        console.error('Error creating user:', insertError);
      }
    } else {
      // Update existing user
      const { error: updateError } = await supabase
        .from('users')
        .update({
          telegram_username: user.username,
          telegram_first_name: user.first_name,
          telegram_last_name: user.last_name,
        })
        .eq('telegram_id', user.id);

      if (updateError) {
        console.error('Error updating user:', updateError);
      }
    }

    // Handle commands
    let responseText = '';

    if (text === '/start') {
      responseText = `Welcome to Vibe Maxing! 🚀

I'm your crypto payment bot powered by World ID verification.

Available commands:
/start - Show this welcome message
/verify - Verify your World ID (coming soon)
/balance - Check your balance (coming soon)
/send - Send crypto to friends (coming soon)

Let's get started by verifying you're a real human with World ID!`;
    } else if (text === '/verify') {
      if (existingUser?.world_id_verified) {
        responseText = `✅ You're already verified with World ID!

Connected wallet: ${existingUser.wallet_address || 'Not connected yet'}

Ready to send and receive crypto with verified humans.`;
      } else {
        responseText = `🌍 World ID Verification

To use this bot for crypto payments, you need to verify you're a real human with World ID.

Most people already have World ID from their World App! We'll just check if you're verified.

Verification coming soon - we're building the integration now!`;
      }
    } else if (text === '/balance') {
      responseText = '💰 Balance checking coming soon! First, complete World ID verification.';
    } else if (text.startsWith('/send')) {
      responseText = '💸 Sending crypto coming soon! First, complete World ID verification.';
    } else if (text) {
      responseText = `I received: "${text}"

Try these commands:
/start - Get started
/verify - Verify with World ID
/balance - Check your balance
/send - Send crypto to friends`;
    }

    // Send response to Telegram
    if (responseText) {
      await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: chatId,
          text: responseText,
          parse_mode: 'Markdown',
        }),
      });
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (error) {
    console.error('Error in telegram-bot function:', error);
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
