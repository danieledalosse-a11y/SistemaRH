-- Migration 143: corrige dp_fn_historico_criterio e dp_fn_historico_criterio_batch
--
-- Problema 1: dp_fn_historico_criterio filtra apenas a.status = 'publicada',
--   ignorando avaliações com status 'concluida' (que são avaliações encerradas com nota válida).
--   Resultado: nenhum histórico era encontrado para colaboradores cujo ciclo anterior
--   foi encerrado sem passar pelo fluxo de publicação.
--
-- Problema 2: dp_fn_historico_criterio_batch declara p_colaborador_id como BIGINT,
--   mas a função interna dp_fn_historico_criterio espera INTEGER.
--   Com parâmetros nomeados (=>), PostgreSQL não faz cast implícito bigint→integer,
--   gerando erro 42883 em tempo de execução sempre que havia histórico a buscar.
--
-- Solução:
--   1. Ampliar o filtro de status para IN ('concluida', 'publicada')
--   2. Alinhar o tipo de p_colaborador_id da batch para INTEGER

-- ─── Parte 1: corrige dp_fn_historico_criterio ────────────────────────────────
CREATE OR REPLACE FUNCTION dp_fn_historico_criterio(
  p_colaborador_id  INTEGER,
  p_criterio_id     UUID,
  p_ciclo_atual_id  UUID,
  p_modelo_id       UUID,
  p_escala_id       UUID,
  p_tipo_resposta   dp_tipo_resposta
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_build_object(
    'comparavel',           true,
    'ciclo_nome',           c.nome,
    'ciclo_encerrado_em',   c.encerrado_em,
    'escala_opcao_label',   r.snapshot_opcao_label,
    'escala_opcao_valor',   r.snapshot_opcao_valor_num,
    'valor_numerico_livre', r.valor_numerico_livre,
    'meta',                 r.meta,
    'realizado',            r.realizado,
    'conceito_selecionado', r.conceito_selecionado,
    'resposta_texto',       r.resposta_texto,
    'nota_final',           res.nota_final,
    'conceito_resultado',   res.conceito
  )
  INTO v_resultado
  FROM dp_respostas r
  JOIN dp_versao_criterios vc    ON vc.id  = r.versao_criterio_id
  JOIN dp_versoes v              ON v.id   = vc.versao_id
  JOIN dp_avaliacoes a           ON a.id   = r.avaliacao_id
  JOIN dp_ciclo_participantes cp ON cp.id  = a.participante_id
  JOIN dp_ciclos c               ON c.id   = cp.ciclo_id
  LEFT JOIN dp_resultados res    ON res.avaliacao_id = a.id
  WHERE cp.colaborador_id = p_colaborador_id
    AND vc.criterio_id    = p_criterio_id
    AND c.id             != p_ciclo_atual_id
    AND v.modelo_id       = p_modelo_id
    AND a.status          IN ('concluida', 'publicada')
    AND (p_escala_id IS NULL OR vc.escala_id = p_escala_id)
    AND vc.tipo_resposta  = p_tipo_resposta
  ORDER BY c.encerrado_em DESC NULLS LAST, a.concluida_em DESC NULLS LAST
  LIMIT 1;

  IF v_resultado IS NULL THEN
    RETURN jsonb_build_object('comparavel', false);
  END IF;

  RETURN v_resultado;
END;
$$;

-- ─── Parte 2: corrige dp_fn_historico_criterio_batch (bigint → integer) ───────
-- DROP explícito necessário pois CREATE OR REPLACE com assinatura diferente cria overload
DROP FUNCTION IF EXISTS public.dp_fn_historico_criterio_batch(uuid, bigint, uuid);
CREATE OR REPLACE FUNCTION dp_fn_historico_criterio_batch(
  p_versao_id      uuid,
  p_colaborador_id integer,
  p_ciclo_atual_id uuid
)
RETURNS TABLE(versao_criterio_id uuid, resultado jsonb)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_vc RECORD;
BEGIN
  FOR v_vc IN
    SELECT vc.id AS vc_id,
           vc.criterio_id,
           vc.escala_id,
           vc.tipo_resposta,
           v.modelo_id
      FROM dp_versao_criterios vc
      JOIN dp_versoes v ON v.id = vc.versao_id
     WHERE vc.versao_id = p_versao_id
     ORDER BY vc.ordem
  LOOP
    versao_criterio_id := v_vc.vc_id;

    SELECT dp_fn_historico_criterio(
      p_colaborador_id := p_colaborador_id,
      p_criterio_id    := v_vc.criterio_id,
      p_ciclo_atual_id := p_ciclo_atual_id,
      p_modelo_id      := v_vc.modelo_id,
      p_escala_id      := v_vc.escala_id,
      p_tipo_resposta  := v_vc.tipo_resposta
    ) INTO resultado;

    RETURN NEXT;
  END LOOP;
END;
$$;

-- Permissões (mantém as existentes)
GRANT EXECUTE ON FUNCTION dp_fn_historico_criterio(integer, uuid, uuid, uuid, uuid, dp_tipo_resposta)
  TO authenticated;

GRANT EXECUTE ON FUNCTION dp_fn_historico_criterio_batch(uuid, integer, uuid)
  TO authenticated;
