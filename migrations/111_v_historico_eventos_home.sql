-- Migration 111 — v_historico_eventos_home
-- View de apresentação para a Home do Gestor.
-- Nunca expõe salario_anterior, salario_novo nem o campo dados completo.
-- Fonte oficial e completa permanece inalterada em historico_eventos.

CREATE OR REPLACE VIEW v_historico_eventos_home AS
SELECT
  id,
  colaborador_id,
  tipo,
  titulo,
  data_evento,

  -- resumo_home: para eventos salariais, substitui valores nominais por
  -- percentual + mês/ano + situação do cargo.
  -- Para todos os demais tipos, repassa o resumo original (auditado: sem salário).
  CASE
    WHEN tipo IN ('reajuste_salarial', 'promocao') THEN
      CONCAT_WS(' · ',
        -- Percentual: "+6%" (inteiro) ou "+6,5%" (decimal)
        CASE
          WHEN (dados->>'percentual') IS NOT NULL
            AND (dados->>'percentual')::NUMERIC <> 0
          THEN '+' || CASE
            WHEN (dados->>'percentual')::NUMERIC % 1 = 0
            THEN ((dados->>'percentual')::NUMERIC)::INTEGER::TEXT
            ELSE REPLACE(TO_CHAR((dados->>'percentual')::NUMERIC, 'FM990D99'), '.', ',')
          END || '%'
        END,
        -- Mês/ano da vigência em português abreviado (ex: "ago/2026")
        CASE EXTRACT(MONTH FROM data_evento)
          WHEN 1  THEN 'jan'  WHEN 2  THEN 'fev'  WHEN 3  THEN 'mar'
          WHEN 4  THEN 'abr'  WHEN 5  THEN 'mai'  WHEN 6  THEN 'jun'
          WHEN 7  THEN 'jul'  WHEN 8  THEN 'ago'  WHEN 9  THEN 'set'
          WHEN 10 THEN 'out'  WHEN 11 THEN 'nov'  WHEN 12 THEN 'dez'
        END || '/' || TO_CHAR(data_evento, 'YYYY'),
        -- Cargo: informa novo cargo ou confirma que foi mantido
        CASE
          WHEN NULLIF(TRIM(dados->>'cargo_novo'), '') IS NOT NULL
          THEN 'novo cargo: ' || (dados->>'cargo_novo')
          ELSE 'cargo mantido'
        END
      )
    ELSE
      resumo
  END AS resumo_home

FROM historico_eventos;

-- Comentário descritivo
COMMENT ON VIEW v_historico_eventos_home IS
  'Camada de apresentação para a Home do Gestor. '
  'Nunca expõe salario_anterior, salario_novo nem o JSONB dados completo. '
  'Fonte oficial: historico_eventos (inalterada).';
