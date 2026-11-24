CREATE TABLE IF NOT EXISTS admissao_fichas (
  id BIGSERIAL PRIMARY KEY,
  token UUID REFERENCES admissao_convites(token) ON DELETE CASCADE,
  -- Dados pessoais
  nome TEXT, nascimento DATE, sexo TEXT, nacionalidade TEXT, naturalidade TEXT,
  rg TEXT, rg_orgao TEXT, rg_data DATE, cpf TEXT,
  titulo_eleitor TEXT, titulo_zona TEXT, titulo_secao TEXT,
  ctps_numero TEXT, ctps_serie TEXT, pis TEXT,
  cnh_numero TEXT, cnh_primeira_hab DATE, cnh_emissao DATE, cnh_validade DATE, cnh_categoria TEXT,
  -- Endereço
  endereco TEXT, cep TEXT, cidade TEXT, uf TEXT,
  -- Contato
  celular TEXT, tel_recado TEXT, tel_recado_nome TEXT, email TEXT,
  -- Família
  nome_pai TEXT, nome_mae TEXT, estado_civil TEXT, data_casamento DATE,
  conjuge_nome TEXT, conjuge_cpf TEXT, conjuge_rg TEXT, conjuge_nascimento DATE,
  tem_filhos BOOLEAN DEFAULT false,
  dependentes JSONB DEFAULT '[]',
  -- Complementares
  escolaridade TEXT, cor_raca TEXT, vale_transporte BOOLEAN DEFAULT false,
  banco TEXT, agencia TEXT, conta TEXT, primeiro_emprego BOOLEAN DEFAULT false, hobby TEXT,
  -- LGPD
  aceite_lgpd BOOLEAN DEFAULT false, aceite_lgpd_em TIMESTAMPTZ,
  -- Documentos (paths no Supabase Storage)
  docs JSONB DEFAULT '{}',
  -- Audit
  preenchido_em TIMESTAMPTZ DEFAULT now(),
  created_at TIMESTAMPTZ DEFAULT now()
);
