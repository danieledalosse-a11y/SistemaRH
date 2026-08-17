-- Migration 046: user_id de quem criou o processo para filtro por gestor
ALTER TABLE processos_rh ADD COLUMN IF NOT EXISTS criado_por_user_id UUID REFERENCES auth.users(id);
