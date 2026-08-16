import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { email, password, nome } = await req.json()
    if (!email || !password) throw new Error('email e password são obrigatórios')

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    let userId: string

    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nome },
    })

    if (error) {
      // Se o e-mail já existe, busca o user_id existente
      if (error.message.includes('already been registered') || error.message.includes('already exists')) {
        const { data: list, error: listErr } = await admin.auth.admin.listUsers()
        if (listErr) throw listErr
        const existing = list.users.find(u => u.email === email)
        if (!existing) throw new Error('Usuário já existe mas não foi possível localizar')
        userId = existing.id
      } else {
        throw error
      }
    } else {
      userId = data.user.id
    }

    return new Response(JSON.stringify({ user_id: userId }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
