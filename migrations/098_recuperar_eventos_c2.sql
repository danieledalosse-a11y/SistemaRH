-- Migration 098 — Recuperação de eventos: Parte C-2
-- Chama fn_concluir_bonus_indicacao, fn_concluir_vt_alteracao e
-- fn_concluir_devolucao_uniforme para todos os processos já concluídos
-- que ainda não possuem evento em historico_eventos.
-- Idempotente: pode ser re-executado sem duplicar eventos.
-- Execute APÓS as migrations 095, 096 e 097.
--
-- Processos sem colaborador_id (vt criados durante admissão) são recusados
-- pelas próprias funções — retornam ok=false sem criar evento.
--
-- Estado esperado antes da execução (out/2026):
--   bonus_indicacao concluídos com colab: 5 (proc 23 já tem evento — será pulado)
--   vt_alteracao concluídos com colab: 2 (proc 38 já tem evento — será pulado)
--   devolucao_uniforme concluídos com colab: 1 (proc 13 já tem evento — será pulado)
--   Eventos a criar: 5 (bonus: 24,25,26,47 + vt: 17)

DO $$
DECLARE
  v_proc   RECORD;
  v_res    JSONB;
  v_ok     INTEGER := 0;
  v_recup  INTEGER := 0;
  v_pulado INTEGER := 0;
  v_erro   INTEGER := 0;
BEGIN

  -- ── bonus_indicacao ────────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de bônus de indicação ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'bonus_indicacao'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_bonus_indicacao(v_proc.id, 'Migração C-2');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  bonus proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  bonus proc %: OK (indicado: %)', v_proc.id, v_res->>'indicado_nome';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  bonus proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  -- ── vt_alteracao ───────────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de VT ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'vt_alteracao'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_vt_alteracao(v_proc.id, 'Migração C-2');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  vt proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  vt proc %: OK (operacao: %, linha: %)',
          v_proc.id, v_res->>'operacao', v_res->>'vt_linha';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  vt proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  -- ── devolucao_uniforme ─────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de devolução de uniforme ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'devolucao_uniforme'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_devolucao_uniforme(v_proc.id, 'Migração C-2');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  uniforme proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  uniforme proc %: OK (qtd: %)', v_proc.id, v_res->>'qtd_itens';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  uniforme proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  RAISE NOTICE '=== Resultado: % eventos criados, % já existiam, % pulados, % erros ===',
    v_ok, v_recup, v_pulado, v_erro;

  IF v_erro > 0 THEN
    RAISE EXCEPTION 'Recuperação C-2 concluída com % erro(s). Verifique os avisos acima antes de prosseguir.', v_erro;
  END IF;

END;
$$;
