-- Migration 101 — Recuperação de eventos: Fase D (entrega_uniforme)
-- Chama fn_registrar_entrega_uniforme para cada grupo distinto de
-- (colaborador_id, data_movimentacao, motivo) em unif_movimentacoes,
-- filtrando apenas itens do catálogo com tipo='uniforme'.
--
-- Idempotente: a função verifica EXISTS antes de inserir —
-- grupos já registrados retornam ok=true + aviso e são contados como v_pulado.
--
-- Estado esperado antes da execução:
--   6 grupos distintos em unif_movimentacoes (todos motivo='admissao')
--   1 já tem evento (colab 2280, data 2026-09-23) → será pulado
--   5 pendentes → serão criados
--
-- Não altera unif_movimentacoes em nenhuma hipótese.

DO $$
DECLARE
  v_grupo   RECORD;
  v_res     JSONB;
  v_ok      INTEGER := 0;
  v_pulado  INTEGER := 0;
  v_erro    INTEGER := 0;
BEGIN

  RAISE NOTICE '=== Recuperando eventos de entrega_uniforme ===';

  FOR v_grupo IN
    SELECT DISTINCT
      m.colaborador_id,
      m.data_movimentacao,
      m.motivo
    FROM unif_movimentacoes m
    JOIN unif_catalogo c ON c.id = m.item_id
    WHERE m.colaborador_id IS NOT NULL
      AND c.tipo = 'uniforme'
    ORDER BY m.colaborador_id, m.data_movimentacao
  LOOP
    v_res := fn_registrar_entrega_uniforme(
      v_grupo.colaborador_id,
      v_grupo.data_movimentacao,
      v_grupo.motivo,
      'Migração D'
    );

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_pulado := v_pulado + 1;
        RAISE NOTICE '  colab=% data=% motivo=%: já registrado (pulado)',
          v_grupo.colaborador_id, v_grupo.data_movimentacao, v_grupo.motivo;
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  colab=% data=% motivo=%: OK (% iten(s))',
          v_grupo.colaborador_id, v_grupo.data_movimentacao, v_grupo.motivo,
          v_res->>'total_itens';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  colab=% data=% motivo=%: ERRO — %',
        v_grupo.colaborador_id, v_grupo.data_movimentacao, v_grupo.motivo,
        v_res->>'erro';
    END IF;
  END LOOP;

  RAISE NOTICE '=== Resultado: % evento(s) criado(s), % pulado(s), % erro(s) ===',
    v_ok, v_pulado, v_erro;

  IF v_erro > 0 THEN
    RAISE EXCEPTION 'Recuperação Fase D concluída com % erro(s). Verifique os avisos acima.', v_erro;
  END IF;

END;
$$;
