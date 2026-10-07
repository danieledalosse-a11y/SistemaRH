-- Migration 095 — fn_concluir_bonus_indicacao
-- Grava evento de bônus de indicação em historico_eventos na conclusão do
-- processo bonus_indicacao. Processo cancelado é recusado (bônus não pago).
-- Idempotente: pode ser chamada múltiplas vezes com segurança.
-- Modo recuperação: se processo já concluído sem evento, reconstrói o evento.
--
-- data_evento = concluido_em::DATE (data de registro do bônus)
--              fallback: CURRENT_DATE
-- dados      = { indicado_nome, valor_bonus, mes_folha }

CREATE OR REPLACE FUNCTION fn_concluir_bonus_indicacao(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc         processos_rh%ROWTYPE;
  v_extras       JSONB;
  v_indicado     TEXT;
  v_valor_bonus  NUMERIC(12,2);
  v_mes_folha    TEXT;
  v_data_evento  DATE;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'bonus_indicacao' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo bonus_indicacao');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo sem colaborador vinculado');
  END IF;

  IF v_proc.status = 'cancelado' THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Processo cancelado — bônus não será pago. Nenhum evento gerado.');
  END IF;

  -- ── Idempotência: processo já concluído ──────────────────────────────────
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação
    v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_indicado    := NULLIF(TRIM(v_extras->>'indicado_nome'), '');
    v_valor_bonus := NULLIF(TRIM(v_extras->>'valor_bonus'), '')::NUMERIC;
    v_mes_folha   := NULLIF(TRIM(v_extras->>'mes_folha'), '');
    v_data_evento := COALESCE(v_proc.concluido_em::DATE, CURRENT_DATE);

    IF v_indicado IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Campo "indicado_nome" é obrigatório no processo ' || p_processo_id::TEXT);
    END IF;

    PERFORM _validar_dados_evento('bonus_indicacao',
      jsonb_build_object('indicado_nome', v_indicado, 'valor_bonus', v_valor_bonus, 'mes_folha', v_mes_folha));

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id,
      'bonus_indicacao',
      'Bônus de Indicação',
      'Bônus por indicação de ' || v_indicado,
      jsonb_build_object('indicado_nome', v_indicado, 'valor_bonus', v_valor_bonus, 'mes_folha', v_mes_folha),
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de bônus de indicação recuperado. Indicado: ' || v_indicado,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de bônus de indicação recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras      := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_indicado    := NULLIF(TRIM(v_extras->>'indicado_nome'), '');
  v_valor_bonus := NULLIF(TRIM(v_extras->>'valor_bonus'), '')::NUMERIC;
  v_mes_folha   := NULLIF(TRIM(v_extras->>'mes_folha'), '');
  v_data_evento := COALESCE(v_proc.concluido_em::DATE, CURRENT_DATE);

  IF v_indicado IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Campo "indicado_nome" é obrigatório em dados_extras');
  END IF;

  PERFORM _validar_dados_evento('bonus_indicacao',
    jsonb_build_object('indicado_nome', v_indicado, 'valor_bonus', v_valor_bonus, 'mes_folha', v_mes_folha));

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
    'bonus_indicacao',
    'Bônus de Indicação',
    'Bônus por indicação de ' || v_indicado,
    jsonb_build_object('indicado_nome', v_indicado, 'valor_bonus', v_valor_bonus, 'mes_folha', v_mes_folha),
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Bônus de indicação registrado. Indicado: ' || v_indicado ||
          CASE WHEN v_mes_folha IS NOT NULL THEN '. Mês folha: ' || v_mes_folha ELSE '' END,
          p_usuario, auth.uid());

  RETURN jsonb_build_object(
    'ok', true,
    'indicado_nome', v_indicado,
    'valor_bonus',   v_valor_bonus,
    'mes_folha',     v_mes_folha
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
