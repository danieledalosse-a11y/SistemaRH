-- 122_dp_trg_bloqueia_aval_nao_participa.sql
-- Trigger que impede INSERT de nova dp_avaliacao para participante
-- marcado como nao_participa = TRUE.
-- Apenas INSERT: UPDATE de avaliações existentes é livre (preserva histórico).

CREATE OR REPLACE FUNCTION dp_fn_bloqueia_aval_nao_participa()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_nao_participa BOOLEAN;
BEGIN
  SELECT nao_participa INTO v_nao_participa
  FROM dp_ciclo_participantes
  WHERE id = NEW.participante_id;

  IF v_nao_participa = TRUE THEN
    RAISE EXCEPTION
      'Participante está marcado como não participante neste ciclo. Reverta o status antes de iniciar uma avaliação.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS dp_trg_bloqueia_aval_nao_participa ON dp_avaliacoes;

CREATE TRIGGER dp_trg_bloqueia_aval_nao_participa
  BEFORE INSERT ON dp_avaliacoes
  FOR EACH ROW
  WHEN (NEW.participante_id IS NOT NULL)
  EXECUTE FUNCTION dp_fn_bloqueia_aval_nao_participa();
