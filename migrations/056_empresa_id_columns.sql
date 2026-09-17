-- Migration 056 — Etapa 1: colunas de FK para param_empresa
-- Nullable, sem constraint — rollback = DROP COLUMN
-- empresa_registro_id e empresa_atuacao_id ficam independentes (regra de negócio preservada)

ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS empresa_registro_id INTEGER,
  ADD COLUMN IF NOT EXISTS empresa_atuacao_id  INTEGER;

-- Validação estrutural imediata (deve retornar 0 em ambas as colunas _id — ainda não migrado)
SELECT
  COUNT(*)                   AS total_colaboradores,
  COUNT(empresa_registro_id) AS com_reg_id,
  COUNT(empresa_atuacao_id)  AS com_atu_id
FROM colaboradores;
