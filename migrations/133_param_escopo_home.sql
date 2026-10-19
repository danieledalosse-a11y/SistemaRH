-- Migration 133: param_escopo_home
-- Escopo adicional de visualização na Home do Gestor, independente de Férias.
-- Permite ampliar aniversariantes (e futuras funcionalidades) por gestor, via Parâmetros Gerais.
-- Segue o mesmo padrão de param_escopo_ferias (gestor_id = param_gestor.id, sem RLS própria).

CREATE TABLE IF NOT EXISTS param_escopo_home (
  id            UUID        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  gestor_id     INTEGER     NOT NULL REFERENCES param_gestor(id) ON DELETE CASCADE,
  modulo        TEXT        NOT NULL DEFAULT 'aniversarios',  -- 'aniversarios' (futuro: 'atividades', 'ferias')
  tipo          TEXT        NOT NULL,  -- 'gestor' | 'empresa_atuacao' | 'setor' | 'todos'
  valor         TEXT,                  -- nome da empresa/setor; NULL quando tipo = 'gestor' ou 'todos'
  gestor_ref_id BIGINT      REFERENCES param_gestor(id) ON DELETE SET NULL,
  ativo         BOOLEAN     NOT NULL DEFAULT true,
  criado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  criado_por    TEXT
);

CREATE INDEX IF NOT EXISTS idx_peh_gestor ON param_escopo_home (gestor_id) WHERE ativo = true;

COMMENT ON TABLE  param_escopo_home IS 'Escopo adicional de colaboradores visíveis na Home do Gestor por funcionalidade. Soma-se à equipe estrutural, nunca a substitui.';
COMMENT ON COLUMN param_escopo_home.modulo IS 'aniversarios = aniversariantes e tempo de casa. Outros módulos implementados futuramente.';
COMMENT ON COLUMN param_escopo_home.tipo   IS 'gestor = equipe de outro gestor; empresa_atuacao = todos da empresa; setor = todos do setor; todos = todos os CLT ativos';
COMMENT ON COLUMN param_escopo_home.valor  IS 'Nome normalizado da empresa ou setor. NULL quando tipo = gestor ou todos.';
