-- Migration 096 — fn_concluir_vt_alteracao
-- Grava evento de alteração de Vale-Transporte em historico_eventos na
-- conclusão do processo vt_alteracao. Processos criados durante admissão
-- (antes de o candidato ser efetivado) têm colaborador_id=NULL e são
-- recusados com mensagem explícita — não geram evento.
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = concluido_em::DATE
--              fallback: CURRENT_DATE
-- dados      = { operacao, vt_linha, vt_cartao, vt_passes, vt_viacao }
-- titulo     = dinâmico por operação (inclusao/alteracao/cancelamento)

CREATE OR REPLACE FUNCTION fn_concluir_vt_alteracao(
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
  v_operacao    TEXT;
  v_vt_linha    TEXT;
  v_vt_cartao   TEXT;
  v_vt_passes   INTEGER;
  v_vt_viacao   TEXT;
  v_data_evento DATE;
  v_titulo      TEXT;
  v_resumo      TEXT;
  v_dados       JSONB;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'vt_alteracao' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo vt_alteracao');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Processo de VT sem colaborador vinculado — criado durante admissão, antes da efetivação');
  END IF;

  -- ── Idempotência: processo já concluído ──────────────────────────────────
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação
    v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_operacao    := NULLIF(TRIM(v_extras->>'operacao'), '');
    v_vt_linha    := NULLIF(TRIM(v_extras->>'vt_linha'), '');
    v_vt_cartao   := NULLIF(TRIM(v_extras->>'vt_cartao'), '');
    v_vt_passes   := NULLIF(TRIM(v_extras->>'vt_passes'), '')::INTEGER;
    v_vt_viacao   := NULLIF(TRIM(v_extras->>'vt_viacao'), '');
    v_data_evento := COALESCE(v_proc.concluido_em::DATE, CURRENT_DATE);

    IF v_operacao IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Campo "operacao" é obrigatório no processo ' || p_processo_id::TEXT);
    END IF;

    v_titulo := CASE v_operacao
      WHEN 'inclusao'      THEN 'VT Incluído'
      WHEN 'alteracao'     THEN 'VT Alterado'
      WHEN 'cancelamento'  THEN 'VT Cancelado'
      ELSE 'Vale-Transporte'
    END;

    v_resumo := v_operacao ||
      CASE WHEN v_vt_linha IS NOT NULL THEN ': ' || v_vt_linha ELSE '' END;

    v_dados := jsonb_build_object(
      'operacao',   v_operacao,
      'vt_linha',   v_vt_linha,
      'vt_cartao',  v_vt_cartao,
      'vt_passes',  v_vt_passes,
      'vt_viacao',  v_vt_viacao
    );

    PERFORM _validar_dados_evento('vt_alteracao', v_dados);

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id,
      'vt_alteracao',
      v_titulo, v_resumo, v_dados,
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de VT recuperado. Operação: ' || v_operacao,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de VT recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_operacao    := NULLIF(TRIM(v_extras->>'operacao'), '');
  v_vt_linha    := NULLIF(TRIM(v_extras->>'vt_linha'), '');
  v_vt_cartao   := NULLIF(TRIM(v_extras->>'vt_cartao'), '');
  v_vt_passes   := NULLIF(TRIM(v_extras->>'vt_passes'), '')::INTEGER;
  v_vt_viacao   := NULLIF(TRIM(v_extras->>'vt_viacao'), '');
  v_data_evento := CURRENT_DATE;

  IF v_operacao IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Campo "operacao" é obrigatório em dados_extras');
  END IF;

  v_titulo := CASE v_operacao
    WHEN 'inclusao'      THEN 'VT Incluído'
    WHEN 'alteracao'     THEN 'VT Alterado'
    WHEN 'cancelamento'  THEN 'VT Cancelado'
    ELSE 'Vale-Transporte'
  END;

  v_resumo := v_operacao ||
    CASE WHEN v_vt_linha IS NOT NULL THEN ': ' || v_vt_linha ELSE '' END;

  v_dados := jsonb_build_object(
    'operacao',   v_operacao,
    'vt_linha',   v_vt_linha,
    'vt_cartao',  v_vt_cartao,
    'vt_passes',  v_vt_passes,
    'vt_viacao',  v_vt_viacao
  );

  PERFORM _validar_dados_evento('vt_alteracao', v_dados);

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
    'vt_alteracao',
    v_titulo, v_resumo, v_dados,
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'VT registrado. Operação: ' || v_operacao ||
          CASE WHEN v_vt_linha IS NOT NULL THEN '. Linha: ' || v_vt_linha ELSE '' END,
          p_usuario, auth.uid());

  RETURN jsonb_build_object(
    'ok', true,
    'operacao',  v_operacao,
    'vt_linha',  v_vt_linha,
    'vt_cartao', v_vt_cartao
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
