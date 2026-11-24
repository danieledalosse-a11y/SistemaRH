-- ============================================================
-- MIGRAÇÃO 018: Tabela de instituições parceiras Jovem Aprendiz
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

CREATE TABLE IF NOT EXISTS param_instituicao_aprendiz (
  id         BIGSERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL UNIQUE,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Registros iniciais
INSERT INTO param_instituicao_aprendiz (codigo, descricao, ordem) VALUES
  ('CIEE',              'CIEE',                    1),
  ('LINS_VASCONCELOS',  'Lins de Vasconcelos',     2),
  ('SENAI',             'SENAI',                   3)
ON CONFLICT (codigo) DO NOTHING;
