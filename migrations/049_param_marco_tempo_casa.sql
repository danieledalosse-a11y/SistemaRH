-- Marcos de Tempo de Casa
-- Configura os anos de empresa que o RH quer destacar no relatório Tempo de Casa
CREATE TABLE IF NOT EXISTS public.param_marco_tempo_casa (
  id         SERIAL  PRIMARY KEY,
  anos       INTEGER NOT NULL UNIQUE,
  ativo      BOOLEAN NOT NULL DEFAULT TRUE,
  criado_por TEXT
);

INSERT INTO public.param_marco_tempo_casa (anos) VALUES (1),(5),(10),(15),(20)
ON CONFLICT (anos) DO NOTHING;

ALTER TABLE public.param_marco_tempo_casa ENABLE ROW LEVEL SECURITY;

CREATE POLICY "anon_all" ON public.param_marco_tempo_casa
  FOR ALL TO anon, authenticated USING (true) WITH CHECK (true);
