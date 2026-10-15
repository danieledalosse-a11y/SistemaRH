-- 119_dp_rls_historico_gestor_sel.sql
-- Adiciona SELECT em dp_historico_eventos para o Gestor.
-- Completa a migration 113 (que criou apenas INSERT para gestor).
-- Âncoras: auth_avaliador_ciclo_ids() (mig. 117) para evitar recursão,
--          e avaliador_id = auth.uid() para avaliações diretas.
-- Idempotente: IF NOT EXISTS.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename   = 'dp_historico_eventos'
      AND policyname  = 'dp_historico_gestor_sel'
  ) THEN
    CREATE POLICY dp_historico_gestor_sel ON dp_historico_eventos
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND (
          -- Eventos vinculados a ciclos onde o gestor é avaliador designado
          (entidade = 'dp_ciclos'     AND entidade_id = ANY(SELECT auth_avaliador_ciclo_ids()))
          OR
          -- Eventos vinculados a avaliações do gestor
          (entidade = 'dp_avaliacoes' AND entidade_id IN (
            SELECT id FROM dp_avaliacoes WHERE avaliador_id = auth.uid()
          ))
        )
      );
  END IF;
END $$;
