-- Migration 110 — Corrige origem em fn_registrar_movimentacao_uniforme
-- Único ajuste: origem 'uniforme' → 'sistema' no INSERT de historico_eventos.
-- A constraint historico_eventos_origem_check aceita: 'sistema','legado','manual'.

CREATE OR REPLACE FUNCTION fn_registrar_movimentacao_uniforme(
  p_colaborador_id   BIGINT,
  p_almoxarifado_id  UUID,
  p_tipo             TEXT,
  p_motivo           TEXT,
  p_data             DATE,
  p_registrado_por   TEXT,
  p_itens            JSONB,
  p_operacao_id      UUID   DEFAULT NULL,
  p_obs              TEXT   DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_confirmado    BOOLEAN;
  v_almox_tipo    TEXT;
  v_sinal         INTEGER;
  v_tipo_evt_cod  TEXT;
  v_tipo_evt_lbl  TEXT;
  v_tipo_evt_ati  BOOLEAN;
  v_item          JSONB;
  v_item_id       UUID;
  v_tamanho       TEXT;
  v_quantidade    INTEGER;
  v_ca_lote       TEXT;
  v_itens_hist    JSONB    := '[]'::JSONB;
  v_total_itens   INTEGER  := 0;
  v_resumo        TEXT;
BEGIN

  -- ── 1. Valida p_tipo ─────────────────────────────────────────────────────────
  IF p_tipo NOT IN ('entrega', 'devolucao') THEN
    RAISE EXCEPTION 'p_tipo inválido: %. Use ''entrega'' ou ''devolucao''', p_tipo;
  END IF;

  -- ── 2. Deriva confirmado da operação ─────────────────────────────────────────
  v_confirmado := (p_tipo = 'devolucao');

  -- ── 3. Idempotência ──────────────────────────────────────────────────────────
  IF p_operacao_id IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM unif_movimentacoes WHERE operacao_id = p_operacao_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'operação já registrada');
    END IF;
  END IF;

  -- ── 4. Valida p_itens ────────────────────────────────────────────────────────
  IF p_itens IS NULL OR jsonb_array_length(p_itens) = 0 THEN
    RAISE EXCEPTION 'p_itens não pode ser vazio';
  END IF;

  -- ── 5. Detecta tipo do almoxarifado ──────────────────────────────────────────
  SELECT tipo INTO v_almox_tipo FROM unif_almoxarifados WHERE id = p_almoxarifado_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Almoxarifado % não encontrado', p_almoxarifado_id;
  END IF;

  v_sinal := CASE WHEN p_tipo = 'devolucao' THEN 1 ELSE -1 END;

  -- ── 6. Loop sobre itens ───────────────────────────────────────────────────────
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_itens)
  LOOP
    v_item_id    := (v_item->>'item_id')::UUID;
    v_tamanho    := v_item->>'tamanho';
    v_quantidade := (v_item->>'quantidade')::INTEGER;
    v_ca_lote    := v_item->>'ca_numero_lote';

    -- 6a. INSERT movimentação
    INSERT INTO unif_movimentacoes (
      colaborador_id, item_id, almoxarifado_id, tipo, motivo,
      tamanho, quantidade, ca_numero_lote, data_movimentacao,
      confirmado, registrado_por, obs, operacao_id
    ) VALUES (
      p_colaborador_id, v_item_id, p_almoxarifado_id, p_tipo, p_motivo,
      v_tamanho, v_quantidade, v_ca_lote, p_data,
      v_confirmado, p_registrado_por, p_obs, p_operacao_id
    );

    -- 6b. UPDATE estoque (só se confirmado e almoxarifado não é CD)
    IF v_confirmado AND v_almox_tipo IS DISTINCT FROM 'cd' THEN
      UPDATE unif_estoque
        SET quantidade = GREATEST(0, quantidade + v_sinal * v_quantidade)
      WHERE almoxarifado_id = p_almoxarifado_id
        AND item_id         = v_item_id
        AND tamanho         = v_tamanho;
    END IF;

    v_itens_hist  := v_itens_hist || jsonb_build_object(
      'item_id',        v_item_id,
      'tamanho',        v_tamanho,
      'quantidade',     v_quantidade,
      'ca_numero_lote', v_ca_lote
    );
    v_total_itens := v_total_itens + 1;
  END LOOP;

  -- ── 7. Lookup tipos_evento ───────────────────────────────────────────────────
  v_tipo_evt_cod := CASE WHEN p_tipo = 'devolucao' THEN 'devolucao_uniforme' ELSE 'entrega_uniforme' END;

  SELECT label, ativo INTO v_tipo_evt_lbl, v_tipo_evt_ati
  FROM tipos_evento WHERE codigo = v_tipo_evt_cod;

  IF NOT FOUND OR v_tipo_evt_ati = FALSE THEN
    RAISE EXCEPTION 'Tipo de evento % não encontrado ou inativo — rollback total', v_tipo_evt_cod;
  END IF;

  -- ── 8. Monta resumo ──────────────────────────────────────────────────────────
  v_resumo := v_total_itens::TEXT
    || CASE WHEN v_total_itens = 1 THEN ' item' ELSE ' itens' END
    || ' — ' || p_motivo;

  -- ── 9. INSERT historico_eventos ───────────────────────────────────────────────
  INSERT INTO historico_eventos (
    colaborador_id, tipo, titulo, resumo, data_evento, dados,
    registrado_por, registrado_por_id, ref_tabela, origem
  ) VALUES (
    p_colaborador_id,
    v_tipo_evt_cod,
    v_tipo_evt_lbl,
    v_resumo,
    p_data,
    jsonb_build_object(
      'motivo',          p_motivo,
      'total_itens',     v_total_itens,
      'itens',           v_itens_hist,
      'almoxarifado_id', p_almoxarifado_id,
      'confirmado',      v_confirmado,
      'operacao_id',     p_operacao_id
    ),
    p_registrado_por,
    auth.uid(),
    'unif_movimentacoes',
    'sistema'   -- corrigido: era 'uniforme', violava historico_eventos_origem_check
  );

  -- ── 10. INSERT unif_log ───────────────────────────────────────────────────────
  INSERT INTO unif_log (
    acao, tabela, registro_id, snapshot_antes, snapshot_depois, usuario
  ) VALUES (
    p_tipo || '_registrado',
    'unif_movimentacoes',
    p_operacao_id::TEXT,
    NULL,
    jsonb_build_object(
      'colaborador_id',  p_colaborador_id,
      'almoxarifado_id', p_almoxarifado_id,
      'tipo',            p_tipo,
      'motivo',          p_motivo,
      'total_itens',     v_total_itens,
      'confirmado',      v_confirmado
    ),
    p_registrado_por
  );

  RETURN jsonb_build_object(
    'ok',          true,
    'tipo',        p_tipo,
    'motivo',      p_motivo,
    'data',        p_data::TEXT,
    'total_itens', v_total_itens
  );

END;
$$;
