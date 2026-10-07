-- Migration 093 — Recuperação de eventos: Parte C-1
-- Chama fn_concluir_prorrogacao_experiencia, fn_concluir_efetivacao e
-- fn_concluir_transferencia_cnpj para todos os processos já concluídos
-- que ainda não possuem evento em historico_eventos.
-- Idempotente: pode ser re-executado sem duplicar eventos.
-- Execute APÓS as migrations 090, 091 e 092.
--
-- Processos cancelados (avaliacao_final_experiencia proc 21) são pulados
-- pelas próprias funções — retornam ok=false sem criar evento.

DO $$
DECLARE
  v_proc    RECORD;
  v_res     JSONB;
  v_ok      INTEGER := 0;
  v_recup   INTEGER := 0;
  v_pulado  INTEGER := 0;
  v_erro    INTEGER := 0;
BEGIN

  -- ── prorrogacao_experiencia ───────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de prorrogação de experiência ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'prorrogacao_experiencia'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_prorrogacao_experiencia(v_proc.id, 'Migração C-1');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  prorrogacao proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  prorrogacao proc %: OK (fim_45_dias: %)', v_proc.id, v_res->>'fim_45_dias';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  prorrogacao proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  -- ── avaliacao_final_experiencia → efetivacao ──────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de efetivação ===';

  FOR v_proc IN
    SELECT p.id, p.status
    FROM processos_rh p
    WHERE p.tipo = 'avaliacao_final_experiencia'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    -- Processos cancelados são pulados (colaborador não foi efetivado)
    IF v_proc.status = 'cancelado' THEN
      v_pulado := v_pulado + 1;
      RAISE NOTICE '  efetivacao proc %: cancelado — pulado (sem evento)', v_proc.id;
      CONTINUE;
    END IF;

    v_res := fn_concluir_efetivacao(v_proc.id, 'Migração C-1');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  efetivacao proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  efetivacao proc %: OK (fim_experiencia: %)', v_proc.id, v_res->>'fim_experiencia';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  efetivacao proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  -- ── transferencia_cnpj ────────────────────────────────────────────────────
  RAISE NOTICE '=== Recuperando eventos de transferência ===';

  FOR v_proc IN
    SELECT p.id
    FROM processos_rh p
    WHERE p.tipo = 'transferencia_cnpj'
      AND p.status = 'concluido'
      AND p.colaborador_id IS NOT NULL
      AND NOT EXISTS (
        SELECT 1 FROM historico_eventos he WHERE he.processo_id = p.id
      )
    ORDER BY p.id
  LOOP
    v_res := fn_concluir_transferencia_cnpj(v_proc.id, 'Migração C-1');

    IF (v_res->>'ok')::BOOLEAN THEN
      IF v_res ? 'aviso' THEN
        v_recup := v_recup + 1;
        RAISE NOTICE '  transferencia proc %: % (já registrado)', v_proc.id, v_res->>'aviso';
      ELSE
        v_ok := v_ok + 1;
        RAISE NOTICE '  transferencia proc %: OK (% → %)',
          v_proc.id, v_res->>'empresa_origem', v_res->>'empresa_destino';
      END IF;
    ELSE
      v_erro := v_erro + 1;
      RAISE WARNING '  transferencia proc %: ERRO — %', v_proc.id, v_res->>'erro';
    END IF;
  END LOOP;

  RAISE NOTICE '=== Resultado: % eventos criados, % já existiam, % cancelados pulados, % erros ===',
    v_ok, v_recup, v_pulado, v_erro;

  IF v_erro > 0 THEN
    RAISE EXCEPTION 'Recuperação C-1 concluída com % erro(s). Verifique os avisos acima antes de prosseguir.', v_erro;
  END IF;

END;
$$;
