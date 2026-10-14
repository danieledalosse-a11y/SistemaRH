-- 115_dp_fn_historico_criterio_resposta_texto.sql
-- Adiciona resposta_texto ao retorno de dp_fn_historico_criterio.
-- Necessário para que critérios binários mostrem Sim/Não no histórico do formulário de avaliação.
-- Mesma assinatura e lógica; apenas o jsonb_build_object é estendido.

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
    AND a.status          = 'publicada'
    AND (p_escala_id IS NULL OR vc.escala_id = p_escala_id)
    AND vc.tipo_resposta  = p_tipo_resposta
  ORDER BY c.encerrado_em DESC
  LIMIT 1;

  IF v_resultado IS NULL THEN
    RETURN jsonb_build_object('comparavel', false);
  END IF;

  RETURN v_resultado;
END;
$$;
