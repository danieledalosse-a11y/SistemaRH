-- Migration 062: Escopo adicional de gestão de férias
-- Parametriza quais colaboradores um gestor pode ver no módulo Férias,
-- além da sua equipe estrutural definida em param_gestor_setor.

CREATE TABLE IF NOT EXISTS param_escopo_ferias (
  id         uuid    NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  gestor_id  integer NOT NULL REFERENCES param_gestor(id) ON DELETE CASCADE,
  tipo       text    NOT NULL CHECK (tipo IN ('empresa_atuacao', 'setor', 'todos')),
  valor      text,                 -- NULL quando tipo = 'todos'
  ativo      boolean NOT NULL DEFAULT true,
  criado_em  timestamptz NOT NULL DEFAULT now(),
  criado_por text
);

-- Permite múltiplas regras por gestor (cada regra adiciona colaboradores ao escopo)
-- RLS: mesma política das demais tabelas param_* (sem RLS, acesso via service role key)

COMMENT ON TABLE  param_escopo_ferias IS 'Escopo adicional de colaboradores visíveis no módulo Férias por gestor. Soma-se à equipe estrutural (param_gestor_setor), nunca a substitui.';
COMMENT ON COLUMN param_escopo_ferias.tipo  IS 'empresa_atuacao = todos da empresa; setor = todos do setor; todos = todos os CLT ativos';
COMMENT ON COLUMN param_escopo_ferias.valor IS 'Nome normalizado (stripNum) da empresa ou setor. NULL quando tipo = todos.';
