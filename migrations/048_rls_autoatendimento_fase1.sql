-- ─────────────────────────────────────────────────────────────────────────────
-- Migration 048: RLS Fase 1 — isolamento de dados do Colaborador
-- Tabelas: colaboradores, ferias
-- Princípio: negação por padrão. Acesso concedido explicitamente por perfil.
-- Para adicionar um novo perfil com acesso: incluir no IN (...) das 4 policies.
-- ─────────────────────────────────────────────────────────────────────────────

-- ── Funções helper (SECURITY DEFINER + search_path fixo) ─────────────────────

CREATE OR REPLACE FUNCTION auth_perfil()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT LOWER(COALESCE(perfil, ''))
  FROM   usuarios_perfil
  WHERE  user_id = auth.uid()
  LIMIT  1;
$$;

CREATE OR REPLACE FUNCTION auth_colaborador_id()
RETURNS INTEGER LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT colaborador_id
  FROM   usuarios_perfil
  WHERE  user_id = auth.uid()
  LIMIT  1;
$$;

-- ── Tabela: colaboradores ─────────────────────────────────────────────────────

ALTER TABLE colaboradores ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON colaboradores
  FOR ALL TO anon
  USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_select" ON colaboradores
  FOR SELECT TO authenticated
  USING (
    auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica')
    OR
    (auth_perfil() = 'colaborador'
     AND auth_colaborador_id() IS NOT NULL
     AND id = auth_colaborador_id())
  );

CREATE POLICY "authenticated_write" ON colaboradores
  FOR ALL TO authenticated
  USING    (auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica'))
  WITH CHECK (auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica'));

-- ── Tabela: ferias ────────────────────────────────────────────────────────────

ALTER TABLE ferias ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON ferias
  FOR ALL TO anon
  USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_select" ON ferias
  FOR SELECT TO authenticated
  USING (
    auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica')
    OR
    (auth_perfil() = 'colaborador'
     AND auth_colaborador_id() IS NOT NULL
     AND colaborador_id = auth_colaborador_id())
  );

CREATE POLICY "authenticated_write" ON ferias
  FOR ALL TO authenticated
  USING    (auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica'))
  WITH CHECK (auth_perfil() IN ('admin', 'rh', 'gestor', 'diretoria', 'logistica'));
