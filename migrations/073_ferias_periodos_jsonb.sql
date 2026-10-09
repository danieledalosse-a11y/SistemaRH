-- Migration 073: Adiciona coluna periodos JSONB à tabela ferias
-- Execute no Supabase SQL Editor
-- Data: 2026-10-09

-- 1. Adiciona a coluna com default de array vazio
ALTER TABLE ferias
  ADD COLUMN IF NOT EXISTS periodos JSONB NOT NULL DEFAULT '[]'::jsonb;

-- 2. Índice GIN para queries dentro do array (opcional mas recomendado)
CREATE INDEX IF NOT EXISTS idx_ferias_periodos ON ferias USING GIN (periodos);

-- Verificação: deve retornar 0 (nenhuma linha com periodos não-array)
-- SELECT COUNT(*) FROM ferias WHERE jsonb_typeof(periodos) != 'array';
