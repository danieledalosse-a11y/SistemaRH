-- ============================================================
-- MIGRAÇÃO 012: Simplifica param_tipo_contrato
-- Tipo de contrato = modalidade jurídica apenas
-- Duração da experiência é campo individual no colaborador
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

DELETE FROM param_tipo_contrato;

INSERT INTO param_tipo_contrato (ordem, codigo, descricao, ativo) VALUES
  (1, 'CLT_EXP',   'CLT – Experiência',           TRUE),
  (2, 'CLT_INDET', 'CLT – Prazo Indeterminado',   TRUE),
  (3, 'APRENDIZ',  'Jovem Aprendiz',               TRUE),
  (4, 'ESTAGIO',   'Estágio',                      TRUE),
  (5, 'PJ',        'PJ – Prestação de Serviços',   TRUE),
  (6, 'TEMP',      'Temporário',                   TRUE),
  (7, 'AUTONOMO',  'Autônomo',                     TRUE);

-- Campo para duração individual da experiência (no colaborador)
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS dias_experiencia INTEGER;
