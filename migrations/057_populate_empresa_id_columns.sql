-- Migration 057 — Etapa 1: popular empresa_registro_id e empresa_atuacao_id
-- Mapping via nome_simplificado (correspondência exata, sem transformação de case)
-- empresa_atuacao com '' (3 registros) mantidos sem _id — não inferir

-- 1. empresa_registro_id
UPDATE public.colaboradores c
SET empresa_registro_id = e.id
FROM public.param_empresa e
WHERE c.empresa_registro = e.nome_simplificado
  AND c.empresa_registro IS NOT NULL
  AND c.empresa_registro != '';

-- 2. empresa_atuacao_id
UPDATE public.colaboradores c
SET empresa_atuacao_id = e.id
FROM public.param_empresa e
WHERE c.empresa_atuacao = e.nome_simplificado
  AND c.empresa_atuacao IS NOT NULL
  AND c.empresa_atuacao != '';

-- Validação de dados (deve retornar pendentes_reg=0, pendentes_atu=0, em_branco_atu=3)
SELECT
  COUNT(*) FILTER (WHERE empresa_registro != '' AND empresa_registro IS NOT NULL AND empresa_registro_id IS NULL)   AS pendentes_reg,
  COUNT(*) FILTER (WHERE empresa_atuacao  != '' AND empresa_atuacao  IS NOT NULL AND empresa_atuacao_id  IS NULL)   AS pendentes_atu,
  COUNT(*) FILTER (WHERE empresa_atuacao  = ''  OR  empresa_atuacao  IS NULL)                                       AS em_branco_atu,
  COUNT(*) FILTER (WHERE empresa_registro_id IS NOT NULL)                                                           AS reg_mapeados,
  COUNT(*) FILTER (WHERE empresa_atuacao_id  IS NOT NULL)                                                           AS atu_mapeados
FROM colaboradores;
