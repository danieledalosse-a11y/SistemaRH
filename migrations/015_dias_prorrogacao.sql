-- ============================================================
-- MIGRAÇÃO 015: Adiciona dias_prorrogacao na tabela colaboradores
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS dias_prorrogacao INTEGER; -- dias da 2ª etapa (prorrogação), opcional
