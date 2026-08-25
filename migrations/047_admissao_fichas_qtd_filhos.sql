-- Adiciona coluna qtd_filhos na tabela admissao_fichas
ALTER TABLE admissao_fichas
  ADD COLUMN IF NOT EXISTS qtd_filhos INTEGER;
