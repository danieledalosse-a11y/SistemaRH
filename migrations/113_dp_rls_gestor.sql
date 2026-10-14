-- 113_dp_rls_gestor.sql
-- Fase 2 do RLS dp_*: acesso do Gestor à própria equipe.
-- Políticas aditivas — não remove nem altera as da migration 112.
-- Gestor: SELECT em configuração, SELECT+escrita restrita em operacional,
--         INSERT restrito em histórico (avaliacao_iniciada/concluida vinculadas à equipe).

-- ============================================================
-- Helper: IDs dos colaboradores ativos da equipe do gestor logado.
-- Fluxo: auth_colaborador_id() → param_gestor.colaborador_id → apelido
--        → colaboradores WHERE gestor ILIKE apelido AND data_demissao IS NULL
-- SECURITY DEFINER: lê param_gestor e colaboradores sem bloqueio de RLS.
-- Apelido nulo: guarda explícita — retorna zero IDs com segurança.
-- ============================================================

CREATE OR REPLACE FUNCTION auth_gestor_equipe_ids()
RETURNS SETOF INTEGER LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public AS $$
  SELECT c.id
  FROM   colaboradores c
  JOIN   param_gestor  pg ON c.gestor ILIKE pg.apelido
  WHERE  pg.colaborador_id  = auth_colaborador_id()
    AND  pg.ativo            = true
    AND  pg.apelido         IS NOT NULL
    AND  c.data_demissao    IS NULL;
$$;

-- ============================================================
-- GRUPO 1 — Configuração: SELECT para gestor (11 tabelas)
-- Necessário para renderizar o formulário de avaliação.
-- ============================================================

DO $$ DECLARE tbl TEXT; BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'dp_modelos','dp_versoes','dp_versao_blocos','dp_versao_criterios',
    'dp_criterios','dp_escalas','dp_escala_opcoes',
    'dp_tipos_avaliador','dp_tipos_calculo_config',
    'dp_tabelas_conceito','dp_faixas_conceito'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public' AND tablename = tbl AND policyname = tbl||'_gestor_sel'
    ) THEN
      EXECUTE format(
        'CREATE POLICY %I ON %I FOR SELECT TO authenticated
         USING (auth_perfil() = ''gestor'')',
        tbl||'_gestor_sel', tbl
      );
    END IF;
  END LOOP;
END $$;

-- ============================================================
-- GRUPO 2 — Operacional: SELECT e escrita por equipe
-- ============================================================

-- dp_ciclo_participantes: SELECT — equipe do gestor
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_ciclo_participantes' AND policyname='dp_ciclo_participantes_gestor_sel') THEN
    CREATE POLICY dp_ciclo_participantes_gestor_sel ON dp_ciclo_participantes
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
      );
  END IF;
END $$;

-- dp_ciclos: SELECT — apenas ciclos onde a equipe tem participante
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_ciclos' AND policyname='dp_ciclos_gestor_sel') THEN
    CREATE POLICY dp_ciclos_gestor_sel ON dp_ciclos
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND id IN (
          SELECT ciclo_id FROM dp_ciclo_participantes
          WHERE colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
        )
      );
  END IF;
END $$;

-- dp_avaliacoes: SELECT — equipe + gestor_direto
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_gestor_sel') THEN
    CREATE POLICY dp_avaliacoes_gestor_sel ON dp_avaliacoes
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND participante_id IN (
          SELECT id FROM dp_ciclo_participantes
          WHERE colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
        )
      );
  END IF;
END $$;

-- dp_avaliacoes: INSERT — equipe + gestor_direto + ciclo aberto/em_andamento
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_gestor_ins') THEN
    CREATE POLICY dp_avaliacoes_gestor_ins ON dp_avaliacoes
      FOR INSERT TO authenticated
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND participante_id IN (
          SELECT id FROM dp_ciclo_participantes
          WHERE colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
        )
        AND tipo_avaliador_id IN (
          SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
        )
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
        )
      );
  END IF;
END $$;

-- dp_avaliacoes: UPDATE — mesmas condições + avaliacao não concluída/publicada
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_avaliacoes' AND policyname='dp_avaliacoes_gestor_upd') THEN
    CREATE POLICY dp_avaliacoes_gestor_upd ON dp_avaliacoes
      FOR UPDATE TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND participante_id IN (
          SELECT id FROM dp_ciclo_participantes
          WHERE colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
        )
        AND tipo_avaliador_id IN (
          SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
        )
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
        )
        AND status NOT IN ('concluida','publicada')
      )
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND participante_id IN (
          SELECT id FROM dp_ciclo_participantes
          WHERE colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
        )
        AND tipo_avaliador_id IN (
          SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
        )
        AND ciclo_id IN (
          SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
        )
      );
  END IF;
END $$;

-- dp_respostas: SELECT — via avaliacao gestor_direto da equipe
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_gestor_sel') THEN
    CREATE POLICY dp_respostas_gestor_sel ON dp_respostas
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
        )
      );
  END IF;
END $$;

-- dp_respostas: INSERT — avaliacao gestor_direto da equipe + ciclo aberto
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_gestor_ins') THEN
    CREATE POLICY dp_respostas_gestor_ins ON dp_respostas
      FOR INSERT TO authenticated
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
            AND a.ciclo_id IN (
              SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
            )
            AND a.status NOT IN ('concluida','publicada')
        )
      );
  END IF;
END $$;

-- dp_respostas: UPDATE — mesmas condições
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_respostas' AND policyname='dp_respostas_gestor_upd') THEN
    CREATE POLICY dp_respostas_gestor_upd ON dp_respostas
      FOR UPDATE TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
            AND a.ciclo_id IN (
              SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
            )
            AND a.status NOT IN ('concluida','publicada')
        )
      )
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
            AND a.ciclo_id IN (
              SELECT id FROM dp_ciclos WHERE status IN ('aberto','em_andamento')
            )
        )
      );
  END IF;
END $$;

-- dp_resultados: SELECT — equipe + gestor_direto apenas
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados' AND policyname='dp_resultados_gestor_sel') THEN
    CREATE POLICY dp_resultados_gestor_sel ON dp_resultados
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND avaliacao_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
        )
      );
  END IF;
END $$;

-- ============================================================
-- GRUPO 3 — Histórico: INSERT restrito a eventos de avaliação da equipe
-- Tipos: avaliacao_iniciada, avaliacao_concluida
-- entidade_id: deve corresponder a avaliacao gestor_direto da equipe
-- usuario_id: preenchido pelo banco via DEFAULT auth.uid() — não injetável
-- ============================================================

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_historico_eventos' AND policyname='dp_historico_gestor_ins') THEN
    CREATE POLICY dp_historico_gestor_ins ON dp_historico_eventos
      FOR INSERT TO authenticated
      WITH CHECK (
        auth_perfil() = 'gestor'
        AND tipo IN ('avaliacao_iniciada','avaliacao_concluida')
        AND entidade = 'dp_avaliacoes'
        AND entidade_id IN (
          SELECT a.id FROM dp_avaliacoes a
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
        )
      );
  END IF;
END $$;
