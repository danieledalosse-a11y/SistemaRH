-- Marca salario_garantia e comissionado para todos os colaboradores com cargo de Vendedor
UPDATE colaboradores
SET
  salario_garantia = true,
  comissionado     = true
WHERE cargo ILIKE '%vendedor%'
  AND ativo = true;
