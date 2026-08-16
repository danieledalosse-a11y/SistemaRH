-- Migration 045: campo apelido em param_gestor para exibição resumida
ALTER TABLE param_gestor ADD COLUMN IF NOT EXISTS apelido TEXT;
