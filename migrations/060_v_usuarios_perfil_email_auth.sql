-- Migration 060: acesso seguro a dados de usuários com e-mail do Supabase Auth
-- Abandona a view (auth.users inacessível em SECURITY INVOKER para authenticated).
-- Implementa: RLS na tabela + função SECURITY DEFINER somente para admin.

-- ── 1. Remover view anterior se existir ──────────────────────────────────────
DROP VIEW IF EXISTS public.v_usuarios_perfil;

-- ── 2. Helper: verifica se o chamador é admin (SECURITY DEFINER evita recursão no RLS) ──
CREATE OR REPLACE FUNCTION public.auth_is_admin()
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.usuarios_perfil
    WHERE user_id = auth.uid() AND perfil = 'admin' AND ativo = true
  );
$$;
GRANT EXECUTE ON FUNCTION public.auth_is_admin() TO authenticated;

-- ── 3. RLS em usuarios_perfil ────────────────────────────────────────────────
ALTER TABLE public.usuarios_perfil ENABLE ROW LEVEL SECURITY;

-- SELECT: admin vê todos; qualquer autenticado vê o próprio registro (necessário para login)
CREATE POLICY "up_select" ON public.usuarios_perfil
  FOR SELECT TO authenticated
  USING (public.auth_is_admin() OR user_id = auth.uid());

-- INSERT: somente admin pode criar usuários
CREATE POLICY "up_insert" ON public.usuarios_perfil
  FOR INSERT TO authenticated
  WITH CHECK (public.auth_is_admin());

-- UPDATE: somente admin pode alterar usuários
CREATE POLICY "up_update" ON public.usuarios_perfil
  FOR UPDATE TO authenticated
  USING (public.auth_is_admin());

-- ── 4. Função SECURITY DEFINER: lista usuários com e-mail do Auth ────────────
-- Somente admin recebe dados; outros recebem conjunto vazio.
-- SECURITY DEFINER: roda como postgres → acessa auth.users legalmente.
CREATE OR REPLACE FUNCTION public.fn_get_usuarios_perfil()
RETURNS TABLE(
  id          bigint,
  user_id     uuid,
  nome        text,
  email       text,
  perfil      text,
  perfil_id   bigint,
  colaborador_id bigint,
  ativo       boolean,
  cargo       text,
  acesso_modulos jsonb,
  criado_por  text,
  alterado_por text,
  created_at  timestamptz,
  updated_at  timestamptz
)
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  SELECT
    up.id::bigint,
    up.user_id,
    up.nome,
    COALESCE(au.email, up.email)::text AS email,
    up.perfil,
    up.perfil_id::bigint,
    up.colaborador_id::bigint,
    up.ativo,
    up.cargo,
    up.acesso_modulos,
    up.criado_por,
    up.alterado_por,
    up.created_at,
    up.updated_at
  FROM public.usuarios_perfil up
  LEFT JOIN auth.users au ON au.id = up.user_id
  WHERE public.auth_is_admin()   -- retorna vazio para não-admin (sem erro)
  ORDER BY up.nome;
$$;
GRANT EXECUTE ON FUNCTION public.fn_get_usuarios_perfil() TO authenticated;
