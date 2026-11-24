-- ============================================================
-- MIGRAÇÃO 009: Normaliza empresa_registro em colaboradores
-- Converte "148 - Matriz Adm", "148 - Matriz Vendas" etc.
-- para nome_simplificado de param_empresa (ex: "Matriz").
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- PASSO 1: Diagnóstico — confirme o mapeamento antes de alterar
SELECT
  c.empresa_registro       AS valor_atual,
  pe.nome_simplificado     AS novo_valor,
  COUNT(*)                 AS qtd
FROM colaboradores c
LEFT JOIN param_empresa pe
  ON c.empresa_registro LIKE pe.codigo || ' -%'
WHERE c.empresa_registro IS NOT NULL AND c.empresa_registro != ''
GROUP BY c.empresa_registro, pe.nome_simplificado
ORDER BY qtd DESC;

-- ──────────────────────────────────────────────────────────────
-- PASSO 2: Execute o UPDATE após confirmar o resultado acima
-- ──────────────────────────────────────────────────────────────
UPDATE colaboradores
SET empresa_registro = pe.nome_simplificado
FROM param_empresa pe
WHERE colaboradores.empresa_registro LIKE pe.codigo || ' -%'
  AND pe.nome_simplificado IS NOT NULL
  AND pe.nome_simplificado != '';
