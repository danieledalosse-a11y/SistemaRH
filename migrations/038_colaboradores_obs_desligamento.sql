-- Migration 038: Adicionar observacao_desligamento em colaboradores
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS obs_desligamento TEXT;
