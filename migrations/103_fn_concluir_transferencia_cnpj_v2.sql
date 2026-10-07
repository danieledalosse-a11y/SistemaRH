-- Migration 103 — fn_concluir_transferencia_cnpj v2
-- Parametriza tipo_transferencia usando param_tipo_transferencia (Mig 102).
--
-- O que muda em relação à v1 (Migration 092):
--   1. Busca o label de param_tipo_transferencia após extrair o codigo.
--   2. Fallback: se o codigo não existir na tabela (valor legado ou NULL),
--      usa o próprio codigo como label — sem quebrar processos antigos.
--   3. historico_eventos.dados passa a incluir tipo_transferencia_label
--      como snapshot imutável do label na época do registro.
--
-- O comportamento externo (retorno JSON, atualização de processo, auditoria)
-- é idêntico à v1. Eventos já registrados NÃO são alterados.

CREATE OR REPLACE FUNCTION fn_concluir_transferencia_cnpj(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc                    processos_rh%ROWTYPE;
  v_extras                  JSONB;
  v_empresa_origem          TEXT;
  v_empresa_destino         TEXT;
  v_tipo_transferencia      TEXT;
  v_tipo_transferencia_label TEXT;   -- ← novo: snapshot do label na época
  v_data_evento             DATE;
  v_dados_evento            JSONB;
  v_titulo_evento           TEXT;
  v_resumo_evento           TEXT;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'transferencia_cnpj' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo transferencia_cnpj');
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
    v_extras             := COALESCE(v_proc.dados_extras, '{}'::JSONB);
    v_empresa_origem     := NULLIF(TRIM(v_extras->>'empresa_origem'), '');
    v_empresa_destino    := NULLIF(TRIM(v_extras->>'empresa_destino'), '');
    v_tipo_transferencia := NULLIF(TRIM(v_extras->>'tipo_transferencia'), '');
    v_data_evento        := COALESCE(
      NULLIF(TRIM(v_extras->>'data_transferencia'), '')::DATE,
      v_proc.concluido_em::DATE
    );

    -- Buscar label parametrizado (fallback: usa o próprio codigo)
    SELECT label INTO v_tipo_transferencia_label
    FROM param_tipo_transferencia
    WHERE codigo = v_tipo_transferencia AND ativo = TRUE;
    IF NOT FOUND THEN
      v_tipo_transferencia_label := COALESCE(v_tipo_transferencia, '');
    END IF;

    IF v_empresa_origem IS NULL OR v_empresa_destino IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Campos "empresa_origem" e "empresa_destino" são obrigatórios no processo ' || p_processo_id::TEXT);
    END IF;

    IF v_data_evento IS NULL THEN
      RETURN jsonb_build_object('ok', false, 'erro',
        'Não foi possível determinar a data da transferência do processo ' || p_processo_id::TEXT);
    END IF;

    v_dados_evento  := jsonb_build_object(
      'empresa_origem',           v_empresa_origem,
      'empresa_destino',          v_empresa_destino,
      'tipo_transferencia',       v_tipo_transferencia,
      'tipo_transferencia_label', v_tipo_transferencia_label
    );
    v_titulo_evento := 'Transferência para ' || v_empresa_destino;
    v_resumo_evento := v_empresa_origem || ' → ' || v_empresa_destino;

    PERFORM _validar_dados_evento('transferencia', v_dados_evento);

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_proc.colaborador_id, 'transferencia', v_titulo_evento, v_resumo_evento, v_dados_evento,
      v_data_evento, p_usuario, auth.uid(),
      NULL, NULL, p_processo_id, 'sistema'
    );

    INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
    VALUES (p_processo_id, 'concluido',
            'Evento de transferência recuperado. Data: ' || v_data_evento::TEXT,
            p_usuario, auth.uid());

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de transferência recuperado');
  END IF;

  -- ── ETAPA 2: Conclusão normal (processo aberto) ──────────────────────────
  v_extras             := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_empresa_origem     := NULLIF(TRIM(v_extras->>'empresa_origem'), '');
  v_empresa_destino    := NULLIF(TRIM(v_extras->>'empresa_destino'), '');
  v_tipo_transferencia := NULLIF(TRIM(v_extras->>'tipo_transferencia'), '');
  v_data_evento        := COALESCE(
    NULLIF(TRIM(v_extras->>'data_transferencia'), '')::DATE,
    CURRENT_DATE
  );

  -- Buscar label parametrizado (fallback: usa o próprio codigo)
  SELECT label INTO v_tipo_transferencia_label
  FROM param_tipo_transferencia
  WHERE codigo = v_tipo_transferencia AND ativo = TRUE;
  IF NOT FOUND THEN
    v_tipo_transferencia_label := COALESCE(v_tipo_transferencia, '');
  END IF;

  IF v_empresa_origem IS NULL OR v_empresa_destino IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro',
      'Campos "empresa_origem" e "empresa_destino" são obrigatórios em dados_extras');
  END IF;

  v_dados_evento  := jsonb_build_object(
    'empresa_origem',           v_empresa_origem,
    'empresa_destino',          v_empresa_destino,
    'tipo_transferencia',       v_tipo_transferencia,
    'tipo_transferencia_label', v_tipo_transferencia_label
  );
  v_titulo_evento := 'Transferência para ' || v_empresa_destino;
  v_resumo_evento := v_empresa_origem || ' → ' || v_empresa_destino;

  PERFORM _validar_dados_evento('transferencia', v_dados_evento);

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
    v_proc.colaborador_id, 'transferencia', v_titulo_evento, v_resumo_evento, v_dados_evento,
    v_data_evento, p_usuario, auth.uid(),
    NULL, NULL, p_processo_id, 'sistema'
  );

  -- ── ETAPA 5: Registrar auditoria ─────────────────────────────────────────
  INSERT INTO processo_auditoria (processo_id, acao, detalhe, usuario, usuario_id)
  VALUES (p_processo_id, 'concluido',
          'Transferência registrada. ' || v_empresa_origem || ' → ' || v_empresa_destino ||
          '. Data: ' || v_data_evento::TEXT,
          p_usuario, auth.uid());

  RETURN jsonb_build_object(
    'ok', true,
    'empresa_origem',  v_empresa_origem,
    'empresa_destino', v_empresa_destino,
    'data_transferencia', TO_CHAR(v_data_evento, 'DD/MM/YYYY')
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
