-- Migration 060: acesso seguro a dados de usuários com e-mail do Supabase Auth
-- RLS na tabela + função SECURITY DEFINER com regra parametrizada.
--
-- REGRA DE ACESSO: quem pode listar/gerir usuários é determinado pela tabela `perfis`
-- (coluna `modulos` JSONB). Qualquer perfil que contenha 'parametros' em seus módulos
-- tem acesso — sem nenhum perfil, user_id ou string de papel fixo no código.
-- Hoje apenas o perfil Admin tem 'parametros', mas isso é configurável em Parâmetros → Perfis.

-- ── 1. Remover view anterior se existir ──────────────────────────────────────
DROP VIEW IF EXISTS public.v_usuarios_perfil;

-- ── 2. Helper: verifica acesso a 'parametros' via tabela perfis (parametrizado) ─
-- SECURITY DEFINER: roda como postgres para evitar recursão de RLS.
-- Não há nenhuma string de perfil fixo: a regra vem de perfis.modulos no banco.
CREATE OR REPLACE FUNCTION public.auth_pode_gerir_usuarios()
RETURNS boolean
SECURITY DEFINER
SET search_path = public
LANGUAGE sql STABLE AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.usuarios_perfil up
    JOIN public.perfis p ON p.id = up.perfil_id
    WHERE up.user_id  = auth.uid()
      AND up.ativo    = true
      AND p.ativo     = true
      AND p.modulos  @> '["parametros"]'::jsonb
  );
$$;
GRANT EXECUTE ON FUNCTION public.auth_pode_gerir_usuarios() TO authenticated;

-- ── 3. RLS em usuarios_perfil ────────────────────────────────────────────────
ALTER TABLE public.usuarios_perfil ENABLE ROW LEVEL SECURITY;

-- SELECT: quem pode gerir usuários vê todos; qualquer autenticado vê o próprio registro
-- (o próprio registro é necessário para o login carregar o perfil)
CREATE POLICY "up_select" ON public.usuarios_perfil
  FOR SELECT TO authenticated
  USING (public.auth_pode_gerir_usuarios() OR user_id = auth.uid());

-- INSERT: somente quem tem acesso a 'parametros'
CREATE POLICY "up_insert" ON public.usuarios_perfil
  FOR INSERT TO authenticated
  WITH CHECK (public.auth_pode_gerir_usuarios());

-- UPDATE: somente quem tem acesso a 'parametros'
CREATE POLICY "up_update" ON public.usuarios_perfil
  FOR UPDATE TO authenticated
  USING (public.auth_pode_gerir_usuarios());

-- ── 4. Função SECURITY DEFINER: lista usuários com e-mail do Auth ────────────
-- Retorna vazio para qualquer chamador sem acesso (não lança erro).
-- SECURITY DEFINER: roda como postgres → acessa auth.users legalmente.
CREATE OR REPLACE FUNCTION public.fn_get_usuarios_perfil()
RETURNS TABLE(
  id             bigint,
  user_id        uuid,
  nome           text,
  email          text,
  perfil         text,
  perfil_id      bigint,
  colaborador_id bigint,
  ativo          boolean,
  cargo          text,
  acesso_modulos jsonb,
  criado_por     text,
  alterado_por   text,
  created_at     timestamptz,
  updated_at     timestamptz
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
  WHERE public.auth_pode_gerir_usuarios()   -- retorna vazio para não-autorizados
  ORDER BY up.nome;
$$;
GRANT EXECUTE ON FUNCTION public.fn_get_usuarios_perfil() TO authenticated;
