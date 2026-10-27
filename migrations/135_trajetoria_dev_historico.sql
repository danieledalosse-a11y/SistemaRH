-- 135_trajetoria_dev_historico.sql
--
-- Etapa 1 — Trajetória Profissional: adiciona dois campos nullable em
-- dev_historico para vincular registros D&P a ciclos e avaliações.
--
-- Sem impacto em registros existentes (Admissão, Férias, histórico manual):
-- colunas são nullable, sem default, sem constraint NOT NULL.
--
-- RLS: dev_historico não tem RLS habilitado — mantido assim.
-- Habilitar RLS requereria mapeamento completo de todos os módulos que
-- gravam na tabela (fora do escopo desta etapa).

ALTER TABLE dev_historico
  ADD COLUMN IF NOT EXISTS ciclo_id     uuid REFERENCES dp_ciclos(id),
  ADD COLUMN IF NOT EXISTS avaliacao_id uuid REFERENCES dp_avaliacoes(id);
