-- ============================================================
-- MIGRAÇÃO 011: Ajusta param_tipo_contrato — remove CLT Prazo
--               Determinado, mantém lista final padronizada
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

DELETE FROM param_tipo_contrato;

INSERT INTO param_tipo_contrato (ordem, codigo, descricao, ativo) VALUES
  (1, 'CLT_EXP',   'CLT – Experiência (45+45 dias)',   TRUE),
  (2, 'CLT_INDET', 'CLT – Prazo Indeterminado',        TRUE),
  (3, 'APRENDIZ',  'Jovem Aprendiz',                   TRUE),
  (4, 'ESTAGIO',   'Estágio',                          TRUE),
  (5, 'PJ',        'PJ – Prestação de Serviços',       TRUE),
  (6, 'TEMP',      'Temporário (Lei 6.019/74)',         TRUE),
  (7, 'AUTONOMO',  'Autônomo',                         TRUE);
