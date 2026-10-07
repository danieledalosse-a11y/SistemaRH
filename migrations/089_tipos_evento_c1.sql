-- Migration 089 — tipos_evento: prorrogacao_experiencia, efetivacao, transferencia
-- Parte C-1 da arquitetura de historico_eventos unificado.
-- Execute APÓS a migration 088.

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'prorrogacao_experiencia',
  'cadastro',
  'Prorrogação de Experiência',
  'clock',
  '#B54708',
  '[
    {"campo":"fim_45_dias","tipo":"date","label":"Prorrogado até","obrigatorio":true}
  ]',
  'Prorrogado até {fim_45_dias}',
  '[
    {"campo":"fim_45_dias","label":"Prorrogado até"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'efetivacao',
  'carreira',
  'Efetivação',
  'user-check',
  '#027A48',
  '[
    {"campo":"fim_experiencia","tipo":"date","label":"Data de efetivação","obrigatorio":true}
  ]',
  'Efetivado após período de experiência',
  '[
    {"campo":"fim_experiencia","label":"Data de efetivação"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'transferencia',
  'carreira',
  'Transferência',
  'building',
  '#1570EF',
  '[
    {"campo":"empresa_origem",      "tipo":"text","label":"Empresa de origem", "obrigatorio":true},
    {"campo":"empresa_destino",     "tipo":"text","label":"Empresa de destino","obrigatorio":true},
    {"campo":"tipo_transferencia",  "tipo":"text","label":"Tipo",              "obrigatorio":false}
  ]',
  '{empresa_origem} → {empresa_destino}',
  '[
    {"campo":"empresa_origem",     "label":"Empresa de origem"},
    {"campo":"empresa_destino",    "label":"Empresa de destino"},
    {"campo":"tipo_transferencia", "label":"Tipo"}
  ]',
  TRUE,
  NOW()
);
