-- Migration 040: vínculo formal entre usuário do sistema e colaborador
ALTER TABLE usuarios_perfil ADD COLUMN IF NOT EXISTS colaborador_id INTEGER REFERENCES colaboradores(id);
