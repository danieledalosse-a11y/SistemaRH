-- Migration 065: Desenvolvimento & Performance V1
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-29
-- Execute blocos 1 a 12 juntos, depois o bloco 13 separado para validar contagens.


-- BLOCO 1: ENUMs

CREATE TYPE dp_tipo_calculo AS ENUM (
  'soma',
  'media',
  'media_ponderada',
  'percentual_atingimento',
  'qualitativo'
);

CREATE TYPE dp_tipo_resposta AS ENUM (
  'binario',
  'escala',
  'numerico',
  'numerico_com_meta',
  'conceito',
  'texto'
);

CREATE TYPE dp_tipo_criterio AS ENUM (
  'tecnico',
  'comportamental'
);

CREATE TYPE dp_status_versao AS ENUM (
  'rascunho',
  'publicada',
  'descontinuada'
);

CREATE TYPE dp_tipo_elegibilidade AS ENUM (
  'todos',
  'setor',
  'cargo',
  'unidade',
  'lista_nominal'
);

CREATE TYPE dp_tipo_avaliador AS ENUM (
  'gestor_direto',
  'rh',
  'especifico',
  'autoavaliacao'
);

CREATE TYPE dp_status_ciclo AS ENUM (
  'rascunho',
  'aberto',
  'em_andamento',
  'encerrado',
  'cancelado'
);

CREATE TYPE dp_status_avaliacao AS ENUM (
  'nao_iniciada',
  'em_andamento',
  'concluida',
  'publicada'
);

CREATE TYPE dp_tipo_regra_financeira AS ENUM (
  'por_resposta',
  'por_resultado_faixa',
  'por_resultado_percentual',
  'fixo_por_conceito'
);

CREATE TYPE dp_status_resultado_financeiro AS ENUM (
  'calculado',
  'ajustado',
  'pago',
  'cancelado'
);

CREATE TYPE dp_evento_historico AS ENUM (
  'versao_publicada',
  'ciclo_criado',
  'ciclo_aberto',
  'ciclo_encerrado',
  'ciclo_cancelado',
  'avaliacao_iniciada',
  'avaliacao_concluida',
  'avaliacao_publicada',
  'avaliacao_reaberta',
  'participante_adicionado',
  'participante_removido'
);


-- BLOCO 2: Escalas
-- Apos uso em versao publicada, a escala fica totalmente congelada.

CREATE TABLE dp_escalas (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        TEXT        NOT NULL,
  descricao   TEXT,
  criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dp_escala_opcoes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  escala_id       UUID        NOT NULL REFERENCES dp_escalas(id),
  label           TEXT        NOT NULL,
  valor_numerico  NUMERIC,
  ordem           SMALLINT    NOT NULL,
  UNIQUE (escala_id, ordem)
);


-- BLOCO 3: Criterios (catalogo global)

CREATE TABLE dp_criterios (
  id                  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                TEXT        NOT NULL,
  descricao           TEXT,
  tipo                dp_tipo_criterio NOT NULL,
  area                TEXT,
  ativo               BOOLEAN     NOT NULL DEFAULT true,
  dev_competencias_id BIGINT      UNIQUE,
  criado_em           TIMESTAMPTZ NOT NULL DEFAULT now()
);


-- BLOCO 4: Modelos e Versoes

CREATE TABLE dp_modelos (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome        TEXT        NOT NULL,
  descricao   TEXT,
  ativo       BOOLEAN     NOT NULL DEFAULT true,
  criado_em   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dp_versoes (
  id                      UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
  modelo_id               UUID                  NOT NULL REFERENCES dp_modelos(id),
  numero                  SMALLINT              NOT NULL DEFAULT 1,
  status                  dp_status_versao      NOT NULL DEFAULT 'rascunho',
  em_uso                  BOOLEAN               NOT NULL DEFAULT false,
  tipo_calculo            dp_tipo_calculo       NOT NULL,
  tipo_elegibilidade      dp_tipo_elegibilidade NOT NULL DEFAULT 'todos',
  elegibilidade_ids       UUID[],
  converte_para_conceito  BOOLEAN               NOT NULL DEFAULT false,
  faixas_conceito         JSONB,
  publicado_em            TIMESTAMPTZ,
  publicado_por           UUID                  REFERENCES auth.users(id),
  criado_em               TIMESTAMPTZ           NOT NULL DEFAULT now(),
  UNIQUE (modelo_id, numero)
);

CREATE TABLE dp_versao_blocos (
  id          UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  versao_id   UUID     NOT NULL REFERENCES dp_versoes(id) ON DELETE CASCADE,
  nome        TEXT     NOT NULL,
  ordem       SMALLINT NOT NULL,
  UNIQUE (versao_id, ordem)
);

CREATE TABLE dp_versao_criterios (
  id                  UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
  versao_id           UUID             NOT NULL REFERENCES dp_versoes(id) ON DELETE CASCADE,
  criterio_id         UUID             NOT NULL REFERENCES dp_criterios(id),
  bloco_id            UUID             REFERENCES dp_versao_blocos(id),
  tipo_resposta       dp_tipo_resposta NOT NULL,
  escala_id           UUID             REFERENCES dp_escalas(id),
  peso                NUMERIC,
  obrigatorio         BOOLEAN          NOT NULL DEFAULT true,
  contribui_calculo   BOOLEAN          NOT NULL DEFAULT true,
  obs_condicao        JSONB,
  instrucao_avaliador TEXT,
  ordem               SMALLINT         NOT NULL,
  UNIQUE (versao_id, criterio_id),
  CONSTRAINT qualitativo_nao_calcula CHECK (
    tipo_resposta NOT IN ('texto', 'conceito') OR contribui_calculo = false
  ),
  CONSTRAINT escala_obrigatoria CHECK (
    tipo_resposta NOT IN ('binario', 'escala') OR escala_id IS NOT NULL
  )
);


-- BLOCO 5: Ciclos e Participantes
-- Snapshot minimo obrigatorio (responsabilidade da aplicacao):
--   nome, matricula, empresa, setor, cargo, unidade

CREATE TABLE dp_ciclos (
  id              UUID              PRIMARY KEY DEFAULT gen_random_uuid(),
  versao_id       UUID              NOT NULL REFERENCES dp_versoes(id),
  nome            TEXT              NOT NULL,
  status          dp_status_ciclo   NOT NULL DEFAULT 'rascunho',
  tipo_avaliador  dp_tipo_avaliador NOT NULL DEFAULT 'gestor_direto',
  data_inicio     DATE,
  data_fim        DATE,
  aberto_por      UUID              REFERENCES auth.users(id),
  aberto_em       TIMESTAMPTZ,
  encerrado_em    TIMESTAMPTZ,
  criado_em       TIMESTAMPTZ       NOT NULL DEFAULT now()
);

CREATE TABLE dp_ciclo_participantes (
  id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  ciclo_id        UUID        NOT NULL REFERENCES dp_ciclos(id) ON DELETE CASCADE,
  colaborador_id  INTEGER     NOT NULL REFERENCES colaboradores(id),
  snapshot        JSONB       NOT NULL,
  adicionado_em   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (ciclo_id, colaborador_id)
);


-- BLOCO 6: Avaliacoes e Respostas

CREATE TABLE dp_avaliacoes (
  id               UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  ciclo_id         UUID                NOT NULL REFERENCES dp_ciclos(id),
  participante_id  UUID                NOT NULL REFERENCES dp_ciclo_participantes(id),
  tipo_avaliador   dp_tipo_avaliador   NOT NULL,
  avaliador_id     UUID                REFERENCES auth.users(id),
  status           dp_status_avaliacao NOT NULL DEFAULT 'nao_iniciada',
  iniciada_em      TIMESTAMPTZ,
  concluida_em     TIMESTAMPTZ,
  publicada_em     TIMESTAMPTZ,
  publicada_por    UUID                REFERENCES auth.users(id),
  UNIQUE (ciclo_id, participante_id, tipo_avaliador)
);

CREATE TABLE dp_respostas (
  id                       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  avaliacao_id             UUID        NOT NULL REFERENCES dp_avaliacoes(id) ON DELETE CASCADE,
  versao_criterio_id       UUID        NOT NULL REFERENCES dp_versao_criterios(id),
  escala_opcao_id          UUID        REFERENCES dp_escala_opcoes(id),
  valor_numerico_livre     NUMERIC,
  meta                     NUMERIC,
  realizado                NUMERIC,
  conceito_selecionado     TEXT,
  resposta_texto           TEXT,
  snapshot_opcao_label     TEXT,
  snapshot_opcao_valor_num NUMERIC,
  observacao               TEXT,
  respondido_em            TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (avaliacao_id, versao_criterio_id)
);


-- BLOCO 7: Resultados

CREATE TABLE dp_resultados (
  id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  avaliacao_id  UUID        NOT NULL UNIQUE REFERENCES dp_avaliacoes(id),
  nota_final    NUMERIC,
  conceito      TEXT,
  calculado_em  TIMESTAMPTZ NOT NULL DEFAULT now(),
  calculado_por UUID        REFERENCES auth.users(id),
  CONSTRAINT resultado_tem_valor CHECK (
    nota_final IS NOT NULL OR conceito IS NOT NULL
  )
);


-- BLOCO 8: Camada financeira (totalmente opcional)

CREATE TABLE dp_regras_financeiras (
  id          UUID                    PRIMARY KEY DEFAULT gen_random_uuid(),
  versao_id   UUID                    NOT NULL REFERENCES dp_versoes(id) ON DELETE CASCADE,
  tipo        dp_tipo_regra_financeira NOT NULL,
  nome        TEXT                    NOT NULL,
  teto_valor  NUMERIC,
  ativo       BOOLEAN                 NOT NULL DEFAULT true,
  criado_em   TIMESTAMPTZ             NOT NULL DEFAULT now()
);

CREATE TABLE dp_regra_financeira_opcoes (
  id                   UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  regra_financeira_id  UUID    NOT NULL REFERENCES dp_regras_financeiras(id) ON DELETE CASCADE,
  versao_criterio_id   UUID    NOT NULL REFERENCES dp_versao_criterios(id),
  escala_opcao_id      UUID    NOT NULL REFERENCES dp_escala_opcoes(id),
  valor_financeiro     NUMERIC NOT NULL,
  UNIQUE (regra_financeira_id, versao_criterio_id, escala_opcao_id)
);

CREATE TABLE dp_regra_financeira_faixas (
  id                   UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
  regra_financeira_id  UUID    NOT NULL REFERENCES dp_regras_financeiras(id) ON DELETE CASCADE,
  nota_min             NUMERIC,
  nota_max             NUMERIC,
  conceito_ref         TEXT,
  valor_financeiro     NUMERIC,
  percentual_salario   NUMERIC
);

CREATE TABLE dp_resultados_financeiros (
  id                    UUID                           PRIMARY KEY DEFAULT gen_random_uuid(),
  resultado_id          UUID                           NOT NULL REFERENCES dp_resultados(id),
  regra_financeira_id   UUID                           NOT NULL REFERENCES dp_regras_financeiras(id),
  valor_calculado       NUMERIC                        NOT NULL,
  valor_final           NUMERIC                        NOT NULL,
  status                dp_status_resultado_financeiro NOT NULL DEFAULT 'calculado',
  justificativa_ajuste  TEXT,
  ajustado_por          UUID                           REFERENCES auth.users(id),
  ajustado_em           TIMESTAMPTZ,
  configuracao_snapshot JSONB                          NOT NULL,
  calculado_em          TIMESTAMPTZ                    NOT NULL DEFAULT now(),
  UNIQUE (resultado_id, regra_financeira_id)
);


-- BLOCO 9: Historico de eventos

CREATE TABLE dp_historico_eventos (
  id           UUID                PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo         dp_evento_historico NOT NULL,
  entidade     TEXT                NOT NULL,
  entidade_id  UUID                NOT NULL,
  detalhe      JSONB,
  usuario_id   UUID                REFERENCES auth.users(id),
  criado_em    TIMESTAMPTZ         NOT NULL DEFAULT now()
);


-- BLOCO 10: Triggers de imutabilidade

CREATE OR REPLACE FUNCTION dp_fn_escala_opcoes_proteger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  v_escala_id UUID;
BEGIN
  v_escala_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.escala_id ELSE NEW.escala_id END;
  IF EXISTS (
    SELECT 1
    FROM dp_versao_criterios vc
    JOIN dp_versoes v ON v.id = vc.versao_id
    WHERE vc.escala_id = v_escala_id AND v.em_uso = true
  ) THEN
    RAISE EXCEPTION 'Escala em uso por versao publicada. Crie uma nova escala para uma configuracao diferente.';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_eo_proteger_em_uso
  BEFORE INSERT OR UPDATE OR DELETE ON dp_escala_opcoes
  FOR EACH ROW EXECUTE FUNCTION dp_fn_escala_opcoes_proteger();

CREATE OR REPLACE FUNCTION dp_fn_escalas_proteger_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM dp_versao_criterios vc
    JOIN dp_versoes v ON v.id = vc.versao_id
    WHERE vc.escala_id = OLD.id AND v.em_uso = true
  ) THEN
    RAISE EXCEPTION 'Escala em uso por versao publicada e nao pode ser removida.';
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_e_proteger_delete
  BEFORE DELETE ON dp_escalas
  FOR EACH ROW EXECUTE FUNCTION dp_fn_escalas_proteger_delete();

CREATE OR REPLACE FUNCTION dp_fn_versao_proteger_em_uso()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_em_uso BOOLEAN;
BEGIN
  SELECT em_uso INTO v_em_uso
  FROM dp_versoes
  WHERE id = COALESCE(NEW.versao_id, OLD.versao_id);
  IF v_em_uso THEN
    RAISE EXCEPTION 'Esta versao esta publicada e em uso. Crie uma nova versao para fazer alteracoes.';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vc_proteger_em_uso
  BEFORE INSERT OR UPDATE OR DELETE ON dp_versao_criterios
  FOR EACH ROW EXECUTE FUNCTION dp_fn_versao_proteger_em_uso();

CREATE TRIGGER trg_vb_proteger_em_uso
  BEFORE INSERT OR UPDATE OR DELETE ON dp_versao_blocos
  FOR EACH ROW EXECUTE FUNCTION dp_fn_versao_proteger_em_uso();

CREATE OR REPLACE FUNCTION dp_fn_resposta_snapshot()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.escala_opcao_id IS NOT NULL THEN
    SELECT label, valor_numerico
    INTO   NEW.snapshot_opcao_label, NEW.snapshot_opcao_valor_num
    FROM   dp_escala_opcoes
    WHERE  id = NEW.escala_opcao_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_resposta_snapshot
  BEFORE INSERT ON dp_respostas
  FOR EACH ROW EXECUTE FUNCTION dp_fn_resposta_snapshot();


-- BLOCO 11: Funcao de validacao da versao
-- Chamada antes de publicar. Retorna {valido: bool, erros: [{regra, mensagem}]}

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

  -- Regra 2: converte_para_conceito exige faixas_conceito preenchido
  IF v_versao.converte_para_conceito AND (
    v_versao.faixas_conceito IS NULL OR jsonb_array_length(v_versao.faixas_conceito) = 0
  ) THEN
    v_erros := v_erros || jsonb_build_object('regra', 2, 'mensagem', 'Conversao para conceito ativada sem faixas configuradas.');
  END IF;

  -- Regra 3: criterios calculaveis com escala precisam de valor_numerico em todas as opcoes
  IF v_versao.tipo_calculo != 'qualitativo' THEN
    SELECT COUNT(DISTINCT vc.id) INTO v_escala_inv
    FROM dp_versao_criterios vc
    JOIN dp_escala_opcoes eo ON eo.escala_id = vc.escala_id
    WHERE vc.versao_id = p_versao_id
      AND vc.tipo_resposta IN ('binario', 'escala')
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
      v_erros := v_erros || jsonb_build_object('regra', '5b', 'mensagem', format('Modelo qualitativo nao permite contribui_calculo = true (%s encontrado(s)).', v_incompativeis));
    END IF;
  END IF;

  RETURN jsonb_build_object('valido', jsonb_array_length(v_erros) = 0, 'erros', v_erros);
END;
$$;


-- BLOCO 12: Funcao de historico de criterio
-- Comparabilidade: mesmo modelo + criterio + escala + tipo de resposta + avaliacao publicada.
-- Retorna {comparavel: false} quando nao ha historico valido.

CREATE OR REPLACE FUNCTION dp_fn_historico_criterio(
  p_colaborador_id  INTEGER,
  p_criterio_id     UUID,
  p_ciclo_atual_id  UUID,
  p_modelo_id       UUID,
  p_escala_id       UUID,
  p_tipo_resposta   dp_tipo_resposta
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
  v_resultado JSONB;
BEGIN
  SELECT jsonb_build_object(
    'comparavel',           true,
    'ciclo_nome',           c.nome,
    'ciclo_encerrado_em',   c.encerrado_em,
    'escala_opcao_label',   r.snapshot_opcao_label,
    'escala_opcao_valor',   r.snapshot_opcao_valor_num,
    'valor_numerico_livre', r.valor_numerico_livre,
    'meta',                 r.meta,
    'realizado',            r.realizado,
    'conceito_selecionado', r.conceito_selecionado,
    'nota_final',           res.nota_final,
    'conceito_resultado',   res.conceito
  )
  INTO v_resultado
  FROM dp_respostas r
  JOIN dp_versao_criterios vc    ON vc.id  = r.versao_criterio_id
  JOIN dp_versoes v              ON v.id   = vc.versao_id
  JOIN dp_avaliacoes a           ON a.id   = r.avaliacao_id
  JOIN dp_ciclo_participantes cp ON cp.id  = a.participante_id
  JOIN dp_ciclos c               ON c.id   = cp.ciclo_id
  LEFT JOIN dp_resultados res    ON res.avaliacao_id = a.id
  WHERE cp.colaborador_id = p_colaborador_id
    AND vc.criterio_id    = p_criterio_id
    AND c.id             != p_ciclo_atual_id
    AND v.modelo_id       = p_modelo_id
    AND a.status          = 'publicada'
    AND (p_escala_id IS NULL OR vc.escala_id = p_escala_id)
    AND vc.tipo_resposta  = p_tipo_resposta
  ORDER BY c.encerrado_em DESC
  LIMIT 1;

  IF v_resultado IS NULL THEN
    RETURN jsonb_build_object('comparavel', false);
  END IF;

  RETURN v_resultado;
END;
$$;


-- BLOCO 13: Migration dos criterios existentes (dev_competencias -> dp_criterios)
-- Executar separadamente e validar contagens antes de continuar.
-- Resultado esperado: total_origem = total_migrado

-- Mapeamento: dev_competencias usa 'tecnica'/'comportamenta' (feminino/abreviado)
-- dp_tipo_criterio usa 'tecnico'/'comportamental'
INSERT INTO dp_criterios (id, nome, tipo, area, ativo, dev_competencias_id, criado_em)
SELECT
  gen_random_uuid(),
  nome,
  CASE TRIM(tipo)
    WHEN 'tecnica'        THEN 'tecnico'
    WHEN 'comportamental' THEN 'comportamental'
  END::dp_tipo_criterio,
  NULLIF(TRIM(COALESCE(area, '')), ''),
  COALESCE(ativo, true),
  id,
  now()
FROM dev_competencias
ON CONFLICT (dev_competencias_id) DO NOTHING;

-- Validacao (executar apos o INSERT acima):
-- SELECT
--   (SELECT COUNT(*) FROM dev_competencias) AS total_origem,
--   (SELECT COUNT(*) FROM dp_criterios WHERE dev_competencias_id IS NOT NULL) AS total_migrado;


-- BLOCO 14: Remocao das tabelas legadas (MANUAL, apos validacao)
-- Executar somente apos confirmar contagens iguais no bloco 13.
-- dev_pdi: MANTIDO para implementacao no modulo PDI (V2).

-- DROP TABLE IF EXISTS dev_historico;
-- DROP TABLE IF EXISTS dev_avaliacoes;
-- DROP TABLE IF EXISTS dev_ciclos;
-- DROP TABLE IF EXISTS dev_competencias;
