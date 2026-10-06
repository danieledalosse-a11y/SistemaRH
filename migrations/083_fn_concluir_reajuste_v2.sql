-- Migration 083 — fn_concluir_reajuste v2
-- Incorpora Etapas 8 (historico_eventos) e 9 (processo_auditoria) à função existente.
-- Inclui também correções de tipo já aplicadas via SQL Editor (salario NUMERIC, v_sal_anterior direto).
-- Lógica de idempotência expandida para cobrir cenário de recuperação de evento ausente.
-- O comportamento das Etapas 1–7 é preservado integralmente.

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
  v_hist_rec      historico_remuneracao%ROWTYPE;
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
  v_hist_id       BIGINT;
  v_tipo_evento   TEXT;
  v_dados_evento  JSONB;
  v_titulo_evento TEXT;
  v_resumo_evento TEXT;
BEGIN

  -- ── ETAPA 1: Carregar e validar o processo ───────────────────────────────
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

  IF v_proc.status = 'cancelado' THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Processo cancelado não pode ser concluído');
  END IF;

  -- ── Idempotência expandida: processo já concluído ────────────────────────
  -- Distingue "já tudo gravado" de "processo concluído mas evento ausente"
  IF v_proc.status = 'concluido' THEN

    IF EXISTS (SELECT 1 FROM historico_eventos WHERE processo_id = p_processo_id) THEN
      RETURN jsonb_build_object('ok', true, 'aviso', 'Processo e evento já registrados');
    END IF;

    -- Modo recuperação: processo concluído, evento ausente
    -- Reconstrói o evento a partir do dado oficial já gravado (historico_remuneracao)
    SELECT * INTO v_hist_rec
    FROM historico_remuneracao
    WHERE processo_id = p_processo_id;

    IF NOT FOUND THEN
      RETURN jsonb_build_object(
        'ok', false,
        'erro', 'Processo ' || p_processo_id::TEXT ||
                ' está concluído mas não possui registro em historico_remuneracao. ' ||
                'Não é possível recuperar o evento sem dados suficientes.'
      );
    END IF;

    -- Determina tipo do evento a partir do motivo oficial gravado
    v_tipo_evento := CASE v_hist_rec.motivo_codigo
      WHEN '0.2' THEN 'promocao'
      WHEN '0.1' THEN 'reajuste_salarial'
      WHEN '0.3' THEN 'reajuste_salarial'
      WHEN '0.4' THEN 'reajuste_salarial'
      WHEN '0.5' THEN 'reajuste_salarial'
      WHEN '0.6' THEN 'reajuste_salarial'
      ELSE NULL
    END;

    IF v_tipo_evento IS NULL THEN
      RETURN jsonb_build_object(
        'ok', false,
        'erro', 'Motivo "' || COALESCE(v_hist_rec.motivo_codigo, 'nulo') ||
                '" não possui tipo de evento configurado. Não é possível recuperar o evento.'
      );
    END IF;

    v_dados_evento := jsonb_build_object(
      'salario_anterior',  v_hist_rec.salario_anterior,
      'salario_novo',      v_hist_rec.salario_novo,
      'percentual',        v_hist_rec.percentual,
      'cargo_anterior',    v_hist_rec.cargo_anterior,
      'cargo_novo',        v_hist_rec.cargo_novo,
      'motivo_codigo',     v_hist_rec.motivo_codigo,
      'motivo_descricao',  v_hist_rec.motivo_descricao
    );

    PERFORM _validar_dados_evento(v_tipo_evento, v_dados_evento);

    v_titulo_evento := CASE v_tipo_evento
      WHEN 'promocao' THEN 'Promovido para ' || v_hist_rec.cargo_novo
      ELSE 'Reajuste salarial'
    END;

    v_resumo_evento := CASE
      WHEN v_hist_rec.salario_anterior IS NOT NULL
      THEN 'R$ ' || TO_CHAR(v_hist_rec.salario_anterior, 'FM999G999D00') ||
           ' → R$ ' || TO_CHAR(v_hist_rec.salario_novo, 'FM999G999D00') ||
           COALESCE(' (+' || TO_CHAR(v_hist_rec.percentual, 'FM990D00') || '%)', '')
      ELSE 'R$ ' || TO_CHAR(v_hist_rec.salario_novo, 'FM999G999D00')
    END;

    INSERT INTO historico_eventos (
      colaborador_id, tipo, titulo, resumo, dados,
      data_evento, registrado_por, registrado_por_id,
      ref_tabela, ref_id, processo_id, origem
    ) VALUES (
      v_hist_rec.colaborador_id,
      v_tipo_evento,
      v_titulo_evento,
      v_resumo_evento,
      v_dados_evento,
      v_hist_rec.data_vigencia,
      p_usuario,
      auth.uid(),
      'historico_remuneracao', v_hist_rec.id,
      p_processo_id,
      'sistema'
    );

    INSERT INTO processo_auditoria (
      processo_id, acao, detalhe, usuario, usuario_id
    ) VALUES (
      p_processo_id,
      'concluido',
      'Evento de histórico recuperado. Vigência: ' || v_hist_rec.data_vigencia::TEXT,
      p_usuario,
      auth.uid()
    );

    RETURN jsonb_build_object('ok', true, 'aviso', 'Evento de histórico recuperado');
  END IF;

  -- ── ETAPA 2: Extrair e validar campos de dados_extras ───────────────────
  v_extras        := COALESCE(v_proc.dados_extras, '{}'::JSONB);
  v_data_vigencia := (v_extras->>'data_vigencia')::DATE;
  v_salario_novo  := (v_extras->>'salario_novo')::NUMERIC;
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

  -- Determina tipo do evento pelo motivo — erro claro se não mapeado
  v_tipo_evento := CASE v_motivo_cod
    WHEN '0.2' THEN 'promocao'
    WHEN '0.1' THEN 'reajuste_salarial'
    WHEN '0.3' THEN 'reajuste_salarial'
    WHEN '0.4' THEN 'reajuste_salarial'
    WHEN '0.5' THEN 'reajuste_salarial'
    WHEN '0.6' THEN 'reajuste_salarial'
    ELSE NULL
  END;

  IF v_tipo_evento IS NULL THEN
    RETURN jsonb_build_object(
      'ok', false,
      'erro', 'Motivo "' || COALESCE(v_motivo_cod, 'nulo') ||
              '" não possui tipo de evento configurado em tipos_evento. ' ||
              'Cadastre o tipo antes de concluir.'
    );
  END IF;

  -- ── ETAPA 3: Carregar colaborador ────────────────────────────────────────
  SELECT * INTO v_colab
  FROM colaboradores
  WHERE id = v_proc.colaborador_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador não encontrado');
  END IF;

  IF v_colab.data_demissao IS NOT NULL THEN
    RETURN jsonb_build_object('ok', false, 'erro', 'Colaborador desligado — reajuste não aplicável');
  END IF;

  -- Salário e cargo anteriores = valores REAIS no momento da conclusão
  v_sal_anterior := v_colab.salario;
  v_cargo_ant    := COALESCE(v_colab.cargo, '');

  IF v_sal_anterior IS NOT NULL AND v_sal_anterior <> 0 THEN
    v_percentual := ROUND(((v_salario_novo - v_sal_anterior) / v_sal_anterior) * 100, 2);
  END IF;

  v_cargo_mudou   := (v_cargo_novo IS NOT NULL AND v_cargo_novo IS DISTINCT FROM v_cargo_ant);
  v_aplicar_agora := (v_data_vigencia <= CURRENT_DATE);

  -- ── ETAPA 4: Verificar idempotência em historico_remuneracao ─────────────
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
      colaborador_id, processo_id, data_vigencia,
      salario_anterior, salario_novo, percentual,
      cargo_anterior, cargo_novo,
      motivo_codigo, motivo_descricao, observacao,
      registrado_por, registrado_em, aplicado_em,
      estornado, esocial_enviado
    ) VALUES (
      v_proc.colaborador_id, p_processo_id, v_data_vigencia,
      v_sal_anterior, v_salario_novo, v_percentual,
      v_cargo_ant, CASE WHEN v_cargo_mudou THEN v_cargo_novo ELSE NULL END,
      v_motivo_cod, v_motivo_desc, v_observacao,
      p_usuario, NOW(),
      CASE WHEN v_aplicar_agora THEN NOW() ELSE NULL END,
      FALSE, FALSE
    )
    RETURNING id INTO v_hist_id;
  ELSE
    -- Registro já existe: captura o ID para usar como ref_id no evento
    SELECT id INTO v_hist_id
    FROM historico_remuneracao
    WHERE colaborador_id = v_proc.colaborador_id AND processo_id = p_processo_id;
  END IF;

  -- ── ETAPA 7: Aplicar no cadastro (somente se vigência <= hoje) ───────────
  IF v_aplicar_agora THEN

    UPDATE colaboradores SET
      salario       = v_salario_novo,
      cargo         = CASE WHEN v_cargo_mudou THEN v_cargo_novo ELSE cargo END,
      atualizado_em = NOW()
    WHERE id = v_proc.colaborador_id;

    -- Mantém gravação no historico JSONB (comportamento legado preservado)
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

  -- ── ETAPA 8: Gravar evento na linha do tempo ──────────────────────────────
  v_dados_evento := jsonb_build_object(
    'salario_anterior',  v_sal_anterior,
    'salario_novo',      v_salario_novo,
    'percentual',        v_percentual,
    'cargo_anterior',    v_cargo_ant,
    'cargo_novo',        CASE WHEN v_cargo_mudou THEN v_cargo_novo ELSE NULL END,
    'motivo_codigo',     v_motivo_cod,
    'motivo_descricao',  v_motivo_desc
  );

  PERFORM _validar_dados_evento(v_tipo_evento, v_dados_evento);

  v_titulo_evento := CASE v_tipo_evento
    WHEN 'promocao' THEN 'Promovido para ' || v_cargo_novo
    ELSE 'Reajuste salarial'
  END;

  v_resumo_evento := CASE
    WHEN v_sal_anterior IS NOT NULL
    THEN 'R$ ' || TO_CHAR(v_sal_anterior, 'FM999G999D00') ||
         ' → R$ ' || TO_CHAR(v_salario_novo, 'FM999G999D00') ||
         COALESCE(' (+' || TO_CHAR(v_percentual, 'FM990D00') || '%)', '')
    ELSE 'R$ ' || TO_CHAR(v_salario_novo, 'FM999G999D00')
  END;

  INSERT INTO historico_eventos (
    colaborador_id, tipo, titulo, resumo, dados,
    data_evento, registrado_por, registrado_por_id,
    ref_tabela, ref_id, processo_id, origem
  ) VALUES (
    v_proc.colaborador_id,
    v_tipo_evento,
    v_titulo_evento,
    v_resumo_evento,
    v_dados_evento,
    v_data_vigencia,
    p_usuario,
    auth.uid(),
    'historico_remuneracao', v_hist_id,
    p_processo_id,
    'sistema'
  );

  -- ── ETAPA 9: Registrar auditoria de conclusão ─────────────────────────────
  INSERT INTO processo_auditoria (
    processo_id, acao, detalhe, usuario, usuario_id
  ) VALUES (
    p_processo_id,
    'concluido',
    'Reajuste salarial aplicado. Vigência: ' || v_data_vigencia::TEXT,
    p_usuario,
    auth.uid()
  );

  -- ── RETORNO ──────────────────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'ok',            true,
    'aplicado',      v_aplicar_agora,
    'data_vigencia', TO_CHAR(v_data_vigencia, 'DD/MM/YYYY'),
    'salario_novo',  v_salario_novo,
    'percentual',    v_percentual
  );

EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('ok', false, 'erro', SQLERRM);
END;
$$;
