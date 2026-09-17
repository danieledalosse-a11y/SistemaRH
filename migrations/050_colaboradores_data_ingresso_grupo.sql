-- Data de ingresso no grupo Revest
-- Usada quando o colaborador trocou de CNPJ ao longo da carreira.
-- Quando preenchida, substitui data_admissao no cálculo de Tempo de Casa.
-- Nunca deve ser sobrescrita por transferências de CNPJ — apenas pelo RH manualmente.
ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS data_ingresso_grupo DATE;
