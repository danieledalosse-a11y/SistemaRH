-- Migration 041: permitir criar perfil antes de vincular conta de autenticação
ALTER TABLE usuarios_perfil ALTER COLUMN user_id DROP NOT NULL;
