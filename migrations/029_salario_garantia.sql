-- Adiciona flag de salário garantia na tabela de colaboradores
-- Usado para vendedores comissionados que recebem garantia mínima mensal
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS salario_garantia boolean DEFAULT false;
