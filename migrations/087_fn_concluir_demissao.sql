-- Migration 087 — fn_concluir_demissao
-- Grava evento de desligamento em historico_eventos na conclusão do processo.
-- Chamada pelo módulo de demissão ao registrar o desligamento.
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = dados_extras->>'data_demissao' (ou colaboradores.data_demissao)
-- Não altera colaboradores — o módulo de demissão já faz isso.

CREATE OR REPLACE FUNCTION fn_concluir_demissao(
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
  v_motivo        TEXT;
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

  IF v_proc.tipo <> 'demissao' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo demissao');
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

    v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_motivo      := NULLIF(TRIM(v_extras->>'motivo'), '');
    v_data_evento := COALESCE(
      NULLIF(TRIM(v_extras->>'data_demissao'), '')::DATE,
      v_colab.data_demissao,
      v_proc.concluido_em::DATE
    );

    IF v_data_evento IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'erro', 'Não foi possível determinar a data de demissão do processo ' || p_processo_id::TEXT
      );
    END IF;

    v_dados_evento  := jsonb_build_object('motivo', v_motivo);
    v_titulo_evento := 'Desligamento';
    v_resumo_evento := COALESCE(v_motivo, '');

    PERFORM _validar_dados_evento('demissao', v_dados_evento);

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id, 'demissao', v_titulo_evento, v_resumo_evento, v_dados_evento,
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de desligamento recuperado. Data: ' || v_data_evento::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de desligamento recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_motivo      := NULLIF(TRIM(v_extras->>'motivo'), '');
  v_data_evento := NULLIF(TRIM(v_extras->>'data_demissao'), '')::DATE;

  IF v_data_evento IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Campo "data_demissao" ausente em dados_extras');
  END IF;

  -- Carrega colaborador (validação)
  SELECT * INTO v_colab FROM colaboradores WHERE id = v_proc.colaborador_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador não encontrado');
  END IF;

  -- ── ETAPA 3: Marcar processo como concluído ──────────────────────────────
  UPDATE processos_rh SET
    status        = 'concluido',
    concluido_em  = NOW(),
    atualizado_em = NOW(),
    dados_extras  = v_extras || jsonb_build_object('concluido_por', p_usuario)
  WHERE id = p_processo_id;

  -- ── ETAPA 4: Gravar evento na linha do tempo ─────────────────────────────
  v_dados_evento  := jsonb_build_object('motivo', v_motivo);
  v_titulo_evento := 'Desligamento';
  v_resumo_evento := COALESCE(v_motivo, '');

  PERFORM _validar_dados_evento('demissao', v_dados_evento);

  INSERT INTO historico_eventos (
    colaborador_id, tipo, titulo, resumo, dados,
    data_evento, registrado_por, registrado_por_id,
    ref_tabela, ref_id, processo_id, origem
  ) VALUES (
    v_proc.colaborador_id, 'demissao', v_titulo_evento, v_resumo_evento, v_dados_evento,
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Desligamento registrado. Data: ' || v_data_evento::TEXT,
          p_usuario, auth.uid());

  RETURN jsonb_build_object('ok', true, 'data_demissao', TO_CHAR(v_data_evento, 'DD/MM/YYYY'));

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
