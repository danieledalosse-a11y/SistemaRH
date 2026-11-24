-- ============================================================
-- MIGRAÇÃO 014: Adiciona periodo_experiencia (45 ou 90 dias)
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS periodo_experiencia INTEGER; -- 45 ou 90
