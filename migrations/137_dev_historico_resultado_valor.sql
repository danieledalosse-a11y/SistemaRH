-- 137_dev_historico_resultado_valor.sql
--
-- Adiciona campo numérico para armazenar o resultado financeiro de avaliações
-- de desempenho diretamente em dev_historico.
--
-- Usado pela Trajetória Profissional para exibir o gráfico de evolução de
-- resultados por ciclo sem depender de texto da coluna descricao.
--
-- Nullable — sem impacto em registros existentes de outros módulos
-- (Admissão, Férias, feedbacks manuais).

ALTER TABLE dev_historico
  ADD COLUMN IF NOT EXISTS resultado_valor NUMERIC;
