-- 114_dp_versao_criterios_range_monetario.sql
-- Fase 3: range configurável para critérios numéricos (nota_min, nota_max)
-- Fase 4: valor monetário para critérios Sim/Não (valor_se_sim, valor_se_nao)
--
-- Todas as colunas são nullable:
--   - Critérios existentes ficam com NULL → comportamento atual preservado
--   - Resultados históricos já calculados em dp_resultados não são afetados
--   - setCritField() faz PATCH genérico → compatível sem alteração adicional

ALTER TABLE dp_versao_criterios
  ADD COLUMN IF NOT EXISTS nota_min      NUMERIC,
  ADD COLUMN IF NOT EXISTS nota_max      NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_sim  NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_nao  NUMERIC DEFAULT 0;

COMMENT ON COLUMN dp_versao_criterios.nota_min     IS 'Valor mínimo esperado para critérios numéricos (orientação e validação)';
COMMENT ON COLUMN dp_versao_criterios.nota_max     IS 'Valor máximo esperado para critérios numéricos (orientação e validação)';
COMMENT ON COLUMN dp_versao_criterios.valor_se_sim IS 'Valor monetário atribuído quando resposta binária = sim';
COMMENT ON COLUMN dp_versao_criterios.valor_se_nao IS 'Valor monetário atribuído quando resposta binária = não (padrão: 0)';
