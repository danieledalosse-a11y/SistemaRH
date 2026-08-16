-- Migration 043: RBAC — tabela de perfis configuráveis
CREATE TABLE IF NOT EXISTS perfis (
  id          SERIAL PRIMARY KEY,
  nome        TEXT NOT NULL,
  descricao   TEXT,
  modulos     JSONB NOT NULL DEFAULT '[]',
  ativo       BOOLEAN NOT NULL DEFAULT TRUE,
  criado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Perfis iniciais
INSERT INTO perfis (nome, descricao, modulos) VALUES
  ('Admin',  'Acesso completo ao sistema',              '["cadastro","ferias","processos","uniformes","admissao","parametros"]'),
  ('RH',     'Acesso aos módulos operacionais de RH',   '["cadastro","ferias","processos","admissao"]'),
  ('Gestor', 'Acesso a férias e workflow da equipe',    '["ferias","processos"]')
ON CONFLICT DO NOTHING;

-- Vínculo na tabela de usuários
ALTER TABLE usuarios_perfil ADD COLUMN IF NOT EXISTS perfil_id INTEGER REFERENCES perfis(id);
