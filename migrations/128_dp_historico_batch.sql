-- Migration 128: dp_fn_historico_criterio_batch
-- Função batch que retorna o histórico de avaliação anterior para TODOS os critérios
-- de uma versão de uma só vez, eliminando as N chamadas paralelas por critério.
--
-- Substitui o padrão:
--   Promise.all(_dpVersaoCritsParaForm.map(vc => sbRpc('dp_fn_historico_criterio', {...})))
--
-- Por uma única chamada:
--   sbRpc('dp_fn_historico_criterio_batch', { p_versao_id, p_colaborador_id, p_ciclo_atual_id })
--
-- IMPORTANTE: Executar APÓS confirmar que migration 115 (dp_fn_historico_criterio) está aplicada.
-- NÃO EXECUTAR sem aprovação explícita da usuária.

CREATE OR REPLACE FUNCTION dp_fn_historico_criterio_batch(
  p_versao_id      uuid,
  p_colaborador_id bigint,
  p_ciclo_atual_id uuid
)
RETURNS TABLE(versao_criterio_id uuid, resultado jsonb)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_vc RECORD;
BEGIN
  -- Itera sobre todos os critérios da versão
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

    -- Reutiliza a lógica da função individual
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

-- Permissões: mesmas da função individual
GRANT EXECUTE ON FUNCTION dp_fn_historico_criterio_batch(uuid, bigint, uuid)
  TO authenticated;
