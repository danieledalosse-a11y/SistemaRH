CREATE TABLE IF NOT EXISTS public.param_tipo_vinculo (
  id SERIAL PRIMARY KEY,
  codigo TEXT NOT NULL UNIQUE,
  descricao TEXT NOT NULL,
  ativo BOOLEAN NOT NULL DEFAULT true,
  ordem INTEGER NOT NULL DEFAULT 0,
  criado_em TIMESTAMPTZ DEFAULT now()
);

INSERT INTO public.param_tipo_vinculo (codigo, descricao, ativo, ordem) VALUES
  ('clt',        'CLT',        true, 1),
  ('promotora',  'Promotora',  true, 2),
  ('pro_labore', 'Pró-labore', true, 3)
ON CONFLICT (codigo) DO NOTHING;
