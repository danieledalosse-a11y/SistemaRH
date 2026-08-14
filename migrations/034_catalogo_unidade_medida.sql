-- Migration 034: Add unidade_medida to unif_catalogo (for EPI items)
ALTER TABLE unif_catalogo
  ADD COLUMN IF NOT EXISTS unidade_medida TEXT DEFAULT 'unidade';
