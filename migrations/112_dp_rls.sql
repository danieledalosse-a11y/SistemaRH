-- 112_dp_rls.sql
-- Habilita RLS nas 21 tabelas dp_* e define políticas por perfil.
-- Fase 1: RH/admin com acesso completo. Diretoria somente leitura (exceto financeiro).
-- Gestor: sem acesso direto — será definido na fase 2 com escopo por equipe.
-- anon: sem política = negado por padrão em todas as tabelas dp_*.
-- Idempotente: verifica pg_policies antes de criar cada política.
-- Funções auth_perfil() e auth_colaborador_id() definidas em migration 048.

-- ============================================================
-- Helper interno: cria política somente se não existir
-- ============================================================

CREATE OR REPLACE FUNCTION _dp_create_policy_if_not_exists(
  p_name  TEXT,
  p_table TEXT,
  p_sql   TEXT
) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = p_table
      AND policyname = p_name
  ) THEN
    EXECUTE p_sql;
  END IF;
END;
$$;

-- ============================================================
-- GRUPO 1 — Configuração (11 tabelas)
-- SELECT: rh, admin, diretoria
-- INSERT/UPDATE/DELETE: rh, admin
-- ============================================================

ALTER TABLE dp_criterios            ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_escalas              ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_escala_opcoes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_modelos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versoes              ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versao_blocos        ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_versao_criterios     ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_tipos_avaliador      ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_tipos_calculo_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_tabelas_conceito     ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_faixas_conceito      ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE tbl TEXT; BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'dp_criterios','dp_escalas','dp_escala_opcoes','dp_modelos',
    'dp_versoes','dp_versao_blocos','dp_versao_criterios',
    'dp_tipos_avaliador','dp_tipos_calculo_config',
    'dp_tabelas_conceito','dp_faixas_conceito'
  ] LOOP
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_sel', tbl,
      format('CREATE POLICY %I ON %I FOR SELECT TO authenticated
              USING (auth_perfil() IN (''admin'',''rh'',''diretoria''))',
             tbl||'_sel', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_ins', tbl,
      format('CREATE POLICY %I ON %I FOR INSERT TO authenticated
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_ins', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_upd', tbl,
      format('CREATE POLICY %I ON %I FOR UPDATE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_upd', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_del', tbl,
      format('CREATE POLICY %I ON %I FOR DELETE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_del', tbl)
    );
  END LOOP;
END $$;

-- ============================================================
-- GRUPO 2 — Operacional (5 tabelas)
-- SELECT: rh, admin, diretoria
-- INSERT/UPDATE/DELETE: rh, admin
-- Gestor: sem acesso nesta fase
-- ============================================================

ALTER TABLE dp_ciclos              ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_ciclo_participantes ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_avaliacoes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_respostas           ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_resultados          ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE tbl TEXT; BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'dp_ciclos','dp_ciclo_participantes',
    'dp_avaliacoes','dp_respostas','dp_resultados'
  ] LOOP
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_sel', tbl,
      format('CREATE POLICY %I ON %I FOR SELECT TO authenticated
              USING (auth_perfil() IN (''admin'',''rh'',''diretoria''))',
             tbl||'_sel', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_ins', tbl,
      format('CREATE POLICY %I ON %I FOR INSERT TO authenticated
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_ins', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_upd', tbl,
      format('CREATE POLICY %I ON %I FOR UPDATE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_upd', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_del', tbl,
      format('CREATE POLICY %I ON %I FOR DELETE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_del', tbl)
    );
  END LOOP;
END $$;

-- ============================================================
-- GRUPO 3 — Histórico (1 tabela) — append-only
-- SELECT: rh, admin, diretoria
-- INSERT: rh, admin
-- UPDATE/DELETE: sem política = negado por padrão
-- ============================================================

ALTER TABLE dp_historico_eventos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  PERFORM _dp_create_policy_if_not_exists(
    'dp_historico_sel', 'dp_historico_eventos',
    'CREATE POLICY dp_historico_sel ON dp_historico_eventos
     FOR SELECT TO authenticated
     USING (auth_perfil() IN (''admin'',''rh'',''diretoria''))'
  );
  PERFORM _dp_create_policy_if_not_exists(
    'dp_historico_ins', 'dp_historico_eventos',
    'CREATE POLICY dp_historico_ins ON dp_historico_eventos
     FOR INSERT TO authenticated
     WITH CHECK (auth_perfil() IN (''admin'',''rh''))'
  );
END $$;

-- ============================================================
-- GRUPO 4 — Financeiro (4 tabelas)
-- SELECT/INSERT/UPDATE/DELETE: rh, admin apenas
-- Diretoria: sem acesso direto a dados financeiros individuais
-- ============================================================

ALTER TABLE dp_regras_financeiras         ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_regra_financeira_opcoes    ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_regra_financeira_faixas    ENABLE ROW LEVEL SECURITY;
ALTER TABLE dp_resultados_financeiros     ENABLE ROW LEVEL SECURITY;

DO $$ DECLARE tbl TEXT; BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'dp_regras_financeiras','dp_regra_financeira_opcoes',
    'dp_regra_financeira_faixas','dp_resultados_financeiros'
  ] LOOP
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_sel', tbl,
      format('CREATE POLICY %I ON %I FOR SELECT TO authenticated
              USING (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_sel', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_ins', tbl,
      format('CREATE POLICY %I ON %I FOR INSERT TO authenticated
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_ins', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_upd', tbl,
      format('CREATE POLICY %I ON %I FOR UPDATE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))
              WITH CHECK (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_upd', tbl)
    );
    PERFORM _dp_create_policy_if_not_exists(
      tbl||'_del', tbl,
      format('CREATE POLICY %I ON %I FOR DELETE TO authenticated
              USING  (auth_perfil() IN (''admin'',''rh''))',
             tbl||'_del', tbl)
    );
  END LOOP;
END $$;

-- ============================================================
-- Limpeza: remove helper temporário
-- ============================================================

DROP FUNCTION _dp_create_policy_if_not_exists(TEXT, TEXT, TEXT);
