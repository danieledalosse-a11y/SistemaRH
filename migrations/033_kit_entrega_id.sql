-- Agrupa itens de um kit registrado na mesma operação
-- e permite registrar itens não entregues com motivo
ALTER TABLE unif_movimentacoes
  ADD COLUMN IF NOT EXISTS kit_entrega_id UUID,
  ADD COLUMN IF NOT EXISTS motivo_pendencia TEXT;

CREATE INDEX IF NOT EXISTS idx_unif_mov_kit
  ON unif_movimentacoes(kit_entrega_id)
  WHERE kit_entrega_id IS NOT NULL;

COMMENT ON COLUMN unif_movimentacoes.kit_entrega_id IS
  'UUID gerado no front para agrupar todos os itens entregues/pendentes de um mesmo lançamento de kit';
COMMENT ON COLUMN unif_movimentacoes.motivo_pendencia IS
  'Motivo pelo qual o item não foi entregue (sem_estoque, sem_numeracao, entregar_depois, outro). Preenchido quando quantidade=0.';
