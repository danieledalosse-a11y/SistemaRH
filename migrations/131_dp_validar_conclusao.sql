-- Migration 131: Trigger de validação de completude antes de concluir avaliação.
--
-- Bloqueia a transição para status 'concluida' quando há critérios obrigatórios
-- da versão sem resposta preenchida. Protege a integridade tanto via frontend
-- quanto por chamada direta à API REST do Supabase.
--
-- Lógica da validação:
--   1. Obtém versao_id via dp_ciclos (ciclo_id da avaliação)
--   2. Conta critérios com obrigatorio = true nessa versão
--   3. Conta respostas preenchidas para esses critérios nesta avaliação
--   4. Bloqueia se respondidos < obrigatórios
--
-- Dispara apenas na transição OLD.status → NEW.status = 'concluida'.
-- Não interfere em saves de rascunho, em_andamento ou respondida.
-- Funciona tanto na conclusão individual quanto em lote (ambos fazem PATCH em dp_avaliacoes).
--
-- REQUER: migration 130 (valor 'respondida' no ENUM) já aplicada e committed.
-- NÃO EXECUTAR sem aprovação explícita da usuária.

CREATE OR REPLACE FUNCTION dp_fn_validar_conclusao()
RETURNS TRIGGER LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_versao_id   uuid;
  v_total_obrig int;
  v_total_resp  int;
BEGIN
  -- Verifica apenas na transição PARA 'concluida'
  IF NEW.status <> 'concluida' THEN RETURN NEW; END IF;
  IF OLD.status IN ('concluida', 'publicada') THEN RETURN NEW; END IF;

  -- Obtém versao_id via ciclo
  SELECT versao_id INTO v_versao_id
  FROM dp_ciclos
  WHERE id = NEW.ciclo_id;

  IF v_versao_id IS NULL THEN RETURN NEW; END IF;

  -- Total de critérios obrigatórios da versão
  SELECT COUNT(*) INTO v_total_obrig
  FROM dp_versao_criterios
  WHERE versao_id = v_versao_id
    AND obrigatorio = true;

  -- Sem critérios obrigatórios: conclui livremente
  IF v_total_obrig = 0 THEN RETURN NEW; END IF;

  -- Respostas preenchidas para critérios obrigatórios desta avaliação
  SELECT COUNT(*) INTO v_total_resp
  FROM dp_respostas dr
  JOIN dp_versao_criterios vc ON vc.id = dr.versao_criterio_id
  WHERE dr.avaliacao_id = NEW.id
    AND vc.versao_id    = v_versao_id
    AND vc.obrigatorio  = true
    AND (
      dr.resposta_texto       IS NOT NULL OR
      dr.escala_opcao_id      IS NOT NULL OR
      dr.valor_numerico_livre IS NOT NULL
    );

  IF v_total_resp < v_total_obrig THEN
    RAISE EXCEPTION
      'Avaliação incompleta: % de % critérios obrigatórios respondidos. Responda todos os critérios antes de concluir.',
      v_total_resp, v_total_obrig;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validar_conclusao ON dp_avaliacoes;
CREATE TRIGGER trg_validar_conclusao
  BEFORE UPDATE ON dp_avaliacoes
  FOR EACH ROW EXECUTE FUNCTION dp_fn_validar_conclusao();

GRANT EXECUTE ON FUNCTION dp_fn_validar_conclusao() TO authenticated;
