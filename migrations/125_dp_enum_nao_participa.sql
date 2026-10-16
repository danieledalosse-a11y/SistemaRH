-- 125_dp_enum_nao_participa.sql
-- Adiciona os valores que faltam ao enum dp_evento_historico.
-- A migration 124 usa esses valores nas RPCs, mas esqueceu de adicioná-los ao enum.

ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'nao_participa_marcado';
ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'nao_participa_revertido';
