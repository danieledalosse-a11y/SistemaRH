-- ============================================================
-- MIGRAÇÃO 008: Normaliza empresa_atuacao em colaboradores
-- Converte o formato antigo "148 - Matriz Adm" para o
-- nome_simplificado de param_empresa (ex: "MATRIZ").
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- PASSO 1: Diagnóstico — veja os valores atuais antes de alterar
SELECT
  c.empresa_atuacao        AS valor_atual,
  pe.nome_simplificado     AS novo_valor,
  COUNT(*)                 AS qtd_colaboradores
FROM colaboradores c
LEFT JOIN param_empresa pe
  ON c.empresa_atuacao LIKE pe.codigo || ' -%'
WHERE c.empresa_atuacao IS NOT NULL AND c.empresa_atuacao != ''
GROUP BY c.empresa_atuacao, pe.nome_simplificado
ORDER BY qtd_colaboradores DESC;

-- ──────────────────────────────────────────────────────────────
-- PASSO 2: Confirme o resultado acima e então execute o UPDATE
-- ──────────────────────────────────────────────────────────────
UPDATE colaboradores
SET empresa_atuacao = pe.nome_simplificado
FROM param_empresa pe
WHERE colaboradores.empresa_atuacao LIKE pe.codigo || ' -%'
  AND pe.nome_simplificado IS NOT NULL
  AND pe.nome_simplificado != '';
