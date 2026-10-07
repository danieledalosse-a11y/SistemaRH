-- Migration 097 — fn_concluir_devolucao_uniforme
-- Grava evento de devolução de uniforme em historico_eventos na conclusão do
-- processo devolucao_uniforme.
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = dados_extras->>'data_demissao'::DATE (data efetiva da devolução)
--              fallback: concluido_em::DATE
--              fallback: CURRENT_DATE
-- dados      = { qtd_itens }
-- resumo     = '1 item devolvido' ou 'N itens devolvidos'

CREATE OR REPLACE FUNCTION fn_concluir_devolucao_uniforme(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc        processos_rh%ROWTYPE;
  v_extras      JSONB;
  v_qtd_itens   INTEGER;
  v_data_evento DATE;
  v_resumo      TEXT;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'devolucao_uniforme' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo devolucao_uniforme');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo sem colaborador vinculado');
  END IF;

  -- ── Idempotência: processo já concluído ──────────────────────────────────
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação
    v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_qtd_itens   := NULLIF(TRIM(v_extras->>'qtd_itens'), '')::INTEGER;
    v_data_evento := COALESCE(
      NULLIF(TRIM(v_extras->>'data_demissao'), '')::DATE,
      v_proc.concluido_em::DATE,
      CURRENT_DATE
    );

    IF v_qtd_itens IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Campo "qtd_itens" é obrigatório no processo ' || p_processo_id::TEXT);
    END IF;

    v_resumo := v_qtd_itens::TEXT ||
      CASE WHEN v_qtd_itens = 1 THEN ' item devolvido' ELSE ' itens devolvidos' END;

    PERFORM _validar_dados_evento('devolucao_uniforme',
      jsonb_build_object('qtd_itens', v_qtd_itens));

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id,
      'devolucao_uniforme',
      'Devolução de Uniforme',
      v_resumo,
      jsonb_build_object('qtd_itens', v_qtd_itens),
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de devolução de uniforme recuperado. Qtd: ' || v_qtd_itens::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de devolução de uniforme recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_qtd_itens   := NULLIF(TRIM(v_extras->>'qtd_itens'), '')::INTEGER;
  v_data_evento := COALESCE(
    NULLIF(TRIM(v_extras->>'data_demissao'), '')::DATE,
    CURRENT_DATE
  );

  IF v_qtd_itens IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Campo "qtd_itens" é obrigatório em dados_extras');
  END IF;

  v_resumo := v_qtd_itens::TEXT ||
    CASE WHEN v_qtd_itens = 1 THEN ' item devolvido' ELSE ' itens devolvidos' END;

  PERFORM _validar_dados_evento('devolucao_uniforme',
    jsonb_build_object('qtd_itens', v_qtd_itens));

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
    'devolucao_uniforme',
    'Devolução de Uniforme',
    v_resumo,
    jsonb_build_object('qtd_itens', v_qtd_itens),
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Devolução de uniforme registrada. Qtd: ' || v_qtd_itens::TEXT ||
          '. Data: ' || v_data_evento::TEXT,
          p_usuario, auth.uid());

  RETURN jsonb_build_object(
    'ok', true,
    'qtd_itens',    v_qtd_itens,
    'data_evento',  TO_CHAR(v_data_evento, 'DD/MM/YYYY')
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
