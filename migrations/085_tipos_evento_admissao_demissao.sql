-- Migration 085 — tipos_evento: admissao e demissao
-- Registra os tipos de evento para os processos de admissão e desligamento.
-- icone_chave deve corresponder ao dicionário ICONS em ficha-render.js.

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'admissao',
  'cadastro',
  'Admissão',
  'user-check',
  '#027A48',
  '[
    {"campo":"cargo",   "tipo":"text","label":"Cargo de admissão","obrigatorio":true},
    {"campo":"empresa", "tipo":"text","label":"Empresa",          "obrigatorio":false}
  ]',
  'Admitido como {cargo}',
  '[
    {"campo":"cargo",   "label":"Cargo"},
    {"campo":"empresa", "label":"Empresa"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'demissao',
  'cadastro',
  'Desligamento',
  'x-circle',
  '#B42318',
  '[
    {"campo":"motivo","tipo":"text","label":"Motivo","obrigatorio":false}
  ]',
  '{motivo}',
  '[
    {"campo":"motivo","label":"Motivo"}
  ]',
  TRUE,
  NOW()
);
