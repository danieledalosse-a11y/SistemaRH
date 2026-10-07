-- Migration 094 — tipos_evento: bonus_indicacao, vt_alteracao, devolucao_uniforme
-- Parte C-2 da arquitetura de historico_eventos unificado.
-- Execute APÓS a migration 093.

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'bonus_indicacao',
  'financeiro',
  'Bônus de Indicação',
  'trending-up',
  '#6938EF',
  '[
    {"campo":"indicado_nome","tipo":"text","label":"Colaborador indicado","obrigatorio":true},
    {"campo":"valor_bonus",  "tipo":"number","label":"Valor do bônus",    "obrigatorio":true},
    {"campo":"mes_folha",    "tipo":"text","label":"Mês de competência",  "obrigatorio":false}
  ]',
  'Bônus por indicação de {indicado_nome}',
  '[
    {"campo":"indicado_nome","label":"Colaborador indicado"},
    {"campo":"valor_bonus",  "label":"Valor do bônus"},
    {"campo":"mes_folha",    "label":"Mês de competência"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'vt_alteracao',
  'beneficio',
  'Vale-Transporte',
  'bus',
  '#026AA2',
  '[
    {"campo":"operacao", "tipo":"text","label":"Operação",    "obrigatorio":true},
    {"campo":"vt_linha", "tipo":"text","label":"Linha",       "obrigatorio":false},
    {"campo":"vt_cartao","tipo":"text","label":"Cartão",      "obrigatorio":false},
    {"campo":"vt_passes","tipo":"number","label":"Passes/dia","obrigatorio":false},
    {"campo":"vt_viacao","tipo":"text","label":"Viação",      "obrigatorio":false}
  ]',
  '{operacao}: {vt_linha}',
  '[
    {"campo":"operacao", "label":"Operação"},
    {"campo":"vt_linha", "label":"Linha"},
    {"campo":"vt_cartao","label":"Cartão"},
    {"campo":"vt_passes","label":"Passes/dia"},
    {"campo":"vt_viacao","label":"Viação"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'devolucao_uniforme',
  'cadastro',
  'Devolução de Uniforme',
  'check-square',
  '#667085',
  '[
    {"campo":"qtd_itens","tipo":"number","label":"Itens devolvidos","obrigatorio":true}
  ]',
  '{qtd_itens} item(ns) devolvido(s)',
  '[
    {"campo":"qtd_itens","label":"Itens devolvidos"}
  ]',
  TRUE,
  NOW()
);
