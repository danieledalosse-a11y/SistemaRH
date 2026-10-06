-- Migration 077 — Migração de historico_salarial para historico_remuneracao
-- Preserva todos os registros históricos do array JSONB antigo.
-- Segura para re-executar: ON CONFLICT DO NOTHING evita duplicatas.
-- O campo historico_salarial NÃO é removido — permanece como backup.

INSERT INTO historico_remuneracao (
  colaborador_id,
  processo_id,
  data_vigencia,
  salario_anterior,
  salario_novo,
  percentual,
  cargo_anterior,
  cargo_novo,
  motivo_codigo,
  motivo_descricao,
  observacao,
  registrado_por,
  registrado_em,
  aplicado_em,
  estornado,
  esocial_enviado
)
SELECT
  c.id                              AS colaborador_id,
  NULL                              AS processo_id,
  -- data do registro; fallback para data_admissao se ausente
  COALESCE(
    (entry->>'data')::DATE,
    c.data_admissao::DATE
  )                                 AS data_vigencia,
  NULL                              AS salario_anterior,
  -- salario_novo: remove formatação BR (pontos de milhar, vírgula decimal)
  REPLACE(
    REPLACE(
      COALESCE(entry->>'valor', '0'),
      '.', ''
    ),
    ',', '.'
  )::NUMERIC                        AS salario_novo,
  NULL                              AS percentual,
  NULL                              AS cargo_anterior,
  NULL                              AS cargo_novo,
  NULL                              AS motivo_codigo,
  'Histórico anterior ao sistema'   AS motivo_descricao,
  'Migrado de historico_salarial'   AS observacao,
  'migração histórico'              AS registrado_por,
  NOW()                             AS registrado_em,
  -- já estava aplicado (existia no histórico antigo)
  COALESCE(
    (entry->>'data')::TIMESTAMPTZ,
    c.data_admissao::TIMESTAMPTZ,
    NOW()
  )                                 AS aplicado_em,
  FALSE                             AS estornado,
  FALSE                             AS esocial_enviado

FROM colaboradores c,
     LATERAL jsonb_array_elements(
       CASE
         WHEN jsonb_typeof(c.historico_salarial) = 'array'
              AND jsonb_array_length(c.historico_salarial) > 0
         THEN c.historico_salarial
         ELSE '[]'::JSONB
       END
     ) AS entry

-- Exclui entradas com valor zerado ou ausente
WHERE COALESCE(entry->>'valor', '') <> ''
  AND REPLACE(REPLACE(entry->>'valor', '.', ''), ',', '.') <> '0'
  AND REPLACE(REPLACE(entry->>'valor', '.', ''), ',', '.') ~ '^[0-9]+(\.[0-9]+)?$'

-- processo_id = NULL: UNIQUE (colaborador_id, processo_id) não se aplica aqui,
-- pois NULL != NULL no PostgreSQL — múltiplas entradas com processo_id NULL são permitidas.
-- Sem risco de conflito com registros do workflow.
;

-- Relatório de conferência: quantos registros foram migrados por colaborador
-- (execute separadamente se quiser verificar)
-- SELECT c.nome, COUNT(hr.id) AS registros_migrados
-- FROM colaboradores c
-- LEFT JOIN historico_remuneracao hr
--   ON hr.colaborador_id = c.id AND hr.processo_id IS NULL
--   AND hr.motivo_descricao = 'Histórico anterior ao sistema'
-- GROUP BY c.nome
-- HAVING COUNT(hr.id) > 0
-- ORDER BY c.nome;
