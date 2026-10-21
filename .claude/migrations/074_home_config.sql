-- Migration 074: home_config por perfil de usuário
-- Controla acesso ao Home Dashboard e seções visíveis via Parâmetros Gerais
-- Autor: Revest RH — 2026-10-21
--
-- APENAS adiciona a coluna. Todas as linhas ficam NULL.
-- O código em routeHomePerfil trata NULL como "usar padrão do sistema":
--   - perfil gestor → dashboard habilitado (fallback)
--   - demais perfis → grade de módulos (fallback)
-- Configuração explícita é feita via Parâmetros Gerais > Perfis de Acesso.

ALTER TABLE perfis ADD COLUMN IF NOT EXISTS home_config JSONB DEFAULT NULL;
