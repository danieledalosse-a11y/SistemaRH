-- Campo de indicação na tabela colaboradores
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS indicado_por_id BIGINT REFERENCES colaboradores(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS indicacao_bonus_gerado BOOLEAN DEFAULT FALSE;

-- Índice para facilitar consulta dos indicados por colaborador
CREATE INDEX IF NOT EXISTS idx_colaboradores_indicado_por ON colaboradores(indicado_por_id) WHERE indicado_por_id IS NOT NULL;
