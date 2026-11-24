-- Migration 108-B — fn_registrar_entrega_uniforme v2
-- Único ajuste: filtra operacao_id IS NULL no FOR loop para não agregar registros
-- vindos do novo RPC (que já criam seu próprio evento em historico_eventos).

CREATE OR REPLACE FUNCTION fn_registrar_entrega_uniforme(
  p_colaborador_id  BIGINT,
  p_data            DATE,
  p_motivo          TEXT,
  p_usuario         TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_itens       JSONB   := '[]'::JSONB;
  v_total_itens INTEGER := 0;
  v_resumo      TEXT;
  v_linha       RECORD;
BEGIN

  -- ── 1. Idempotência ──────────────────────────────────────────────────────────
  IF EXISTS (
    SELECT 1
    FROM historico_eventos
    WHERE colaborador_id = p_colaborador_id
      AND tipo           = 'entrega_uniforme'
      AND data_evento    = p_data
      AND dados->>'motivo' = p_motivo
  ) THEN
    RETURN jsonb_build_object(
      'ok',    true,
      'aviso', 'Evento de entrega_uniforme já registrado para este colaborador, data e motivo'
    );
  END IF;

  -- ── 2. Agrega linhas históricas (sem operacao_id = geradas antes do RPC) ─────
  FOR v_linha IN
    SELECT
      c.nome,
      c.variante,
      m.tamanho,
      m.quantidade
    FROM unif_movimentacoes m
    JOIN unif_catalogo c ON c.id = m.item_id
    WHERE m.colaborador_id    = p_colaborador_id
      AND m.data_movimentacao = p_data
      AND m.motivo            = p_motivo
      AND c.tipo              = 'uniforme'
      AND m.operacao_id IS NULL   -- exclui registros do novo RPC (já criam evento próprio)
    ORDER BY c.nome, m.tamanho
  LOOP
    v_itens := v_itens || jsonb_build_object(
      'nome',       v_linha.nome,
      'variante',   v_linha.variante,
      'tamanho',    v_linha.tamanho,
      'quantidade', v_linha.quantidade
    );
    v_total_itens := v_total_itens + 1;
  END LOOP;

  -- ── 3. Valida que encontrou ao menos um item ─────────────────────────────────
  IF v_total_itens = 0 THEN
    RETURN jsonb_build_object(
      'ok',   false,
      'erro', format(
        'Nenhuma movimentação de uniforme encontrada para colaborador %s, data %s, motivo %s',
        p_colaborador_id, p_data, p_motivo
      )
    );
  END IF;

  -- ── 4. Monta resumo ──────────────────────────────────────────────────────────
  IF v_total_itens = 1 THEN
    v_resumo := '1 item — ' || p_motivo;
  ELSE
    v_resumo := v_total_itens::TEXT || ' itens — ' || p_motivo;
  END IF;

  -- ── 5. Insere evento ─────────────────────────────────────────────────────────
  INSERT INTO historico_eventos (
    colaborador_id,
    tipo,
    titulo,
    resumo,
    data_evento,
    dados,
    registrado_por
  ) VALUES (
    p_colaborador_id,
    'entrega_uniforme',
    'Entrega de Uniforme',
    v_resumo,
    p_data,
    jsonb_build_object(
      'motivo',      p_motivo,
      'total_itens', v_total_itens,
      'itens',       v_itens
    ),
    p_usuario
  );

  RETURN jsonb_build_object(
    'ok',          true,
    'total_itens', v_total_itens,
    'motivo',      p_motivo,
    'data_evento', p_data::TEXT
  );

END;
$$;
