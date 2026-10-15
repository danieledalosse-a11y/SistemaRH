-- 124_dp_fn_marcar_reverter_nao_participa.sql
-- Funções RPC para marcar e reverter não participação de forma atômica:
-- 1. Atualiza dp_ciclo_participantes.
-- 2. Registra evento em dp_historico_eventos na mesma transação.
-- SECURITY DEFINER garante que o histórico seja gravado mesmo que
-- a RLS restrinja INSERT direto em dp_historico_eventos pelo gestor.

CREATE OR REPLACE FUNCTION dp_fn_marcar_nao_participa(
  p_participante_id UUID,
  p_motivo_id       UUID,
  p_motivo_texto    TEXT,
  p_obs             TEXT DEFAULT NULL
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_ciclo_id UUID;
BEGIN
  -- Valida permissão: RH/admin ou gestor do ciclo
  SELECT ciclo_id INTO v_ciclo_id
  FROM dp_ciclo_participantes
  WHERE id = p_participante_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participante não encontrado.';
  END IF;

  IF auth_perfil() NOT IN ('rh','admin') THEN
    IF auth_perfil() = 'gestor' THEN
      IF v_ciclo_id NOT IN (SELECT auth_avaliador_ciclo_ids()) THEN
        RAISE EXCEPTION 'Sem permissão para este participante.';
      END IF;
    ELSE
      RAISE EXCEPTION 'Sem permissão.';
    END IF;
  END IF;

  -- Atualiza o flag
  UPDATE dp_ciclo_participantes SET
    nao_participa           = TRUE,
    nao_participa_motivo_id = p_motivo_id,
    nao_participa_motivo    = p_motivo_texto,
    nao_participa_obs       = p_obs,
    nao_participa_em        = now(),
    nao_participa_por       = auth.uid()
  WHERE id = p_participante_id;

  -- Registra no histórico
  INSERT INTO dp_historico_eventos (entidade, entidade_id, tipo, detalhe, usuario_id)
  VALUES (
    'dp_ciclo_participantes',
    p_participante_id,
    'nao_participa_marcado',
    jsonb_build_object(
      'motivo',     p_motivo_texto,
      'motivo_id',  p_motivo_id,
      'obs',        p_obs
    ),
    auth.uid()
  );
END;
$$;

CREATE OR REPLACE FUNCTION dp_fn_reverter_nao_participa(
  p_participante_id UUID
)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public AS $$
DECLARE
  v_ciclo_id UUID;
BEGIN
  SELECT ciclo_id INTO v_ciclo_id
  FROM dp_ciclo_participantes
  WHERE id = p_participante_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Participante não encontrado.';
  END IF;

  IF auth_perfil() NOT IN ('rh','admin') THEN
    IF auth_perfil() = 'gestor' THEN
      IF v_ciclo_id NOT IN (SELECT auth_avaliador_ciclo_ids()) THEN
        RAISE EXCEPTION 'Sem permissão para este participante.';
      END IF;
    ELSE
      RAISE EXCEPTION 'Sem permissão.';
    END IF;
  END IF;

  UPDATE dp_ciclo_participantes SET
    nao_participa           = FALSE,
    nao_participa_motivo_id = NULL,
    nao_participa_motivo    = NULL,
    nao_participa_obs       = NULL,
    nao_participa_em        = NULL,
    nao_participa_por       = NULL
  WHERE id = p_participante_id;

  INSERT INTO dp_historico_eventos (entidade, entidade_id, tipo, detalhe, usuario_id)
  VALUES (
    'dp_ciclo_participantes',
    p_participante_id,
    'nao_participa_revertido',
    jsonb_build_object('revertido_em', now()),
    auth.uid()
  );
END;
$$;
