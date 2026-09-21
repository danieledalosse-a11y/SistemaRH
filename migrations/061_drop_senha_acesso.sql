-- Migration 061: remover senha_acesso de usuarios_perfil
-- Senhas devem existir APENAS no Supabase Auth (criptografadas).
-- Manter cópia em texto claro na tabela é risco de segurança desnecessário.
-- O Admin API (updateUserById) já permite ao RH redefinir senhas via sistema.

ALTER TABLE public.usuarios_perfil DROP COLUMN IF EXISTS senha_acesso;
