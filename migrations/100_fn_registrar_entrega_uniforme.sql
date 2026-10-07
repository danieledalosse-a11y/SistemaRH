-- Migration 100 — fn_registrar_entrega_uniforme
-- Fase D: registra um evento de entrega de uniforme em historico_eventos,
-- agregando todas as linhas de unif_movimentacoes para o mesmo
-- (colaborador_id, data_movimentacao, motivo) em um único evento.
--
-- Parâmetros:
--   p_colaborador_id  — ID do colaborador (obrigatório)
--   p_data            — data da movimentação (data_movimentacao das linhas)
--   p_motivo          — motivo da entrega (ex: 'admissao', 'troca', 'saida')
--   p_usuario         — quem está registrando (para registrado_por)
--
-- Retorno JSONB:
--   { ok: true,  total_itens, motivo, data_evento }   — evento criado
--   { ok: true,  aviso, ... }                          — já existia (idempotente)
--   { ok: false, erro }                                — erro de validação

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
  -- Verifica se já existe evento para este (colaborador, tipo, data, motivo)
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

  -- ── 2. Agrega linhas de unif_movimentacoes ───────────────────────────────────
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
