-- Migration 064: Constraint única em param_escopo_ferias
-- Impede duplicatas: mesmo gestor não pode ter dois escopos iguais.

-- Tipo 'gestor': unique por (gestor_id, gestor_ref_id)
CREATE UNIQUE INDEX IF NOT EXISTS uq_escopo_ferias_gestor_ref
  ON param_escopo_ferias (gestor_id, gestor_ref_id)
  WHERE tipo = 'gestor' AND ativo = true;

-- Tipo 'empresa_atuacao' ou 'setor': unique por (gestor_id, tipo, valor)
CREATE UNIQUE INDEX IF NOT EXISTS uq_escopo_ferias_valor
  ON param_escopo_ferias (gestor_id, tipo, valor)
  WHERE tipo IN ('empresa_atuacao', 'setor') AND ativo = true;

-- Tipo 'todos': unique por gestor_id (só pode ter um)
CREATE UNIQUE INDEX IF NOT EXISTS uq_escopo_ferias_todos
  ON param_escopo_ferias (gestor_id)
  WHERE tipo = 'todos' AND ativo = true;
