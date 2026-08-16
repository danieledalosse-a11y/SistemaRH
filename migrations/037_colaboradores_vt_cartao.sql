-- Migration 037: Adicionar vt_cartao em colaboradores
-- (vt, vt_passes e vt_linha já existem desde migration 006)
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS vt_cartao TEXT;
