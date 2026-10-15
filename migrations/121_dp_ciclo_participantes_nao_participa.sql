-- 121_dp_ciclo_participantes_nao_participa.sql
-- Adiciona colunas de não participação em dp_ciclo_participantes.
-- motivo_id: FK nullable para rastreabilidade por tipo.
-- motivo: snapshot imutável do texto no momento do registro.
-- CHECK garante que motivo seja obrigatório ao marcar o flag.

ALTER TABLE dp_ciclo_participantes
  ADD COLUMN IF NOT EXISTS nao_participa          BOOLEAN     NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS nao_participa_motivo_id UUID        REFERENCES dp_param_motivos_nao_participacao(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS nao_participa_motivo    TEXT,
  ADD COLUMN IF NOT EXISTS nao_participa_obs       TEXT,
  ADD COLUMN IF NOT EXISTS nao_participa_em        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS nao_participa_por       UUID        REFERENCES auth.users(id);

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'dp_ciclo_part_nao_participa_motivo_check'
  ) THEN
    ALTER TABLE dp_ciclo_participantes
      ADD CONSTRAINT dp_ciclo_part_nao_participa_motivo_check
      CHECK (
        nao_participa = FALSE
        OR (nao_participa = TRUE AND nao_participa_motivo IS NOT NULL AND nao_participa_motivo <> '')
      );
  END IF;
END $$;
