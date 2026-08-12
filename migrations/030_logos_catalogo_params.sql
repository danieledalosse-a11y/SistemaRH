-- 030: logos bordadas como parâmetro + logo_id em entradas

CREATE TABLE IF NOT EXISTS unif_logos (
  id        bigserial primary key,
  nome      text not null,
  bordada   boolean not null default true,
  ativo     boolean not null default true,
  ordem     int not null default 0,
  criado_em timestamptz not null default now()
);

INSERT INTO unif_logos (nome, bordada, ordem) VALUES
  ('Sem logo',                false, 0),
  ('Logo Grupo Revest',       true,  1),
  ('Logo Revest Acabamentos', true,  2)
ON CONFLICT DO NOTHING;

ALTER TABLE unif_entradas
  ADD COLUMN IF NOT EXISTS logo_id bigint references unif_logos(id);

ALTER TABLE unif_logos ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies WHERE tablename='unif_logos' AND policyname='acesso autenticado'
  ) THEN
    EXECUTE 'CREATE POLICY "acesso autenticado" ON unif_logos FOR ALL USING (auth.role() = ''authenticated'')';
  END IF;
END $$;
