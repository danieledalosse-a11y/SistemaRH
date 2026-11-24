-- ============================================================
-- MIGRAÇÃO 022: Tabela de graus de parentesco (dependentes)
-- ============================================================
CREATE TABLE IF NOT EXISTS param_parentesco (
  id         BIGSERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL UNIQUE,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO param_parentesco (codigo, descricao, ordem) VALUES
  ('FILHO',        'Filho(a)',        1),
  ('ENTEADO',      'Enteado(a)',      2),
  ('CONJUGE',      'Cônjuge',         3),
  ('COMPANHEIRO',  'Companheiro(a)',  4),
  ('PAI',          'Pai',             5),
  ('MAE',          'Mãe',             6),
  ('OUTRO',        'Outro',           7)
ON CONFLICT (codigo) DO NOTHING;
