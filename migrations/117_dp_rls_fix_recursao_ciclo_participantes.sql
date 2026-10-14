-- 117_dp_rls_fix_recursao_ciclo_participantes.sql
-- Corrige recursão infinita entre dp_ciclos e dp_ciclo_participantes.
--
-- Causa raiz (structural — detectada pelo PostgreSQL antes da execução):
--   dp_ciclos_gestor_sel (migration 113):
--     USING (...  AND id IN (SELECT ciclo_id FROM dp_ciclo_participantes WHERE ...))
--   dp_ciclo_participantes_avaliador_sel (migration 116):
--     USING (... AND ciclo_id IN (SELECT id FROM dp_ciclos WHERE avaliador_id = auth.uid()))
--   → dp_ciclos → dp_ciclo_participantes → dp_ciclos → RECURSÃO INFINITA
--
-- Fix: criar função SECURITY DEFINER que lê dp_ciclos sem RLS
--       e substituir a subquery direta por chamada à função.
-- Idempotente: DROP IF EXISTS + CREATE IF NOT EXISTS.

-- ============================================================
-- BLOCO 1 — Função SECURITY DEFINER: IDs dos ciclos do avaliador
-- Lê dp_ciclos sem acionar RLS, quebrando o ciclo de referências.
-- ============================================================

CREATE OR REPLACE FUNCTION auth_avaliador_ciclo_ids()
RETURNS SETOF UUID LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT id FROM dp_ciclos WHERE avaliador_id = auth.uid();
$$;

-- ============================================================
-- BLOCO 2 — Recriar dp_ciclo_participantes_avaliador_sel
-- Remove subquery direta a dp_ciclos; usa a função acima.
-- ============================================================

DROP POLICY IF EXISTS dp_ciclo_participantes_avaliador_sel ON dp_ciclo_participantes;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename   = 'dp_ciclo_participantes'
      AND policyname  = 'dp_ciclo_participantes_avaliador_sel'
  ) THEN
    CREATE POLICY dp_ciclo_participantes_avaliador_sel ON dp_ciclo_participantes
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND ciclo_id = ANY(SELECT auth_avaliador_ciclo_ids())
      );
  END IF;
END $$;
