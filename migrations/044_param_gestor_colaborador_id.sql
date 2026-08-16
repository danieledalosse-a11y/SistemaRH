-- Migration 044: vincular gestor ao colaborador do cadastro
ALTER TABLE param_gestor ADD COLUMN IF NOT EXISTS colaborador_id INTEGER REFERENCES colaboradores(id);
