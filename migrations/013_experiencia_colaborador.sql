-- ============================================================
-- MIGRAÇÃO 013: Reestrutura tipo de contrato e experiência
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. Simplifica param_tipo_contrato (CLT sem subdivisão)
DELETE FROM param_tipo_contrato;

INSERT INTO param_tipo_contrato (ordem, codigo, descricao, ativo) VALUES
  (1, 'CLT',      'CLT',                         TRUE),
  (2, 'APRENDIZ', 'Jovem Aprendiz',               TRUE),
  (3, 'ESTAGIO',  'Estágio',                      TRUE),
  (4, 'PJ',       'PJ – Prestação de Serviços',   TRUE),
  (5, 'TEMP',     'Temporário',                   TRUE),
  (6, 'AUTONOMO', 'Autônomo',                     TRUE);

-- 2. Adiciona campos de experiência no colaborador
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS em_experiencia       BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS data_fim_experiencia DATE,
  ADD COLUMN IF NOT EXISTS prorrogacao_exp      BOOLEAN DEFAULT FALSE;

-- 3. Remove coluna dias_experiencia (substituída pela lógica acima)
ALTER TABLE colaboradores
  DROP COLUMN IF EXISTS dias_experiencia;
