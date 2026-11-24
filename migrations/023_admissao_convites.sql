CREATE TABLE IF NOT EXISTS admissao_convites (
  id          BIGSERIAL PRIMARY KEY,
  token       UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  nome_candidato TEXT NOT NULL,
  email_candidato TEXT,
  telefone    TEXT,
  cargo_pretendido TEXT,
  unidade     TEXT,
  enviado_por TEXT,
  enviado_em  TIMESTAMPTZ DEFAULT now(),
  status      TEXT DEFAULT 'pendente',  -- pendente | preenchido | aprovado | efetivado | cancelado
  observacoes TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);
