-- Migration 060: view v_usuarios_perfil — e-mail sempre vindo do Supabase Auth
-- Elimina duplicação: auth.users é a fonte única de verdade para email.
-- O campo usuarios_perfil.email permanece como cache/fallback para casos em que
-- o user_id ainda não está vinculado, mas nunca é a fonte principal de exibição.

CREATE OR REPLACE VIEW public.v_usuarios_perfil AS
SELECT
  up.id,
  up.user_id,
  up.nome,
  up.perfil,
  up.perfil_id,
  up.colaborador_id,
  up.ativo,
  up.cargo,
  up.acesso_modulos,
  -- senha_acesso removida (migration 061): senha fica exclusivamente no Supabase Auth
  up.criado_por,
  up.alterado_por,
  up.created_at,
  up.updated_at,
  -- E-mail sempre do Auth (via user_id); fallback para campo local se user_id não vinculado
  COALESCE(au.email, up.email) AS email
FROM public.usuarios_perfil up
LEFT JOIN auth.users au ON au.id = up.user_id;

-- Leitura liberada para usuários autenticados
-- (acesso controlado no app por guardModulo('parametros') — apenas Admin)
GRANT SELECT ON public.v_usuarios_perfil TO authenticated;
