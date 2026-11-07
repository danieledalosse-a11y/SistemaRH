-- Migration 144: dp_fn_historico_criterio_batch — SECURITY DEFINER + verificação de acesso por perfil
--
-- Problema: com SECURITY INVOKER (padrão atual), a função executa com as permissões
--   do chamador. Para o Gestor, o plano de execução do JOIN de 6 tabelas em
--   dp_fn_historico_criterio avalia simultaneamente as políticas de RLS do Gestor,
--   que contêm dependências cruzadas (dp_ciclos → dp_ciclo_participantes → dp_ciclos
--   via auth_avaliador_ciclo_ids), causando erro de recursão/profundidade de pilha.
--   Resultado: sbRpc retorna null → "Histórico indisponível" para todos os critérios
--   na visão do Gestor, enquanto RH funciona normalmente.
--
-- Solução: SECURITY DEFINER na função batch — executa com as permissões do owner,
--   eliminando a avaliação das políticas RLS no plano interno. Para preservar as
--   restrições de acesso por perfil, a função verifica inline quem está chamando:
--
--   - rh / admin / diretoria  → acesso completo (comportamento igual ao de antes para RH)
--   - gestor                  → somente se p_colaborador_id ∈ auth_gestor_equipe_ids()
--                               — mesma função já usada pelo RLS do Gestor em todo o módulo
--   - qualquer outro perfil   → retorna TABLE vazia silenciosamente (sem erro, sem dados)
--
-- A função interna dp_fn_historico_criterio NÃO é alterada:
--   ao ser chamada por uma função SECURITY DEFINER ela já roda com as permissões
--   do owner, tornando desnecessária uma alteração na interna.
--
-- search_path fixo em 'public' previne search_path injection (padrão obrigatório
--   para SECURITY DEFINER no Supabase — igual a auth_gestor_equipe_ids e
--   auth_avaliador_ciclo_ids nas migrations 113 e 117).
--
-- DROP explícito necessário: CREATE OR REPLACE não pode mudar a cláusula SECURITY
--   de uma função existente no PostgreSQL.

DROP FUNCTION IF EXISTS public.dp_fn_historico_criterio_batch(uuid, integer, uuid);

CREATE OR REPLACE FUNCTION dp_fn_historico_criterio_batch(
  p_versao_id      uuid,
  p_colaborador_id integer,
  p_ciclo_atual_id uuid
)
RETURNS TABLE(versao_criterio_id uuid, resultado jsonb)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_perfil TEXT;
  v_vc     RECORD;
BEGIN
  -- ── Verificação de acesso ──────────────────────────────────────────────────
  -- auth_perfil() e auth_gestor_equipe_ids() são SECURITY DEFINER e estão
  -- definidas no mesmo schema (public). Chamá-las aqui é seguro e consistente
  -- com as políticas de RLS do módulo D&P.
  v_perfil := auth_perfil();

  IF v_perfil IN ('rh', 'admin', 'diretoria') THEN
    -- Acesso completo — comportamento idêntico ao atual para RH
    NULL;
  ELSIF v_perfil = 'gestor' THEN
    -- Gestor só pode consultar histórico dos colaboradores da sua equipe.
    -- Usa a mesma função auth_gestor_equipe_ids() já utilizada pelo RLS em:
    --   dp_ciclo_participantes_gestor_sel, dp_avaliacoes_gestor_sel,
    --   dp_respostas_gestor_sel, dp_resultados_gestor_sel (migration 113).
    IF p_colaborador_id != ALL(SELECT auth_gestor_equipe_ids()) THEN
      RETURN; -- colaborador fora da equipe: retorna TABLE vazia, sem erro
    END IF;
  ELSE
    -- Perfil não reconhecido: retorna TABLE vazia silenciosamente
    RETURN;
  END IF;

  -- ── Loop principal (inalterado em relação à migration 143) ─────────────────
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

-- Permissões: mantém o GRANT existente (migrations 128 e 143)
GRANT EXECUTE ON FUNCTION dp_fn_historico_criterio_batch(uuid, integer, uuid)
  TO authenticated;
