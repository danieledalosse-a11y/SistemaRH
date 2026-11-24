-- ============================================================
-- MIGRAÇÃO 016: Adiciona data_fim_contrato para contratos
--               de prazo determinado (Jovem Aprendiz, Temporário, etc.)
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS data_fim_contrato DATE;
