-- Migration 059: campo requer_colaborador em perfis + trigger de integridade em usuarios_perfil
-- Data: 2026-09-21

-- 1. Adiciona coluna requer_colaborador na tabela perfis
ALTER TABLE perfis ADD COLUMN IF NOT EXISTS requer_colaborador BOOLEAN NOT NULL DEFAULT false;

-- 2. Marca os perfis que exigem colaborador vinculado
--    Gestor (id=3) e Colaborador (id=6) — derivado dos registros atuais, não hardcodado na regra
UPDATE perfis SET requer_colaborador = true WHERE nome IN ('Gestor', 'Colaborador');

-- 3. Função de verificação de integridade (sem IDs nem nomes fixos — lê requer_colaborador)
CREATE OR REPLACE FUNCTION fn_check_colaborador_obrigatorio()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.colaborador_id IS NULL AND NEW.perfil_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM perfis WHERE id = NEW.perfil_id AND requer_colaborador = true
    ) THEN
      RAISE EXCEPTION 'Este perfil exige um colaborador vinculado. Preencha colaborador_id.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Trigger disparado em INSERT e UPDATE de usuarios_perfil
DROP TRIGGER IF EXISTS trg_check_colaborador_obrigatorio ON usuarios_perfil;
CREATE TRIGGER trg_check_colaborador_obrigatorio
  BEFORE INSERT OR UPDATE ON usuarios_perfil
  FOR EACH ROW EXECUTE FUNCTION fn_check_colaborador_obrigatorio();

-- Nota: registros existentes com colaborador_id IS NULL não são afetados retroativamente.
-- Eles precisam ser corrigidos individualmente (ex: Madson id=15 → colaborador_id=1827).
