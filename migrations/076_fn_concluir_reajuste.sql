-- Migration 076 — Função fn_concluir_reajuste
-- Conclui um processo de reajuste salarial de forma atômica.
-- Chamada pelo módulo Processos via POST /rest/v1/rpc/fn_concluir_reajuste
-- Retorna JSONB: { ok, aplicado, data_vigencia, salario_novo, percentual } ou { ok: false, erro }

CREATE OR REPLACE FUNCTION fn_concluir_reajuste(
  p_processo_id   BIGINT,
  p_usuario       TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_proc          processos_rh%ROWTYPE;
  v_colab         colaboradores%ROWTYPE;
  v_extras        JSONB;
  v_data_vigencia DATE;
  v_salario_novo  NUMERIC(12,2);
  v_cargo_novo    TEXT;
  v_motivo_cod    TEXT;
  v_motivo_desc   TEXT;
  v_observacao    TEXT;
  v_sal_anterior  NUMERIC(12,2);
  v_cargo_ant     TEXT;
  v_percentual    NUMERIC(6,2);
  v_ja_existe     BOOLEAN;
  v_aplicar_agora BOOLEAN;
  v_cargo_mudou   BOOLEAN;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
  -- FOR UPDATE trava o registro: evita conclusão simultânea por dois usuários
  SELECT * INTO v_proc
  FROM processos_rh
  WHERE id = p_processo_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não encontrado');
  END IF;

  IF v_proc.tipo <> 'reajuste' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo não é do tipo reajuste');
  END IF;

  IF v_proc.colaborador_id IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo sem colaborador vinculado');
  END IF;

  -- Processo já concluído: retorna sucesso sem repetir operações (idempotência)
  IF v_proc.status = 'concluido' THEN
    RETURN jsonb_build_object('ok', true, 'aviso', 'Processo já estava concluído');
  END IF;

  IF v_proc.status = 'cancelado' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo cancelado não pode ser concluído');
  END IF;

  -- ── ETAPA 2: Extrair e validar campos de dados_extras ───────────────────
  v_extras        := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_data_vigencia := (v_extras->>'data_vigencia')::DATE;
  v_salario_novo  := REPLACE(REPLACE(v_extras->>'salario_novo', '.', ''), ',', '.')::NUMERIC;
  v_cargo_novo    := NULLIF(TRIM(v_extras->>'nova_funcao'), '');
  v_motivo_cod    := v_extras->>'motivo_codigo';
  v_motivo_desc   := v_extras->>'motivo_descricao';
  v_observacao    := NULLIF(TRIM(COALESCE(v_extras->>'observacao', '')), '');

  IF v_data_vigencia IS NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'data_vigencia ausente em dados_extras');
  END IF;

  IF v_salario_novo IS NULL OR v_salario_novo <= 0 THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'salario_novo ausente ou inválido em dados_extras');
  END IF;

  -- ── ETAPA 3: Carregar colaborador — captura estado REAL agora ───────────
  -- FOR UPDATE garante que outro processo não altere o colaborador ao mesmo tempo
  SELECT * INTO v_colab
  FROM colaboradores
  WHERE id = v_proc.colaborador_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador não encontrado');
  END IF;

  -- Bloqueia reajuste em colaborador inativo
  IF v_colab.data_demissao IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador desligado — reajuste não aplicável');
  END IF;

  -- Salário anterior e cargo anterior = valores REAIS no momento da conclusão
  -- (não o que estava em dados_extras quando o processo foi criado)
  v_sal_anterior := NULLIF(REPLACE(REPLACE(COALESCE(v_colab.salario::TEXT, ''), '.', ''), ',', '.'), '')::NUMERIC;
  v_cargo_ant    := COALESCE(v_colab.cargo, '');

  -- Percentual recalculado agora com base no salário real
  IF v_sal_anterior IS NOT NULL AND v_sal_anterior <> 0 THEN
    v_percentual := ROUND(((v_salario_novo - v_sal_anterior) / v_sal_anterior) * 100, 2);
  END IF;

  v_cargo_mudou := (v_cargo_novo IS NOT NULL AND v_cargo_novo IS DISTINCT FROM v_cargo_ant);
  v_aplicar_agora := (v_data_vigencia <= CURRENT_DATE);

  -- ── ETAPA 4: Verificar idempotência no historico_remuneracao ────────────
  SELECT EXISTS (
    SELECT 1 FROM historico_remuneracao
    WHERE colaborador_id = v_proc.colaborador_id
      AND processo_id    = p_processo_id
  ) INTO v_ja_existe;

  -- ── ETAPA 5: Marcar processo como concluído ──────────────────────────────
  UPDATE processos_rh SET
    status        = 'concluido',
    concluido_em  = NOW(),
    atualizado_em = NOW(),
    dados_extras  = v_extras
      || jsonb_build_object('concluido_por',    p_usuario)
      || jsonb_build_object('percentual_real',  v_percentual)
      || jsonb_build_object('salario_anterior', v_sal_anterior)
  WHERE id = p_processo_id;

  -- ── ETAPA 6: Inserir em historico_remuneracao (idempotente) ─────────────
  IF NOT v_ja_existe THEN
    INSERT INTO historico_remuneracao (
      colaborador_id,
      processo_id,
      data_vigencia,
      salario_anterior,
      salario_novo,
      percentual,
      cargo_anterior,
      cargo_novo,
      motivo_codigo,
      motivo_descricao,
      observacao,
      registrado_por,
      registrado_em,
      aplicado_em,
      estornado,
      esocial_enviado
    ) VALUES (
      v_proc.colaborador_id,
      p_processo_id,
      v_data_vigencia,
      v_sal_anterior,
      v_salario_novo,
      v_percentual,
      v_cargo_ant,
      CASE WHEN v_cargo_mudou THEN v_cargo_novo ELSE NULL END,
      v_motivo_cod,
      v_motivo_desc,
      v_observacao,
      p_usuario,
      NOW(),
      CASE WHEN v_aplicar_agora THEN NOW() ELSE NULL END,
      FALSE,
      FALSE
    );
  END IF;

  -- ── ETAPA 7: Aplicar no cadastro (somente se vigência <= hoje) ───────────
  IF v_aplicar_agora THEN

    -- Atualiza salário e cargo em colaboradores
    UPDATE colaboradores SET
      salario       = v_salario_novo::TEXT,
      cargo         = CASE WHEN v_cargo_mudou THEN v_cargo_novo ELSE cargo END,
      atualizado_em = NOW()
    WHERE id = v_proc.colaborador_id;

    -- Evento de reajuste salarial na timeline JSONB
    UPDATE colaboradores SET
      historico = COALESCE(historico, '[]'::JSONB)
        || jsonb_build_array(jsonb_build_object(
             'tipo',    'reajuste_salarial',
             'de',      COALESCE('R$ ' || TO_CHAR(v_sal_anterior, 'FM999G999D00'), '—'),
             'para',    'R$ ' || TO_CHAR(v_salario_novo, 'FM999G999D00'),
             'data',    TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
             'usuario', p_usuario,
             'ref',     'Processo #' || p_processo_id::TEXT
           ))
    WHERE id = v_proc.colaborador_id;

    -- Evento de cargo na timeline JSONB (somente se cargo mudou)
    IF v_cargo_mudou THEN
      UPDATE colaboradores SET
        historico = historico
          || jsonb_build_array(jsonb_build_object(
               'tipo',    'cargo',
               'de',      v_cargo_ant,
               'para',    v_cargo_novo,
               'data',    TO_CHAR(NOW() AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
               'usuario', p_usuario,
               'ref',     'Processo #' || p_processo_id::TEXT
             ))
      WHERE id = v_proc.colaborador_id;
    END IF;

  END IF;

  -- ── RETORNO ──────────────────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'ok',            true,
    'aplicado',      v_aplicar_agora,
    'data_vigencia', TO_CHAR(v_data_vigencia, 'DD/MM/YYYY'),
    'salario_novo',  v_salario_novo,
    'percentual',    v_percentual
  );

EXCEPTION WHEN OTHERS THEN
  -- Qualquer erro reverte toda a transação automaticamente (PL/pgSQL)
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
