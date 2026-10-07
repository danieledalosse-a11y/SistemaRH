-- Migration 090 — fn_concluir_prorrogacao_experiencia
-- Grava evento de prorrogação de contrato de experiência em historico_eventos.
-- Chamada pelo módulo de processos ao concluir o processo prorrogacao_experiencia.
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = concluido_em::DATE (data em que a prorrogação foi registrada)
-- dados      = { fim_45_dias }

CREATE OR REPLACE FUNCTION fn_concluir_prorrogacao_experiencia(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc          processos_rh%ROWTYPE;
  v_extras        JSONB;
  v_fim_45_dias   TEXT;
  v_data_evento   DATE;
  v_dados_evento  JSONB;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'prorrogacao_experiencia' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo prorrogacao_experiencia');
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

    -- Modo recuperação
    v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_fim_45_dias := NULLIF(TRIM(v_extras->>'fim_45_dias'), '');
    v_data_evento := COALESCE(v_proc.concluido_em::DATE, CURRENT_DATE);

    PERFORM _validar_dados_evento('prorrogacao_experiencia',
      jsonb_build_object('fim_45_dias', v_fim_45_dias));

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id,
      'prorrogacao_experiencia',
      'Prorrogação de Experiência',
      COALESCE('Prorrogado até ' || v_fim_45_dias, 'Prorrogação de experiência registrada'),
      jsonb_build_object('fim_45_dias', v_fim_45_dias),
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de prorrogação de experiência recuperado. Data: ' || v_data_evento::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de prorrogação de experiência recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_fim_45_dias := NULLIF(TRIM(v_extras->>'fim_45_dias'), '');
  v_data_evento := CURRENT_DATE;

  PERFORM _validar_dados_evento('prorrogacao_experiencia',
    jsonb_build_object('fim_45_dias', v_fim_45_dias));

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
    'prorrogacao_experiencia',
    'Prorrogação de Experiência',
    COALESCE('Prorrogado até ' || v_fim_45_dias, 'Prorrogação de experiência registrada'),
    jsonb_build_object('fim_45_dias', v_fim_45_dias),
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Prorrogação de experiência registrada.',
          p_usuario, auth.uid());

  RETURN jsonb_build_object('ok', true, 'fim_45_dias', v_fim_45_dias);

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
