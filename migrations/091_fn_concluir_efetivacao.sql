-- Migration 091 — fn_concluir_efetivacao
-- Grava evento de efetivação em historico_eventos na conclusão do processo
-- avaliacao_final_experiencia. Processo cancelado é recusado (colaborador
-- não foi efetivado — não gera evento na timeline).
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = dados_extras->>'fim_experiencia'::DATE (data oficial do fim do período)
--              fallback: concluido_em::DATE
-- dados      = { fim_experiencia }

CREATE OR REPLACE FUNCTION fn_concluir_efetivacao(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc            processos_rh%ROWTYPE;
  v_extras          JSONB;
  v_fim_experiencia TEXT;
  v_data_evento     DATE;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'avaliacao_final_experiencia' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo avaliacao_final_experiencia');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo sem colaborador vinculado');
  END IF;

  IF v_proc.status = 'cancelado' THEN
    -- Processo cancelado = colaborador não foi efetivado; não gera evento.
    RETURN jsonb_build_object('ok', false, 'erro',
      'Processo cancelado — colaborador não efetivado. Nenhum evento gerado.');
  END IF;

  -- ── Idempotência: processo já concluído ──────────────────────────────────
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação
    v_extras          := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_fim_experiencia := NULLIF(TRIM(v_extras->>'fim_experiencia'), '');
    v_data_evento     := COALESCE(
      NULLIF(v_fim_experiencia, '')::DATE,
      v_proc.concluido_em::DATE
    );

    IF v_data_evento IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Não foi possível determinar a data de efetivação do processo ' || p_processo_id::TEXT);
    END IF;

    PERFORM _validar_dados_evento('efetivacao',
      jsonb_build_object('fim_experiencia', v_fim_experiencia));

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id,
      'efetivacao',
      'Efetivado',
      'Efetivado após período de experiência',
      jsonb_build_object('fim_experiencia', v_fim_experiencia),
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de efetivação recuperado. Data: ' || v_data_evento::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de efetivação recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras          := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_fim_experiencia := NULLIF(TRIM(v_extras->>'fim_experiencia'), '');
  v_data_evento     := COALESCE(
    NULLIF(v_fim_experiencia, '')::DATE,
    CURRENT_DATE
  );

  PERFORM _validar_dados_evento('efetivacao',
    jsonb_build_object('fim_experiencia', v_fim_experiencia));

  -- ── ETAPA 3: Marcar processo como concluído ──────────────────────────────
  UPDATE processos_rh SET
    status        = 'concluido',
    concluido_em  = NOW(),
    atualizado_em = NOW(),
    dados_extras  = v_extras || jsonb_build_object('concluido_por', p_usuario)
  WHERE id = p_processo_id;

  -- ── ETAPA 4: Gravar evento na linha do tempo ─────────────────────────────
  INSERT INTO historico_eventos (
    colaborador_id, tipo, titulo, resumo, dados,
    data_evento, registrado_por, registrado_por_id,
    ref_tabela, ref_id, processo_id, origem
  ) VALUES (
    v_proc.colaborador_id,
    'efetivacao',
    'Efetivado',
    'Efetivado após período de experiência',
    jsonb_build_object('fim_experiencia', v_fim_experiencia),
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Efetivação registrada. Data: ' || v_data_evento::TEXT,
          p_usuario, auth.uid());

  RETURN jsonb_build_object('ok', true, 'fim_experiencia', TO_CHAR(v_data_evento, 'DD/MM/YYYY'));

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
