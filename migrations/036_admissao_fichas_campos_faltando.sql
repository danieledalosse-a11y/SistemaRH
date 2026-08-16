-- Migration 036: Adicionar colunas faltando em admissao_fichas
-- (estado_naturalidade, campos de endereço, vt_cartao, vt_passes)
ALTER TABLE admissao_fichas
  ADD COLUMN IF NOT EXISTS estado_naturalidade TEXT,
  ADD COLUMN IF NOT EXISTS numero             TEXT,
  ADD COLUMN IF NOT EXISTS complemento        TEXT,
  ADD COLUMN IF NOT EXISTS bairro             TEXT,
  ADD COLUMN IF NOT EXISTS vt_cartao          TEXT,
  ADD COLUMN IF NOT EXISTS vt_passes          INTEGER;
