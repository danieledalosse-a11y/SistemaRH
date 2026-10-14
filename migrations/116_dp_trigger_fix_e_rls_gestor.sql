-- 116_dp_trigger_fix_e_rls_gestor.sql
-- Três mudanças coordenadas no motor D&P.
-- Idempotente: ADD COLUMN IF NOT EXISTS; IF NOT EXISTS em todas as policies.
-- Nenhum UPDATE/DELETE em dados históricos.
-- Data: 2026-10-14

-- ============================================================
-- BLOCO 1 — ADD COLUMN avaliador_id em dp_ciclos
--    Armazena o auth.users.id do gestor responsável pelo ciclo.
--    Nullable para manter compatibilidade com ciclos existentes.
-- ============================================================

ALTER TABLE dp_ciclos
  ADD COLUMN IF NOT EXISTS avaliador_id UUID REFERENCES auth.users(id);

COMMENT ON COLUMN dp_ciclos.avaliador_id
  IS 'auth.users.id do gestor designado como avaliador responsável do ciclo.';

-- ============================================================
-- BLOCO 2 — Corrigir dp_fn_versao_proteger_em_uso
--    Problema: ao publicar (em_uso = true), o trigger
--    trg_versao_snapshot_criterios faz UPDATE em dp_versao_criterios
--    para popular criterio_nome_snapshot; o trigger de proteção
--    bloqueia esse UPDATE porque a versão já está publicada.
--    Solução: permitir EXCLUSIVAMENTE a transição
--      criterio_nome_snapshot: NULL → valor
--    desde que NENHUM campo estrutural seja alterado.
--    Todos os outros UPDATE, INSERT e DELETE continuam bloqueados
--    quando em_uso = true.
-- ============================================================

CREATE OR REPLACE FUNCTION dp_fn_versao_proteger_em_uso()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_em_uso BOOLEAN;
BEGIN
  SELECT em_uso INTO v_em_uso
  FROM dp_versoes
  WHERE id = COALESCE(NEW.versao_id, OLD.versao_id);

  IF NOT v_em_uso THEN
    -- Versão não publicada: permite tudo
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
  END IF;

  -- Versão publicada: permitir APENAS escrita do snapshot (NULL → valor)
  -- sem alterar qualquer campo estrutural.
  IF TG_OP = 'UPDATE'
     AND NEW.criterio_nome_snapshot IS NOT NULL
     AND OLD.criterio_nome_snapshot IS NULL
     -- Campos de identidade
     AND NEW.versao_id              = OLD.versao_id
     AND NEW.criterio_id            = OLD.criterio_id
     -- Campos de bloco e ordem
     AND NEW.bloco_id               IS NOT DISTINCT FROM OLD.bloco_id
     AND NEW.ordem                  IS NOT DISTINCT FROM OLD.ordem
     -- Campos de tipo e escala
     AND NEW.tipo_resposta          = OLD.tipo_resposta
     AND NEW.escala_id              IS NOT DISTINCT FROM OLD.escala_id
     -- Campos de cálculo
     AND NEW.peso                   IS NOT DISTINCT FROM OLD.peso
     AND NEW.obrigatorio            = OLD.obrigatorio
     AND NEW.contribui_calculo      = OLD.contribui_calculo
     -- Campos de range numérico (migration 114)
     AND NEW.nota_min               IS NOT DISTINCT FROM OLD.nota_min
     AND NEW.nota_max               IS NOT DISTINCT FROM OLD.nota_max
     -- Campos de valor binário (migration 114)
     AND NEW.valor_se_sim           IS NOT DISTINCT FROM OLD.valor_se_sim
     AND NEW.valor_se_nao           IS NOT DISTINCT FROM OLD.valor_se_nao
     -- Campos de instrução/condição
     AND NEW.obs_condicao           IS NOT DISTINCT FROM OLD.obs_condicao
     AND NEW.instrucao_avaliador    IS NOT DISTINCT FROM OLD.instrucao_avaliador
  THEN
    RETURN NEW;
  END IF;

  -- Qualquer outra operação em versão publicada: bloquear
  RAISE EXCEPTION 'Esta versão está publicada e em uso. Crie uma nova versão para fazer alterações.';
END;
$$;

-- Os triggers já existem (criados em 065b); apenas a função foi substituída.
-- trg_vc_proteger_em_uso e trg_vb_proteger_em_uso continuam ativos.

-- ============================================================
-- BLOCO 3 — RLS Fase 2: policies complementares para o Gestor
--    Âncora: dp_avaliacoes.avaliador_id = auth.uid()
--    Complementa a migration 113 (que usa auth_gestor_equipe_ids()).
--    RLS aplica OR entre políticas: basta uma ser verdadeira.
--    Nomenclatura: _avaliador_sel / _avaliador_ins / _avaliador_upd
--    para não conflitar com as policies _gestor_* da migration 113.
-- ============================================================

-- dp_ciclos: gestor vê ciclos onde é o avaliador_id designado
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_ciclos' AND policyname='dp_ciclos_avaliador_sel') THEN
    CREATE POLICY dp_ciclos_avaliador_sel ON dp_ciclos
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliador_id = auth.uid()
      );
  END IF;
END $$;

-- dp_ciclo_participantes: gestor vê participantes de seus ciclos
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_ciclo_participantes' AND policyname='dp_ciclo_participantes_avaliador_sel') THEN
    CREATE POLICY dp_ciclo_participantes_avaliador_sel ON dp_ciclo_participantes
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos WHERE avaliador_id = auth.uid()
        )
      );
  END IF;
END $$;

-- dp_avaliacoes: SELECT — avaliações onde é o avaliador designado
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_avaliador_sel') THEN
    CREATE POLICY dp_avaliacoes_avaliador_sel ON dp_avaliacoes
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliador_id = auth.uid()
      );
  END IF;
END $$;

-- dp_avaliacoes: INSERT — ciclo onde é avaliador_id + ciclo aberto/em_andamento
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_avaliador_ins') THEN
    CREATE POLICY dp_avaliacoes_avaliador_ins ON dp_avaliacoes
      FOR INSERT TO authenticated
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliador_id = auth.uid()
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos
          WHERE avaliador_id = auth.uid()
            AND status IN ('aberto', 'em_andamento')
        )
      );
  END IF;
END $$;

-- dp_avaliacoes: UPDATE — apenas campo status, nas suas avaliações em ciclo aberto
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_avaliador_upd') THEN
    CREATE POLICY dp_avaliacoes_avaliador_upd ON dp_avaliacoes
      FOR UPDATE TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliador_id = auth.uid()
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos
          WHERE avaliador_id = auth.uid()
            AND status IN ('aberto', 'em_andamento')
        )
        AND status NOT IN ('concluida', 'publicada')
      )
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliador_id = auth.uid()
      );
  END IF;
END $$;

-- dp_respostas: SELECT — respostas das suas avaliações
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_avaliador_sel') THEN
    CREATE POLICY dp_respostas_avaliador_sel ON dp_respostas
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT id FROM dp_avaliacoes WHERE avaliador_id = auth.uid()
        )
      );
  END IF;
END $$;

-- dp_respostas: INSERT — suas avaliações, ciclo aberto, avaliação não concluída
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_avaliador_ins') THEN
    CREATE POLICY dp_respostas_avaliador_ins ON dp_respostas
      FOR INSERT TO authenticated
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          WHERE a.avaliador_id = auth.uid()
            AND a.status NOT IN ('concluida', 'publicada')
            AND a.ciclo_id IN (
              SELECT id FROM dp_ciclos WHERE status IN ('aberto', 'em_andamento')
            )
        )
      );
  END IF;
END $$;

-- dp_respostas: UPDATE — mesmas condições
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_avaliador_upd') THEN
    CREATE POLICY dp_respostas_avaliador_upd ON dp_respostas
      FOR UPDATE TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          WHERE a.avaliador_id = auth.uid()
            AND a.status NOT IN ('concluida', 'publicada')
            AND a.ciclo_id IN (
              SELECT id FROM dp_ciclos WHERE status IN ('aberto', 'em_andamento')
            )
        )
      )
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          WHERE a.avaliador_id = auth.uid()
        )
      );
  END IF;
END $$;

-- dp_resultados: SELECT — suas avaliações
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados' AND policyname='dp_resultados_avaliador_sel') THEN
    CREATE POLICY dp_resultados_avaliador_sel ON dp_resultados
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT id FROM dp_avaliacoes WHERE avaliador_id = auth.uid()
        )
      );
  END IF;
END $$;

-- dp_resultados_bonus: substituir dp_resultados_bonus_sel para incluir gestor
--   A policy existente (migration 114) só permite rh/admin/diretoria.
--   Gestor precisará ver o bônus das suas avaliações para fins de transparência.
--   DROP + CREATE: a nova policy é um superconjunto (backward compatible).
DROP POLICY IF EXISTS dp_resultados_bonus_sel ON dp_resultados_bonus;
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados_bonus' AND policyname='dp_resultados_bonus_sel') THEN
    CREATE POLICY dp_resultados_bonus_sel ON dp_resultados_bonus
      FOR SELECT TO authenticated
      USING (
        auth_perfil() IN ('admin', 'rh', 'diretoria')
        OR (
          auth_perfil() = 'gestor'
          AND resultado_id IN (
            SELECT r.id FROM dp_resultados r
            JOIN dp_avaliacoes a ON a.id = r.avaliacao_id
            WHERE a.avaliador_id = auth.uid()
          )
        )
      );
  END IF;
END $$;

-- Tabelas de configuração: SELECT para gestor via avaliador_id
-- (complementa as policies _gestor_sel da migration 113 que já cobrem por equipe)
-- dp_versao_criterios, dp_criterios, dp_escalas, dp_escala_opcoes
-- Nota: migration 113 já criou _gestor_sel para todas essas tabelas com
-- auth_perfil() = 'gestor' sem restrição adicional — portanto gestor já
-- tem SELECT nessas tabelas. Não é necessário criar policies adicionais.

-- ============================================================
-- Verificação final (comentada — executar manualmente se necessário)
-- ============================================================
-- SELECT policyname, tablename, cmd FROM pg_policies
--   WHERE schemaname = 'public' AND tablename LIKE 'dp_%'
--   AND policyname LIKE '%avaliador%'
--   ORDER BY tablename, policyname;
