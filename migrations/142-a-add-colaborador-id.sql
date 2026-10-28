-- Migration 142-a: adiciona colaborador_id em dev_historico
-- Reversível: apenas adiciona coluna nullable, sem alterar dados existentes
-- Executar via Supabase SQL Editor

ALTER TABLE dev_historico
  ADD COLUMN IF NOT EXISTS colaborador_id integer REFERENCES colaboradores(id);

CREATE INDEX IF NOT EXISTS idx_dev_historico_colaborador_id
  ON dev_historico(colaborador_id);
