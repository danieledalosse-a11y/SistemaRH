-- Adiciona tipo_ficha à tabela param_tipo_vinculo
-- 'completa' = exibe todos os campos (padrão CLT)
-- 'resumida'  = oculta blocos específicos do CLT (Promotora, Pró-labore, etc.)
ALTER TABLE public.param_tipo_vinculo
  ADD COLUMN IF NOT EXISTS tipo_ficha TEXT NOT NULL DEFAULT 'completa'
    CHECK (tipo_ficha IN ('completa', 'resumida'));

UPDATE public.param_tipo_vinculo SET tipo_ficha = 'resumida'
  WHERE codigo IN ('promotora', 'pro_labore');
