-- ============================================================
-- MIGRAÇÃO 019: Tabela de graus de formação (escolaridade)
-- ============================================================
CREATE TABLE IF NOT EXISTS param_escolaridade (
  id         BIGSERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL UNIQUE,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO param_escolaridade (codigo, descricao, ordem) VALUES
  ('FUND_INC',  'Fundamental incompleto',  1),
  ('FUND_COMP', 'Fundamental completo',    2),
  ('MED_INC',   'Médio incompleto',        3),
  ('MED_COMP',  'Médio completo',          4),
  ('SUP_INC',   'Superior incompleto',     5),
  ('SUP_COMP',  'Superior completo',       6),
  ('POS_GRAD',  'Pós-graduação',           7),
  ('MESTRADO',  'Mestrado',                8),
  ('DOUTORADO', 'Doutorado',               9)
ON CONFLICT (codigo) DO NOTHING;
