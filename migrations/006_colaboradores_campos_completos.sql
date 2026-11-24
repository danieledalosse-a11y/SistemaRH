-- ============================================================
-- MIGRAÇÃO 006: Adiciona colunas faltantes em colaboradores
-- Rodar no Supabase Dashboard → SQL Editor
-- ============================================================

-- Contato
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS whatsapp       TEXT,
  ADD COLUMN IF NOT EXISTS tel_recado     TEXT,
  ADD COLUMN IF NOT EXISTS nome_recado    TEXT;

-- Endereço
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS cep            TEXT,
  ADD COLUMN IF NOT EXISTS logradouro     TEXT,
  ADD COLUMN IF NOT EXISTS numero_end     TEXT,
  ADD COLUMN IF NOT EXISTS complemento    TEXT,
  ADD COLUMN IF NOT EXISTS bairro         TEXT,
  ADD COLUMN IF NOT EXISTS cidade         TEXT,
  ADD COLUMN IF NOT EXISTS estado_end     TEXT;

-- Naturalidade
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS estado_naturalidade TEXT,
  ADD COLUMN IF NOT EXISTS pais_nascimento     TEXT;

-- Documentos
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS rg_orgao       TEXT,
  ADD COLUMN IF NOT EXISTS rg_data        DATE,
  ADD COLUMN IF NOT EXISTS cnh            TEXT,
  ADD COLUMN IF NOT EXISTS ctps           TEXT,
  ADD COLUMN IF NOT EXISTS ctps_serie     TEXT,
  ADD COLUMN IF NOT EXISTS titulo_eleitor TEXT,
  ADD COLUMN IF NOT EXISTS titulo_zona    TEXT;

-- Controles especiais
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS pcd              BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS afastado_inss    BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS primeiro_emprego BOOLEAN DEFAULT FALSE;

-- Família
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS possui_filhos  TEXT,
  ADD COLUMN IF NOT EXISTS dependentes_lista JSONB;

-- Contrato e remuneração
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS tipo_contrato  TEXT,
  ADD COLUMN IF NOT EXISTS cbo            TEXT,
  ADD COLUMN IF NOT EXISTS jornada        TEXT,
  ADD COLUMN IF NOT EXISTS tipo_admissao  TEXT,
  ADD COLUMN IF NOT EXISTS historico_salarial JSONB;

-- Rescisão
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS causa_rescisao TEXT,
  ADD COLUMN IF NOT EXISTS aviso_previo   TEXT,
  ADD COLUMN IF NOT EXISTS data_aviso     DATE,
  ADD COLUMN IF NOT EXISTS venc_aviso     DATE;

-- Benefícios
ALTER TABLE colaboradores
  ADD COLUMN IF NOT EXISTS vt             TEXT,
  ADD COLUMN IF NOT EXISTS vt_passes      INTEGER,
  ADD COLUMN IF NOT EXISTS vt_linha       TEXT,
  ADD COLUMN IF NOT EXISTS banco          TEXT,
  ADD COLUMN IF NOT EXISTS banco_codigo   TEXT,
  ADD COLUMN IF NOT EXISTS agencia        TEXT,
  ADD COLUMN IF NOT EXISTS conta          TEXT,
  ADD COLUMN IF NOT EXISTS tipo_conta     TEXT,
  ADD COLUMN IF NOT EXISTS hobby          TEXT;
