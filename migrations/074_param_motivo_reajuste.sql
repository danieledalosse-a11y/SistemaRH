CREATE TABLE IF NOT EXISTS param_motivo_reajuste (
  id         SERIAL PRIMARY KEY,
  codigo     TEXT NOT NULL,
  descricao  TEXT NOT NULL,
  ordem      INTEGER DEFAULT 0,
  ativo      BOOLEAN DEFAULT true,
  criado_por TEXT,
  CONSTRAINT uq_pmr_codigo UNIQUE (codigo)
);

INSERT INTO param_motivo_reajuste (codigo, descricao, ordem) VALUES
  ('0.1', 'Mérito',                  1),
  ('0.2', 'Promoção',                2),
  ('0.3', 'Dissídio coletivo',       3),
  ('0.4', 'Equiparação salarial',    4),
  ('0.5', 'Acordo coletivo',         5),
  ('0.6', 'Enquadramento',           6)
ON CONFLICT (codigo) DO NOTHING;
