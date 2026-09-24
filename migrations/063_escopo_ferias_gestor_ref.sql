-- Migration 063: Adiciona referência estruturada ao gestor em param_escopo_ferias
-- Substitui o uso do campo text 'valor' para o tipo 'gestor' por uma FK real.

-- 1. Adiciona coluna FK para o gestor referenciado
ALTER TABLE param_escopo_ferias
  ADD COLUMN IF NOT EXISTS gestor_ref_id integer REFERENCES param_gestor(id) ON DELETE RESTRICT;

-- 2. Adiciona 'gestor' ao CHECK constraint de tipo
ALTER TABLE param_escopo_ferias
  DROP CONSTRAINT IF EXISTS param_escopo_ferias_tipo_check;

ALTER TABLE param_escopo_ferias
  ADD CONSTRAINT param_escopo_ferias_tipo_check
  CHECK (tipo IN ('empresa_atuacao', 'setor', 'todos', 'gestor'));

-- Regra de uso:
--   tipo = 'gestor'          → gestor_ref_id preenchido, valor NULL
--   tipo = 'empresa_atuacao' → valor preenchido (stripNum), gestor_ref_id NULL
--   tipo = 'setor'           → valor preenchido (stripNum), gestor_ref_id NULL
--   tipo = 'todos'           → ambos NULL
