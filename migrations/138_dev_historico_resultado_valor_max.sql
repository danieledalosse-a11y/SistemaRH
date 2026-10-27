-- 138_dev_historico_resultado_valor_max.sql
--
-- Adiciona o valor máximo possível do ciclo em dev_historico.
-- Usado pela Trajetória Profissional para calcular o percentual de atingimento
-- e colorir o resultado (verde ≥100%, âmbar ≥70%, vermelho <70%)
-- sem depender de queries adicionais na renderização.
--
-- Nullable — sem impacto em registros de outros módulos.

ALTER TABLE dev_historico
  ADD COLUMN IF NOT EXISTS resultado_valor_max NUMERIC;
