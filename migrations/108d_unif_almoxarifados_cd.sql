-- Migration 108-D — inicializa tipo = 'cd' para o Almoxarifado CD
-- Separado da 108-A: é inicialização de dado, não estrutura.
-- Depende de 108-A ter sido executada (coluna tipo deve existir).
-- Usa correspondência exata de nome — não usar ILIKE para evitar falsos positivos.

UPDATE unif_almoxarifados
  SET tipo = 'cd'
WHERE nome = 'Almoxarifado CD'
  AND tipo IS DISTINCT FROM 'cd';
