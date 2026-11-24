-- Torna matrícula opcional no banco de dados
-- Necessário para suportar colaboradores sem matrícula (Promotoras, Pró-labore)
-- A obrigatoriedade passa a ser controlada no frontend por tipo_vinculo
ALTER TABLE public.colaboradores
  ALTER COLUMN matricula DROP NOT NULL;
