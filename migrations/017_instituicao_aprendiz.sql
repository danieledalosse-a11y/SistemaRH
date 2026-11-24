-- ============================================================
-- MIGRAÇÃO 017: Adiciona instituicao_aprendiz para Jovem Aprendiz
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS instituicao_aprendiz TEXT;
