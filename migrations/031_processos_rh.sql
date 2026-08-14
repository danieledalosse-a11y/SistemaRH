-- Tabela principal de processos
CREATE TABLE IF NOT EXISTS processos_rh (
  id            BIGSERIAL PRIMARY KEY,
  tipo          TEXT NOT NULL, -- admissao | demissao | reajuste | vt_avulso | bonus_indicacao | atestado
  colaborador_id BIGINT REFERENCES colaboradores(id) ON DELETE CASCADE,
  colaborador_nome TEXT,       -- snapshot do nome (para caso colaborador seja deletado)
  status        TEXT NOT NULL DEFAULT 'aberto', -- aberto | concluido | cancelado
  dados_extras  JSONB DEFAULT '{}',  -- dados específicos do tipo (ex: {salario_novo, data_demissao})
  criado_em     TIMESTAMPTZ DEFAULT NOW(),
  criado_por    TEXT,
  concluido_em  TIMESTAMPTZ,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Itens do checklist de cada processo
CREATE TABLE IF NOT EXISTS processos_checklist (
  id            BIGSERIAL PRIMARY KEY,
  processo_id   BIGINT REFERENCES processos_rh(id) ON DELETE CASCADE,
  ordem         INT DEFAULT 0,
  item          TEXT NOT NULL,
  responsavel   TEXT,
  prazo_dias    INT,           -- dias úteis após criação do processo
  concluido     BOOLEAN DEFAULT FALSE,
  concluido_por TEXT,
  concluido_em  TIMESTAMPTZ,
  observacao    TEXT
);

-- RLS permissivo (autenticado pode tudo)
ALTER TABLE processos_rh ENABLE ROW LEVEL SECURITY;
ALTER TABLE processos_checklist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all" ON processos_rh FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "auth_all" ON processos_checklist FOR ALL TO authenticated USING (true) WITH CHECK (true);
