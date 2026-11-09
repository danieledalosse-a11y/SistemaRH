-- Migration 146: he_fn_importar — importação transacional de horas extras
--
-- Resolve 5 problemas da abordagem anterior (N+1 requests no cliente):
--   1. ATOMICIDADE: todas as operações em uma transação — rollback automático em qualquer falha
--   2. CONCORRÊNCIA: advisory lock impede processamento simultâneo de mesma empresa+competência
--   3. VERSÃO: lê o máximo real do banco antes de desativar a versão anterior
--   4. HISTÓRICO: 1 UPDATE em lote (não N×GET + N×PATCH); previne duplicatas por colaborador
--   5. ACESSO: valida auth_perfil() dentro da função — não depende só da interface
--
-- Dependências:
--   - he_importacoes (migration 145)
--   - he_registros   (migration 145)
--   - param_empresa  (existente)
--   - colaboradores  (existente)
--   - auth_perfil()  (existente — usada pelo módulo D&P e outros)

CREATE OR REPLACE FUNCTION public.he_fn_importar(
  p_competencia      text,
  p_param_empresa_id integer,
  p_arquivo_nome     text,
  p_importado_por    text,
  p_total_colabs     integer,
  p_total_horas      numeric,
  p_total_valor      numeric,
  p_registros        jsonb     -- array de objetos com campos definidos abaixo
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
-- Campos esperados em cada elemento de p_registros:
--   colaborador_id    text    id do colaborador (string) ou '' quando não encontrado
--   matricula_pdf     text    matrícula com zeros à esquerda (ex: '0000427')
--   empresa_codigo    text    código original do PDF (ex: '0148')
--   percentuais       jsonb   ex: {"50":{"quant":7.57,"valor":95.66},"70":{...}}
--   dsr_quant         numeric
--   dsr_valor         numeric
--   total_quant       numeric
--   total_valor       numeric
--   status_vinculo    text    vinculado | inativo | ambiguo | nao_encontrado
--   detalhe_historico text    texto pré-formatado para colaboradores.historico

DECLARE
  v_perfil        text;
  v_lock_key      bigint;
  v_versao        integer;
  v_importacao_id uuid;
  v_empresa_nome  text;
BEGIN
  -- ── 1. Validação de perfil ─────────────────────────────────────────────────
  -- auth_perfil() é SECURITY DEFINER definida em migration anterior.
  -- Esta verificação garante que somente RH/admin execute, independente da interface.
  v_perfil := auth_perfil();
  IF v_perfil NOT IN ('rh', 'admin') THEN
    RAISE EXCEPTION 'Acesso negado: somente perfil rh ou admin pode importar horas extras.'
      USING ERRCODE = 'P0001';
  END IF;

  -- ── 2. Validações de entrada ───────────────────────────────────────────────
  IF p_competencia IS NULL OR p_competencia !~ '^\d{4}-\d{2}$' THEN
    RAISE EXCEPTION 'Competência inválida: esperado formato YYYY-MM, recebido %', p_competencia
      USING ERRCODE = 'P0002';
  END IF;

  IF p_registros IS NULL OR jsonb_array_length(p_registros) = 0 THEN
    RAISE EXCEPTION 'Nenhum registro informado para importação.'
      USING ERRCODE = 'P0003';
  END IF;

  -- Valida empresa antes de tomar qualquer lock
  SELECT nome_simplificado INTO v_empresa_nome
    FROM param_empresa
   WHERE id = p_param_empresa_id AND ativo = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Empresa id=% não encontrada ou inativa.', p_param_empresa_id
      USING ERRCODE = 'P0004';
  END IF;

  -- ── 3. Advisory lock — evita importações simultâneas ──────────────────────
  -- pg_advisory_xact_lock libera automaticamente ao final da transação.
  -- Chave única por (empresa, competência) usando hashtext para caber em bigint.
  v_lock_key := hashtext(p_competencia || '|' || p_param_empresa_id::text);
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- ── 4. Calcula próxima versão ANTES de qualquer alteração ─────────────────
  -- Lê o máximo real do banco para garantir sequência correta independente
  -- do número de substituições anteriores.
  SELECT COALESCE(MAX(versao), 0) + 1
    INTO v_versao
    FROM he_importacoes
   WHERE competencia      = p_competencia
     AND param_empresa_id = p_param_empresa_id;

  -- ── 5. Desativa importação anterior ───────────────────────────────────────
  -- Ocorre dentro da transação: se qualquer passo posterior falhar,
  -- este UPDATE também é desfeito — versão anterior retorna como ativa.
  UPDATE he_importacoes
     SET ativo = false
   WHERE competencia      = p_competencia
     AND param_empresa_id = p_param_empresa_id
     AND ativo = true;

  -- ── 6. Cria nova importação ───────────────────────────────────────────────
  INSERT INTO he_importacoes(
    competencia, param_empresa_id, arquivo_nome, versao,
    importado_por, total_colabs, total_horas, total_valor
  )
  VALUES (
    p_competencia, p_param_empresa_id, p_arquivo_nome, v_versao,
    p_importado_por, p_total_colabs, p_total_horas, p_total_valor
  )
  RETURNING id INTO v_importacao_id;

  -- ── 7. Insere registros em lote — 1 INSERT ────────────────────────────────
  INSERT INTO he_registros(
    importacao_id, colaborador_id, matricula_pdf, empresa_codigo,
    competencia, percentuais,
    dsr_quant, dsr_valor, total_quant, total_valor, status_vinculo
  )
  SELECT
    v_importacao_id,
    NULLIF(r->>'colaborador_id', '')::integer,
    r->>'matricula_pdf',
    r->>'empresa_codigo',
    p_competencia,
    r->'percentuais',
    (r->>'dsr_quant')::numeric,
    (r->>'dsr_valor')::numeric,
    (r->>'total_quant')::numeric,
    (r->>'total_valor')::numeric,
    r->>'status_vinculo'
  FROM jsonb_array_elements(p_registros) AS r;

  -- ── 8. Atualiza histórico em lote — 1 UPDATE ──────────────────────────────
  -- Apenas registros vinculados ou inativos (têm colaborador_id).
  -- CTE deduplica pelo colaborador_id para evitar múltiplas entradas
  -- caso o mesmo colaborador apareça mais de uma vez no p_registros.
  WITH vinculados AS (
    SELECT DISTINCT ON (NULLIF(r->>'colaborador_id','')::integer)
      NULLIF(r->>'colaborador_id', '')::integer AS colab_id,
      r->>'detalhe_historico'                   AS detalhe
    FROM jsonb_array_elements(p_registros) AS r
   WHERE (r->>'status_vinculo') IN ('vinculado', 'inativo')
     AND (r->>'colaborador_id') IS NOT NULL
     AND (r->>'colaborador_id') <> ''
   ORDER BY NULLIF(r->>'colaborador_id','')::integer
  )
  UPDATE colaboradores c
     SET historico = COALESCE(c.historico, '[]'::jsonb)
                     || jsonb_build_array(
                          jsonb_build_object(
                            'tipo',    'he_importacao',
                            'data',    to_char(
                                         now() AT TIME ZONE 'America/Sao_Paulo',
                                         'YYYY-MM-DD"T"HH24:MI:SS"Z"'
                                       ),
                            'detalhe', v.detalhe,
                            'usuario', p_importado_por
                          )
                        )
    FROM vinculados v
   WHERE c.id = v.colab_id;

  -- ── 9. Retorna resultado ───────────────────────────────────────────────────
  RETURN jsonb_build_object(
    'importacao_id', v_importacao_id,
    'versao',        v_versao,
    'empresa',       v_empresa_nome,
    'competencia',   p_competencia
  );

EXCEPTION
  WHEN OTHERS THEN
    -- Re-lança com contexto adicional para facilitar diagnóstico no cliente
    RAISE EXCEPTION 'he_fn_importar falhou [%]: %', SQLSTATE, SQLERRM;
END;
$$;

-- Concede execução apenas a usuários autenticados.
-- A verificação de perfil dentro da função é a guarda real.
GRANT EXECUTE ON FUNCTION public.he_fn_importar TO authenticated;
