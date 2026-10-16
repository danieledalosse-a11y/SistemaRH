-- 127_dp_rls_bonus_gestor.sql
-- Permite que o Gestor consulte dp_resultados_bonus para os colaboradores
-- da própria equipe, via cadeia: bonus → resultado → avaliacao → participante → equipe.
-- Segue o mesmo padrão das políticas em 113_dp_rls_gestor.sql.
-- Apenas SELECT — escrita permanece restrita a rh/admin/diretoria.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename  = 'dp_resultados_bonus'
      AND policyname = 'dp_resultados_bonus_gestor_sel'
  ) THEN
    CREATE POLICY dp_resultados_bonus_gestor_sel ON dp_resultados_bonus
      FOR SELECT TO authenticated
      USING (
        auth_perfil() = 'gestor'
        AND resultado_id IN (
          SELECT r.id FROM dp_resultados r
          JOIN dp_avaliacoes a ON a.id = r.avaliacao_id
          JOIN dp_ciclo_participantes cp ON cp.id = a.participante_id
          WHERE cp.colaborador_id = ANY(SELECT auth_gestor_equipe_ids())
            AND a.tipo_avaliador_id IN (
              SELECT id FROM dp_tipos_avaliador WHERE codigo = 'gestor_direto'
            )
        )
      );
  END IF;
END $$;
