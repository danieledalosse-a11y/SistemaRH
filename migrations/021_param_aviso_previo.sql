-- ============================================================
-- MIGRAÇÃO 021: Tabela de tipos de aviso prévio
-- ============================================================
CREATE TABLE IF NOT EXISTS param_aviso_previo (
  id         BIGSERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL UNIQUE,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO param_aviso_previo (codigo, descricao, ordem) VALUES
  ('TRABALHADO',  'Trabalhado',  1),
  ('INDENIZADO',  'Indenizado',  2),
  ('DISPENSADO',  'Dispensado',  3)
ON CONFLICT (codigo) DO NOTHING;
