-- Migration 078 — tipos_evento
-- Tabela de referência parametrizada de tipos de eventos da linha do tempo.
-- Cada módulo registra aqui o tipo antes de gravar eventos em historico_eventos.

CREATE TABLE tipos_evento (
  codigo           TEXT        PRIMARY KEY,
  categoria        TEXT        NOT NULL
                               CHECK (categoria IN ('financeiro','carreira','beneficio','ausencia','cadastro')),
  label            TEXT        NOT NULL,
  icone_chave      TEXT,
  cor_hex          TEXT,
  dados_schema     JSONB,
  resumo_template  TEXT,
  detalhe_campos   JSONB,
  ativo            BOOLEAN     NOT NULL DEFAULT TRUE,
  criado_em        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'reajuste_salarial',
  'financeiro',
  'Reajuste Salarial',
  'trending-up',
  '#1849A9',
  '[
    {"campo":"salario_anterior","tipo":"currency","label":"Salário anterior","obrigatorio":false},
    {"campo":"salario_novo",    "tipo":"currency","label":"Novo salário",     "obrigatorio":true},
    {"campo":"percentual",      "tipo":"percent", "label":"Variação",         "obrigatorio":false},
    {"campo":"motivo_codigo",   "tipo":"text",    "label":"Código do motivo", "obrigatorio":false},
    {"campo":"motivo_descricao","tipo":"text",    "label":"Motivo",           "obrigatorio":true}
  ]',
  '{salario_anterior} → {salario_novo} (+{percentual}%)',
  '[
    {"campo":"motivo_descricao","label":"Motivo"},
    {"campo":"salario_anterior","label":"Salário anterior"},
    {"campo":"salario_novo",    "label":"Novo salário"},
    {"campo":"percentual",      "label":"Variação"}
  ]',
  TRUE,
  NOW()
);

INSERT INTO tipos_evento (
  codigo, categoria, label, icone_chave, cor_hex,
  dados_schema, resumo_template, detalhe_campos, ativo, criado_em
) VALUES (
  'promocao',
  'carreira',
  'Promoção',
  'chevrons-up',
  '#12B76A',
  '[
    {"campo":"cargo_anterior",  "tipo":"text",    "label":"Cargo anterior",   "obrigatorio":false},
    {"campo":"cargo_novo",      "tipo":"text",    "label":"Novo cargo",       "obrigatorio":true},
    {"campo":"salario_anterior","tipo":"currency","label":"Salário anterior",  "obrigatorio":false},
    {"campo":"salario_novo",    "tipo":"currency","label":"Novo salário",      "obrigatorio":false},
    {"campo":"percentual",      "tipo":"percent", "label":"Variação salarial", "obrigatorio":false},
    {"campo":"motivo_descricao","tipo":"text",    "label":"Motivo",            "obrigatorio":false}
  ]',
  '{cargo_anterior} → {cargo_novo}',
  '[
    {"campo":"cargo_anterior",  "label":"Cargo anterior"},
    {"campo":"cargo_novo",      "label":"Novo cargo"},
    {"campo":"salario_anterior","label":"Salário anterior"},
    {"campo":"salario_novo",    "label":"Novo salário"},
    {"campo":"percentual",      "label":"Variação salarial"}
  ]',
  TRUE,
  NOW()
);
