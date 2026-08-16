-- Migration 042: armazenar senha de acesso para consulta pelo RH
ALTER TABLE usuarios_perfil ADD COLUMN IF NOT EXISTS senha_acesso TEXT;
