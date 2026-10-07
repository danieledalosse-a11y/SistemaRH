-- Migration 105 — alteracao_setor + ajustes nos eventos históricos da Mig 104
--
-- 105-A: param_tipo_transferencia adicionado ao CATS do módulo Parâmetros Gerais
--        (frontend apenas — modulos/parametros/index.html, commit 81e56c6)
--
-- 105-B: Novo tipo de evento 'alteracao_setor' em tipos_evento
--        Executado via REST API (Python). Documentado abaixo para controle de versão.
--
-- 105-C: Correção dos eventos históricos da Mig 104 (historico_eventos)
--        Executado via REST API (Python). Estado final documentado abaixo.

-- 105-B: INSERT tipos_evento[alteracao_setor]
-- (executado via REST API; este bloco é apenas documentação)
/*
INSERT INTO tipos_evento (codigo, categoria, label, icone_chave, dados_schema, resumo_template)
VALUES (
  'alteracao_setor',
  'carreira',
  'Mudança de Setor',
  'briefcase',
  '[
    {"tipo":"text","campo":"setor_anterior",       "label":"Setor anterior",         "obrigatorio":true},
    {"tipo":"text","campo":"setor_anterior_label",  "label":"Setor anterior (label)",  "obrigatorio":false},
    {"tipo":"text","campo":"setor_novo",            "label":"Setor novo",              "obrigatorio":true},
    {"tipo":"text","campo":"setor_novo_label",       "label":"Setor novo (label)",       "obrigatorio":false}
  ]'::JSONB,
  '{setor_anterior_label} → {setor_novo_label}'
);
*/

-- 105-C: Ajustes em historico_eventos (executado via REST API)
--
-- Removidos:
--   id=90  Sabrina (1778)     transferencia  — normalização de nome de setor, não evento real
--   id=92  Maria Luiza (1629) transferencia  — redundante com promoção id=93
--   id=94  Francisco (1688)   transferencia  — redundante com promoção id=95
--
-- Substituído:
--   id=91  Ana Claudia (1752) transferencia → alteracao_setor
--          dados: setor_anterior='2584 - SDI Adm' / setor_anterior_label='SDI Adm'
--                 setor_novo='Matriz Adm'          / setor_novo_label='Matriz Adm'
--          data_evento: 2025-07-01
--
-- Mantidos sem alteração:
--   id=89  Marcilene (1787)   transferencia  CD → Red        2025-05-01
--   id=93  Maria Luiza (1629) promocao       Atendente → Assistente de E-commerce  2023-11-01
--   id=95  Francisco (1688)   promocao       Ajudante → Operador de Logística      2025-08-01
--
-- Criado:
--   id=96  Gisele (1872)      promocao       Assistente Administrativo → Assistente de Compras Jr.  2022-10-01
--          colaborador_id=1872 (vínculo inativo 2019-10-01→2022-09-30, mat=345)
--          origem: 'manual'
