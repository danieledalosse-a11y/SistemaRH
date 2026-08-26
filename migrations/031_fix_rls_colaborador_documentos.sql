-- Corrige RLS: adiciona policy para usuários autenticados (JWT via Supabase Auth)
-- A policy anon_all (criada em 030) cobre a chave publishable sem login.
-- Esta cobre o access_token do usuário logado (role authenticated),
-- necessário porque o módulo Cadastro usa SB_HEADERS com Bearer do access_token.

CREATE POLICY "authenticated_all" ON colaborador_documentos
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
