-- ============================================================
-- MIGRAÇÃO 010: Limpa e padroniza param_tipo_contrato
-- Padrão eSocial / mercado BR
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- Remove todos os registros atuais
DELETE FROM param_tipo_contrato;

-- Insere lista limpa e padronizada
INSERT INTO param_tipo_contrato (ordem, codigo, descricao, ativo) VALUES
  (1,  'CLT_INDET',  'CLT – Prazo Indeterminado',      TRUE),
  (2,  'CLT_DET',    'CLT – Prazo Determinado',         TRUE),
  (3,  'EXPERIENCIA','CLT – Contrato de Experiência',   TRUE),
  (4,  'APRENDIZ',   'Jovem Aprendiz',                  TRUE),
  (5,  'ESTAGIO',    'Estágio',                         TRUE),
  (6,  'PJ',         'PJ – Prestação de Serviços',      TRUE),
  (7,  'TEMP',       'Temporário (Lei 6.019/74)',        TRUE),
  (8,  'AUTONOMO',   'Autônomo',                        TRUE);
