-- Migration 088 — Recuperação de eventos: admissao e demissao
-- Chama fn_concluir_admissao e fn_concluir_demissao para todos os processos
-- já concluídos que ainda não possuem evento em historico_eventos.
-- Idempotente: pode ser re-executado sem duplicar eventos.
-- Execute APÓS as migrations 085, 086 e 087.
--
-- Processos com colaborador_id IS NULL são pulados (candidatos não contratados).

DO $$
DECLARE
  v_proc    RECORD;
  v_res     JSONB;
  v_ok      INTEGER := 0;
  v_recup   INTEGER := 0;
  v_erro    INTEGER := 0;
  v_pulado  INTEGER := 0;
BEGIN

  -- ── Admissão ─────────────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de admissão ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'admissao'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_admissao(v_proc.id, 'Migração Fase 2');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  admissao proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  admissao proc %: OK (cargo: %)', v_proc.id, v_res->>'cargo';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  admissao proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  -- Conta processos de admissão sem colaborador (dados legados inválidos)
  SELECT COUNT(*) INTO v_pulado
  FROM processos_rh
  WHERE tipo = 'admissao'
    AND status = 'concluido'
    AND colaborador_id IS NULL;

  IF v_pulado > 0 THEN
    RAISE NOTICE '  admissao: % processo(s) sem colaborador vinculado — pulados', v_pulado;
  END IF;

  -- ── Demissão ─────────────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de demissão ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'demissao'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_demissao(v_proc.id, 'Migração Fase 2');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  demissao proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  demissao proc %: OK', v_proc.id;
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  demissao proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  RAISE NOTICE '=== Resultado: % eventos criados, % já existiam, % pulados (sem colaborador), % erros ===',
    v_ok, v_recup, v_pulado, v_erro;

  IF v_erro > 0 THEN
    RAISE EXCEPTION 'Recuperação concluída com % erro(s). Verifique os avisos acima antes de prosseguir.', v_erro;
  END IF;

END;
$$;
