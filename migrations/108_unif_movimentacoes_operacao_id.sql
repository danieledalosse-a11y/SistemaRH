-- Migration 108-A — estrutura para RPC de movimentações de uniformes
-- Apenas DDL. Inicialização do Almoxarifado CD em 108-D (separado por ser dado, não estrutura).

ALTER TABLE unif_movimentacoes
  ADD COLUMN IF NOT EXISTS operacao_id UUID;

CREATE INDEX IF NOT EXISTS idx_unif_mov_operacao_id
  ON unif_movimentacoes (operacao_id)
  WHERE operacao_id IS NOT NULL;

ALTER TABLE unif_almoxarifados
  ADD COLUMN IF NOT EXISTS tipo TEXT DEFAULT 'normal'
  CHECK (tipo IN ('normal', 'cd'));
