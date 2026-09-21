import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const { email, password, nome, modo, user_id } = await req.json()

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )

    // ── ATUALIZAR CREDENCIAIS ─────────────────────────────────────────────────
    if (modo === 'update') {
      if (!user_id) throw new Error('user_id é obrigatório para atualização')

      const updates: Record<string, unknown> = {}
      if (email)    updates.email    = email
      if (password) updates.password = password
      if (nome)     updates.user_metadata = { nome }

      const { error } = await admin.auth.admin.updateUserById(user_id, updates)
      if (error) throw error

      return new Response(JSON.stringify({ ok: true }), {
        headers: { ...CORS, 'Content-Type': 'application/json' },
      })
    }

    // ── CRIAR NOVO USUÁRIO ────────────────────────────────────────────────────
    if (!email || !password) throw new Error('email e password são obrigatórios')

    const { data, error } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { nome },
    })

    if (error) {
      // Se o e-mail já existe, retorna o user_id existente (idempotente)
      if (error.message.includes('already been registered') || error.message.includes('already exists')) {
        const { data: list, error: listErr } = await admin.auth.admin.listUsers()
        if (listErr) throw listErr
        const existing = list.users.find((u: { email?: string }) => u.email === email)
        if (!existing) throw new Error('Usuário já existe mas não foi possível localizar')
        return new Response(JSON.stringify({ user_id: existing.id }), {
          headers: { ...CORS, 'Content-Type': 'application/json' },
        })
      }
      throw error
    }

    return new Response(JSON.stringify({ user_id: data.user.id }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })

  } catch (err) {
    return new Response(JSON.stringify({ error: (err as Error).message }), {
      status: 400,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    })
  }
})
