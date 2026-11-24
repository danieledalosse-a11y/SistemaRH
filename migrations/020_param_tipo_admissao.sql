-- ============================================================
-- MIGRAÇÃO 020: Tabela de tipos de admissão
-- ============================================================
CREATE TABLE IF NOT EXISTS param_tipo_admissao (
  id         BIGSERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL UNIQUE,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO param_tipo_admissao (codigo, descricao, ordem) VALUES
  ('EMPREGO',       'Emprego (1ª vez)',  1),
  ('REEMPREGO',     'Reemprego',         2),
  ('TRANSFERENCIA', 'Transferência',     3),
  ('REINTEGRACAO',  'Reintegração',      4)
ON CONFLICT (codigo) DO NOTHING;
