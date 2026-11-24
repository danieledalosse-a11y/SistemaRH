-- Tipo de vínculo do colaborador com a empresa
-- Substitui o uso isolado do booleano pro_labore para controle de inclusão em KPIs e relatórios.
-- Valores: 'clt' (padrão), 'promotora' (terceirizada), 'pro_labore' (sócio-gerente)
ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS tipo_vinculo TEXT NOT NULL DEFAULT 'clt'
    CHECK (tipo_vinculo IN ('clt', 'promotora', 'pro_labore'));

-- Migrar registros existentes de pro_labore = true
UPDATE public.colaboradores
  SET tipo_vinculo = 'pro_labore'
  WHERE pro_labore = true;

-- Empresa terceirizada — preenchida apenas para promotoras
-- Separada de empresa_atuacao (unidade Revest onde está alocada)
ALTER TABLE public.colaboradores
  ADD COLUMN IF NOT EXISTS empresa_terceirizada TEXT;
