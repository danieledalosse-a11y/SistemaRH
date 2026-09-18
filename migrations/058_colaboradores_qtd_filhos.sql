-- Adiciona qtd_filhos na tabela colaboradores
-- (a coluna possui_filhos TEXT já existe desde migration 006)
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS qtd_filhos INTEGER;
