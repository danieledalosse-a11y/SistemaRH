-- 126_dp_bloquear_aval_concluida.sql
-- Impede alteração de respostas quando a avaliação pai já está concluída ou publicada.
-- A proteção na tela (JS) é conveniente; esta trigger é a proteção real.

CREATE OR REPLACE FUNCTION dp_fn_bloquear_resp_aval_concluida()
RETURNS TRIGGER AS $$
DECLARE
  v_status TEXT;
BEGIN
  SELECT status INTO v_status
    FROM dp_avaliacoes
   WHERE id = NEW.avaliacao_id;

  IF v_status IN ('concluida', 'publicada') THEN
    RAISE EXCEPTION 'Avaliação já concluída — não é possível alterar respostas.';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bloquear_resp_aval_concluida ON dp_respostas;
CREATE TRIGGER trg_bloquear_resp_aval_concluida
  BEFORE INSERT OR UPDATE ON dp_respostas
  FOR EACH ROW EXECUTE FUNCTION dp_fn_bloquear_resp_aval_concluida();

-- Impede reversão do status de concluída/publicada para outro via UPDATE direto.
CREATE OR REPLACE FUNCTION dp_fn_bloquear_reverter_conclusao()
RETURNS TRIGGER AS $$
BEGIN
  IF OLD.status IN ('concluida', 'publicada')
     AND NEW.status NOT IN ('concluida', 'publicada') THEN
    RAISE EXCEPTION 'Avaliação concluída não pode ser reaberta.';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_bloquear_reverter_conclusao ON dp_avaliacoes;
CREATE TRIGGER trg_bloquear_reverter_conclusao
  BEFORE UPDATE ON dp_avaliacoes
  FOR EACH ROW EXECUTE FUNCTION dp_fn_bloquear_reverter_conclusao();
