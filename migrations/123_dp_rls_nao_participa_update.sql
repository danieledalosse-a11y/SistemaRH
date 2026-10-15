-- 123_dp_rls_nao_participa_update.sql
-- Política UPDATE para o flag nao_participa em dp_ciclo_participantes.
-- RH/admin: atualiza qualquer participante.
-- Gestor: somente participantes de ciclos sob sua responsabilidade
--         (usa auth_avaliador_ciclo_ids() — migration 117 — sem recursão).
-- Diretoria: sem UPDATE.

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename   = 'dp_ciclo_participantes'
      AND policyname  = 'dp_ciclo_part_nao_participa_upd'
  ) THEN
    CREATE POLICY dp_ciclo_part_nao_participa_upd ON dp_ciclo_participantes
      FOR UPDATE TO authenticated
      USING (
        auth_perfil() IN ('rh','admin')
        OR (
          auth_perfil() = 'gestor'
          AND ciclo_id = ANY(SELECT auth_avaliador_ciclo_ids())
        )
      );
  END IF;
END $$;
