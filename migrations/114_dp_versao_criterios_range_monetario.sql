-- 114_dp_versao_criterios_range_monetario.sql
-- Fase 3: range configurável para critérios numéricos (nota_min, nota_max)
-- Fase 4: valor monetário para critérios Sim/Não (valor_se_sim, valor_se_nao)
-- Opção B: tabela separada dp_resultados_bonus com RLS rh/admin/diretoria
-- Correção: constraint escala_obrigatoria e função dp_validar_versao Regra 3
-- Semântica: DROP constraint resultado_tem_valor (permite avaliações puramente monetárias)
--
-- IMPORTANTE: Executar somente após autorização explícita do RH.
-- Todas as novas colunas são nullable → comportamento atual preservado.
-- Nenhum UPDATE, DELETE ou TRUNCATE em nenhum bloco.
-- Todos os ALTER TABLE usam IF NOT EXISTS; CREATE POLICY usa guarda IF NOT EXISTS.
-- Resultados históricos não são afetados.

-- ============================================================
-- 1. Novas colunas em dp_versao_criterios
--    Todas nullable: linhas existentes recebem NULL, sem recálculo.
-- ============================================================

ALTER TABLE dp_versao_criterios
  ADD COLUMN IF NOT EXISTS nota_min      NUMERIC,
  ADD COLUMN IF NOT EXISTS nota_max      NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_sim  NUMERIC,
  ADD COLUMN IF NOT EXISTS valor_se_nao  NUMERIC DEFAULT 0;

COMMENT ON COLUMN dp_versao_criterios.nota_min     IS 'Valor mínimo de referência para critérios numéricos (orientação visual — não bloqueia o envio por padrão)';
COMMENT ON COLUMN dp_versao_criterios.nota_max     IS 'Valor máximo de referência para critérios numéricos (orientação visual — não bloqueia o envio por padrão)';
COMMENT ON COLUMN dp_versao_criterios.valor_se_sim IS 'Valor monetário atribuído quando resposta binária = sim';
COMMENT ON COLUMN dp_versao_criterios.valor_se_nao IS 'Valor monetário atribuído quando resposta binária = não (padrão: 0)';

-- ============================================================
-- 2. Corrigir constraint escala_obrigatoria em dp_versao_criterios
--    Antes (migration 065): tipo_resposta NOT IN ('binario','escala') OR escala_id IS NOT NULL
--    → exigia escala_id tanto para 'escala' quanto para 'binario'
--    Depois: apenas tipo_resposta = 'escala' exige escala_id
--    → critérios binários com valor_se_sim não precisam de escala
--    Linhas existentes: satisfazem a nova regra (binários existentes têm escala_id=NULL e agora estão corretos)
-- ============================================================

ALTER TABLE dp_versao_criterios
  DROP CONSTRAINT IF EXISTS escala_obrigatoria;

ALTER TABLE dp_versao_criterios
  ADD CONSTRAINT escala_obrigatoria CHECK (
    tipo_resposta != 'escala' OR escala_id IS NOT NULL
  );

-- ============================================================
-- 3. Atualizar dp_validar_versao — apenas Regra 3 modificada
--    Regras 1, 2, 4, 5a, 5b: idênticas à migration 068.
--    Regra 3 antes: tipo_resposta IN ('binario','escala') exigia valor_numerico nas opções
--    Regra 3 depois: apenas tipo_resposta = 'escala' exige valor_numerico nas opções
--    (critérios binários com valor_se_sim usam campos da própria dp_versao_criterios)
-- ============================================================

CREATE OR REPLACE FUNCTION dp_validar_versao(p_versao_id UUID)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_versao         dp_versoes%ROWTYPE;
  v_erros          JSONB    := '[]'::JSONB;
  v_calculaveis    INTEGER;
  v_escala_inv     INTEGER;
  v_incompativeis  INTEGER;
  v_sem_peso       INTEGER;
BEGIN
  SELECT * INTO v_versao FROM dp_versoes WHERE id = p_versao_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('erro', 'Versao nao encontrada');
  END IF;

  -- Regra 1: modelo nao-qualitativo precisa de ao menos um criterio calculavel
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(*) INTO v_calculaveis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true;
    IF v_calculaveis = 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 1, 'mensagem', 'Nenhum criterio configurado como contribuinte para o calculo.');
    END IF;
  END IF;

  -- Regra 2: converte_para_conceito exige tabela_conceito_id preenchido
  IF v_versao.converte_para_conceito AND v_versao.tabela_conceito_id IS NULL THEN
    v_erros := v_erros || jsonb_build_object('regra', 2, 'mensagem', 'Conversao para conceito ativada sem tabela de conceito selecionada.');
  END IF;

  -- Regra 3: critérios calculáveis do tipo ESCALA precisam de valor_numerico em todas as opções
  --          Critérios BINÁRIOS com valor_se_sim usam campos próprios — não exigem escala_id
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(DISTINCT vc.id) INTO v_escala_inv
    FROM dp_versao_criterios vc
    JOIN dp_escala_opcoes eo ON eo.escala_id = vc.escala_id
    WHERE vc.versao_id = p_versao_id
      AND vc.tipo_resposta = 'escala'
      AND vc.contribui_calculo = true
      AND eo.valor_numerico IS NULL;
    IF v_escala_inv > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 3, 'mensagem', format('%s criterio(s) calculavel(eis) com opcoes de escala sem valor_numerico.', v_escala_inv));
    END IF;
  END IF;

  -- Regra 4: media_ponderada exige peso > 0 em todos os criterios calculaveis
  IF v_versao.tipo_calculo = 'media_ponderada' THEN
    SELECT COUNT(*) INTO v_sem_peso
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true AND (peso IS NULL OR peso <= 0);
    IF v_sem_peso > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', 4, 'mensagem', format('%s criterio(s) calculavel(eis) sem peso definido para media ponderada.', v_sem_peso));
    END IF;
  END IF;

  -- Regra 5a: percentual_atingimento exige numerico_com_meta em todos os calculaveis
  IF v_versao.tipo_calculo = 'percentual_atingimento' THEN
    SELECT COUNT(*) INTO v_incompativeis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true AND tipo_resposta != 'numerico_com_meta';
    IF v_incompativeis > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', '5a', 'mensagem', format('Percentual de atingimento exige tipo numerico com meta em todos os criterios calculaveis (%s incompativel(eis)).', v_incompativeis));
    END IF;
  END IF;

  -- Regra 5b: qualitativo nao admite contribui_calculo = true
  IF v_versao.tipo_calculo = 'qualitativo' THEN
    SELECT COUNT(*) INTO v_incompativeis
    FROM dp_versao_criterios
    WHERE versao_id = p_versao_id AND contribui_calculo = true;
    IF v_incompativeis > 0 THEN
      v_erros := v_erros || jsonb_build_object('regra', '5b', 'mensagem', format('Tipo qualitativo nao admite criterios contribuintes para calculo (%s encontrado(s)).', v_incompativeis));
    END IF;
  END IF;

  RETURN jsonb_build_object('erros', v_erros, 'valida', jsonb_array_length(v_erros) = 0);
END;
$$;

-- ============================================================
-- 4. Tabela dp_resultados_bonus
--    Armazena o bônus financeiro de critérios binários Sim/Não separado
--    de dp_resultados, garantindo que gestores não acessem via API.
--    snapshot_criterios: rastreabilidade dos valores vigentes no cálculo.
-- ============================================================

CREATE TABLE IF NOT EXISTS dp_resultados_bonus (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  resultado_id        UUID        NOT NULL UNIQUE REFERENCES dp_resultados(id) ON DELETE CASCADE,
  valor_bonus         NUMERIC     NOT NULL CHECK (valor_bonus >= 0),
  snapshot_criterios  JSONB,
  calculado_em        TIMESTAMPTZ NOT NULL DEFAULT now(),
  calculado_por       UUID        REFERENCES auth.users(id)
);

COMMENT ON TABLE  dp_resultados_bonus                       IS 'Resultado financeiro de critérios binários Sim/Não (Opção B). Separado de dp_resultados para controle de acesso: gestor e colaborador não acessam.';
COMMENT ON COLUMN dp_resultados_bonus.valor_bonus           IS 'Soma dos valores monetários das respostas válidas (sim/não) com valor_se_sim ou valor_se_nao configurado.';
COMMENT ON COLUMN dp_resultados_bonus.snapshot_criterios    IS 'Snapshot dos critérios e valores vigentes no momento do cálculo. Imutável após criação — preserva rastreabilidade se a parametrização for alterada depois.';
COMMENT ON COLUMN dp_resultados_bonus.resultado_id          IS 'FK para dp_resultados — resultado base da avaliação. Exclusão em cascata.';

-- ============================================================
-- 5. RLS em dp_resultados_bonus
--    SELECT: rh, admin, diretoria.
--    INSERT/UPDATE/DELETE: rh, admin.
--    Gestor e colaborador: sem política = negado pelo RLS (retorna array vazio, não erro).
-- ============================================================

ALTER TABLE dp_resultados_bonus ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados_bonus' AND policyname='dp_resultados_bonus_sel') THEN
    CREATE POLICY dp_resultados_bonus_sel ON dp_resultados_bonus
      FOR SELECT TO authenticated
      USING (auth_perfil() IN ('admin','rh','diretoria'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados_bonus' AND policyname='dp_resultados_bonus_ins') THEN
    CREATE POLICY dp_resultados_bonus_ins ON dp_resultados_bonus
      FOR INSERT TO authenticated
      WITH CHECK (auth_perfil() IN ('admin','rh'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados_bonus' AND policyname='dp_resultados_bonus_upd') THEN
    CREATE POLICY dp_resultados_bonus_upd ON dp_resultados_bonus
      FOR UPDATE TO authenticated
      USING  (auth_perfil() IN ('admin','rh'))
      WITH CHECK (auth_perfil() IN ('admin','rh'));
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public'
    AND tablename='dp_resultados_bonus' AND policyname='dp_resultados_bonus_del') THEN
    CREATE POLICY dp_resultados_bonus_del ON dp_resultados_bonus
      FOR DELETE TO authenticated
      USING (auth_perfil() IN ('admin','rh'));
  END IF;
END $$;

-- ============================================================
-- 5b. Remover constraint resultado_tem_valor de dp_resultados
--     Antes: CHECK (nota_final IS NOT NULL OR conceito IS NOT NULL)
--     Problema: impede avaliações exclusivamente monetárias
--     (nota_final=NULL e conceito=NULL são válidos quando só há critérios binários)
--
--     Proteção equivalente mantida por:
--     a) Guard no frontend: dpCalcularAvaliacao retorna cedo se nota=null
--        AND conceito=null AND bonusTotal=null — nunca cria linha vazia
--     b) UNIQUE em dp_resultados(avaliacao_id) impede linhas duplicadas
--     c) Futura função RPC transacional (proposta abaixo) centralizará
--        a validação no banco
--
--     Dados históricos: sem impacto — todas as linhas existentes têm
--     nota_final ou conceito preenchidos e continuam válidas.
-- ============================================================

ALTER TABLE dp_resultados
  DROP CONSTRAINT IF EXISTS resultado_tem_valor;

-- ============================================================
-- 6. Estender ENUM dp_evento_historico com novo valor resultado_recalculado
--    Necessário para a função dp_salvar_resultado registrar histórico de recálculo.
--    ADD VALUE IF NOT EXISTS: idempotente — não falha se já existir.
-- ============================================================

ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'resultado_recalculado';

-- ============================================================
-- 7. Função RPC transacional dp_salvar_resultado
--    Centraliza o salvamento de dp_resultados + dp_resultados_bonus em uma única
--    transação: ou ambos persistem, ou nenhum (rollback automático).
--    SECURITY DEFINER + SET search_path = public: previne search_path injection.
--    O controle de acesso (perfil rh/admin) está dentro da função —
--    não depende de RLS nem de verificação no frontend.
--    dp_historico_eventos é append-only (sem UPDATE/DELETE policies na migration 112)
--    portanto o snapshot de recálculo não pode ser alterado após registro.
-- ============================================================

CREATE OR REPLACE FUNCTION dp_salvar_resultado(
  p_avaliacao_id      UUID,
  p_nota_final        NUMERIC,
  p_conceito          TEXT,
  p_bonus_total       NUMERIC,
  p_snapshot          JSONB,
  p_motivo_recalculo  TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_resultado_id    UUID;
  v_existing_id     UUID;
  v_existing_bonus  RECORD;
  v_perfil          TEXT;
BEGIN
  -- 1. Controle de acesso: apenas rh e admin podem salvar resultados
  v_perfil := auth_perfil();
  IF v_perfil NOT IN ('rh', 'admin') THEN
    RETURN jsonb_build_object('erro', 'Acesso negado. Apenas RH e administrador podem calcular resultados.');
  END IF;

  -- 2. Validação: pelo menos um campo de resultado deve estar presente
  IF p_nota_final IS NULL AND p_conceito IS NULL AND p_bonus_total IS NULL THEN
    RETURN jsonb_build_object('erro', 'Resultado vazio não permitido: nota, conceito e bônus estão ausentes.');
  END IF;

  -- 3. Upsert em dp_resultados (atômico — dentro desta transação)
  SELECT id INTO v_existing_id FROM dp_resultados WHERE avaliacao_id = p_avaliacao_id;
  IF v_existing_id IS NOT NULL THEN
    UPDATE dp_resultados
      SET nota_final    = p_nota_final,
          conceito      = p_conceito,
          calculado_em  = now(),
          calculado_por = auth.uid()
    WHERE id = v_existing_id;
    v_resultado_id := v_existing_id;
  ELSE
    INSERT INTO dp_resultados (avaliacao_id, nota_final, conceito, calculado_em, calculado_por)
      VALUES (p_avaliacao_id, p_nota_final, p_conceito, now(), auth.uid())
    RETURNING id INTO v_resultado_id;
  END IF;

  -- 4. Bônus: apenas se houver valor monetário configurado
  IF p_bonus_total IS NOT NULL THEN
    -- Preservar snapshot anterior antes de sobrescrever (rastreabilidade de recálculo)
    SELECT * INTO v_existing_bonus FROM dp_resultados_bonus WHERE resultado_id = v_resultado_id;
    IF v_existing_bonus.id IS NOT NULL THEN
      -- Registrar histórico do recálculo (snapshot anterior + motivo)
      INSERT INTO dp_historico_eventos (tipo, entidade, entidade_id, detalhe)
        VALUES (
          'resultado_recalculado',
          'dp_resultados_bonus',
          v_existing_bonus.id,
          jsonb_build_object(
            'valor_bonus_anterior',        v_existing_bonus.valor_bonus,
            'snapshot_criterios_anterior', v_existing_bonus.snapshot_criterios,
            'calculado_em_anterior',       v_existing_bonus.calculado_em,
            'motivo_recalculo',            COALESCE(p_motivo_recalculo, 'Recálculo manual'),
            'recalculado_por',             auth.uid()
          )
        );
      -- Atualizar bônus com novo valor e snapshot
      UPDATE dp_resultados_bonus
        SET valor_bonus        = p_bonus_total,
            snapshot_criterios = p_snapshot,
            calculado_em       = now(),
            calculado_por      = auth.uid()
      WHERE id = v_existing_bonus.id;
    ELSE
      INSERT INTO dp_resultados_bonus (resultado_id, valor_bonus, snapshot_criterios, calculado_em, calculado_por)
        VALUES (v_resultado_id, p_bonus_total, p_snapshot, now(), auth.uid());
    END IF;
  END IF;

  RETURN jsonb_build_object('ok', true, 'resultado_id', v_resultado_id);
END;
$$;

-- Permissões de execução da RPC
-- SECURITY DEFINER: a função roda com os privilégios do owner (postgres),
-- não do caller — portanto pode fazer DML em dp_resultados e dp_resultados_bonus
-- mesmo que o caller (authenticated) não tenha permissão direta de INSERT/UPDATE.
-- O controle de acesso está dentro da função (v_perfil check).
-- anon não tem EXECUTE → sem acesso para não-autenticados.
REVOKE EXECUTE ON FUNCTION dp_salvar_resultado(UUID, NUMERIC, TEXT, NUMERIC, JSONB, TEXT) FROM PUBLIC;
GRANT  EXECUTE ON FUNCTION dp_salvar_resultado(UUID, NUMERIC, TEXT, NUMERIC, JSONB, TEXT) TO authenticated;
-- ============================================================
