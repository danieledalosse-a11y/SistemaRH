-- 136_dev_pdi_created_at.sql
--
-- Adiciona created_at em dev_pdi para rastrear quando cada registro foi criado.
--
-- dev_pdi.ciclo_id já existe (referenciado pelo código desde o início).
-- Esta migration adiciona apenas o campo de timestamp de criação.
--
-- Idempotente: IF NOT EXISTS garante que rodar duas vezes é seguro.

ALTER TABLE dev_pdi
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT now();
