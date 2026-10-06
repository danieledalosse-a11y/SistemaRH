-- Migration 086 — fn_concluir_admissao
-- Grava evento de admissão em historico_eventos na conclusão do processo.
-- Chamada pelo módulo de admissão ao finalizar o onboarding.
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = colaboradores.data_admissao (fonte oficial do cadastro)
-- Não altera colaboradores — o módulo de admissão já faz isso.

CREATE OR REPLACE FUNCTION fn_concluir_admissao(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc          processos_rh%ROWTYPE;
  v_colab         colaboradores%ROWTYPE;
  v_extras        JSONB;
  v_cargo         TEXT;
  v_empresa       TEXT;
  v_data_evento   DATE;
  v_dados_evento  JSONB;
  v_titulo_evento TEXT;
  v_resumo_evento TEXT;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'admissao' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo admissao');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo sem colaborador vinculado');
  END IF;

  IF v_proc.status = 'cancelado' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo cancelado não pode ser concluído');
  END IF;

  -- ── Idempotência: processo já concluído ──────────────────────────────────
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação: reconstrói evento a partir de dados_extras + colaborador
    SELECT * INTO v_colab FROM colaboradores WHERE id = v_proc.colaborador_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador não encontrado para recuperação');
    END IF;

    v_extras    := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_cargo     := NULLIF(TRIM(v_extras->>'cargo'), '');
    v_empresa   := NULLIF(TRIM(v_extras->>'empresa'), '');
    v_data_evento := COALESCE(v_colab.data_admissao, v_proc.concluido_em::DATE);

    IF v_cargo IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'erro', 'Campo "cargo" ausente em dados_extras do processo ' || p_processo_id::TEXT ||
                '. Não é possível recuperar o evento.'
      );
    END IF;

    IF v_data_evento IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'erro', 'data_admissao do colaborador e concluido_em do processo estão nulos. ' ||
                'Não é possível determinar a data do evento.'
      );
    END IF;

    v_dados_evento  := jsonb_build_object('cargo', v_cargo, 'empresa', v_empresa);
    v_titulo_evento := 'Admitido como ' || v_cargo;
    v_resumo_evento := COALESCE(v_empresa, v_cargo);

    PERFORM _validar_dados_evento('admissao', v_dados_evento);

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id, 'admissao', v_titulo_evento, v_resumo_evento, v_dados_evento,
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de admissão recuperado. Data: ' || v_data_evento::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de admissão recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras    := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_cargo     := NULLIF(TRIM(v_extras->>'cargo'), '');
  v_empresa   := NULLIF(TRIM(v_extras->>'empresa'), '');

  IF v_cargo IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Campo "cargo" ausente em dados_extras');
  END IF;

  -- Carrega colaborador para obter data_admissao
  SELECT * INTO v_colab FROM colaboradores WHERE id = v_proc.colaborador_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador não encontrado');
  END IF;

  IF v_colab.data_demissao IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador desligado — admissão não aplicável');
  END IF;

  v_data_evento := COALESCE(v_colab.data_admissao, CURRENT_DATE);

  -- ── ETAPA 3: Marcar processo como concluído ──────────────────────────────
  UPDATE processos_rh SET
    status        = 'concluido',
    concluido_em  = NOW(),
    atualizado_em = NOW(),
    dados_extras  = v_extras || jsonb_build_object('concluido_por', p_usuario)
  WHERE id = p_processo_id;

  -- ── ETAPA 4: Gravar evento na linha do tempo ─────────────────────────────
  v_dados_evento  := jsonb_build_object('cargo', v_cargo, 'empresa', v_empresa);
  v_titulo_evento := 'Admitido como ' || v_cargo;
  v_resumo_evento := COALESCE(v_empresa, v_cargo);

  PERFORM _validar_dados_evento('admissao', v_dados_evento);

  INSERT INTO historico_eventos (
    colaborador_id, tipo, titulo, resumo, dados,
    data_evento, registrado_por, registrado_por_id,
    ref_tabela, ref_id, processo_id, origem
  ) VALUES (
    v_proc.colaborador_id, 'admissao', v_titulo_evento, v_resumo_evento, v_dados_evento,
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Admissão registrada. Data: ' || v_data_evento::TEXT,
          p_usuario, auth.uid());

  RETURN jsonb_build_object('ok', true, 'data_admissao', TO_CHAR(v_data_evento, 'DD/MM/YYYY'), 'cargo', v_cargo);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
