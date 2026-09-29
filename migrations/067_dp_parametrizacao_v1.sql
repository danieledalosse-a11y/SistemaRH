-- Migration 067: Parametrização D&P V1
-- SistemaRH Revest do Brasil Acabamentos Ltda
-- Data: 2026-09-29 — executada e validada
--
-- Escopo (mínimo aprovado):
--   1. dp_tipos_avaliador     → tabela substituindo ENUM dp_tipo_avaliador
--   2. dp_tipos_calculo_config → metadados de UI para os algoritmos existentes
--   3. dp_tabelas_conceito + dp_faixas_conceito → substituem JSONB faixas_conceito
--   4. criterio_nome_snapshot  → snapshot do nome do critério ao publicar versão
--   5. elegibilidade           → movida de dp_versoes para dp_ciclos
--
-- Pré-condições verificadas:
--   - tipo_elegibilidade e elegibilidade_ids: sem referências no código JS
--   - faixas_conceito JSONB: referenciado na UI (drawer de versão) — será atualizado depois
--   - Nenhum ciclo existe em produção — sem dados a migrar nos campos de elegibilidade
--   - Nenhuma versão publicada existe — sem dados a migrar em faixas_conceito
--   - Nenhum criterio_nome_snapshot existe — campo novo, sem migração de dados
--
-- Execute os blocos em ordem. Não pule blocos.


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 1: Tipos de Avaliador — substituir ENUM por tabela
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE dp_tipos_avaliador (
  id        UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo    TEXT     NOT NULL UNIQUE,  -- corresponde ao valor do ENUM antigo (imutável)
  label     TEXT     NOT NULL,
  descricao TEXT,
  ativo     BOOLEAN  NOT NULL DEFAULT true,
  ordem     SMALLINT NOT NULL DEFAULT 0
);

-- Migrar os 4 valores do ENUM como primeiras linhas da tabela
INSERT INTO dp_tipos_avaliador (codigo, label, descricao, ordem) VALUES
  ('gestor_direto', 'Gestor direto',        'Avaliação conduzida pelo gestor imediato do colaborador', 1),
  ('autoavaliacao', 'Auto-avaliação',        'Preenchida pelo próprio colaborador',                    2),
  ('rh',            'RH',                   'Conduzida pela equipe de Recursos Humanos',               3),
  ('especifico',    'Avaliador específico', 'Avaliador designado individualmente',                     4);

-- dp_ciclos: adicionar FK, migrar dados, remover coluna ENUM
ALTER TABLE dp_ciclos
  ADD COLUMN tipo_avaliador_id UUID REFERENCES dp_tipos_avaliador(id);

UPDATE dp_ciclos c
SET tipo_avaliador_id = ta.id
FROM dp_tipos_avaliador ta
WHERE ta.codigo = c.tipo_avaliador::TEXT;

ALTER TABLE dp_ciclos
  ALTER COLUMN tipo_avaliador_id SET NOT NULL,
  DROP COLUMN tipo_avaliador;

-- dp_avaliacoes: adicionar FK, migrar dados, remover coluna ENUM
ALTER TABLE dp_avaliacoes
  ADD COLUMN tipo_avaliador_id UUID REFERENCES dp_tipos_avaliador(id);

UPDATE dp_avaliacoes a
SET tipo_avaliador_id = ta.id
FROM dp_tipos_avaliador ta
WHERE ta.codigo = a.tipo_avaliador::TEXT;

ALTER TABLE dp_avaliacoes
  ALTER COLUMN tipo_avaliador_id SET NOT NULL,
  DROP COLUMN tipo_avaliador;

-- Remover o ENUM — agora sem referências
DROP TYPE dp_tipo_avaliador;


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 2: Tipos de Cálculo — apenas metadados de UI (algoritmos permanecem no motor)
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE dp_tipos_calculo_config (
  codigo    TEXT    PRIMARY KEY,  -- corresponde ao valor do ENUM dp_tipo_calculo (imutável)
  label     TEXT    NOT NULL,
  descricao TEXT,
  ativo     BOOLEAN NOT NULL DEFAULT true,
  ordem     SMALLINT NOT NULL DEFAULT 0
);

INSERT INTO dp_tipos_calculo_config (codigo, label, descricao, ordem) VALUES
  ('media',
   'Média',
   'Soma das notas dividida pelo número de critérios calculáveis. Todos os critérios têm peso igual.',
   1),
  ('media_ponderada',
   'Média Ponderada',
   'Cada critério contribui proporcionalmente ao seu peso. Exige peso definido em todos os critérios calculáveis.',
   2),
  ('soma',
   'Soma',
   'Soma direta das notas de todos os critérios calculáveis, sem divisão.',
   3),
  ('percentual_atingimento',
   '% de Atingimento',
   'Compara o realizado com a meta definida para cada critério. Exige tipo de resposta "Numérico com meta" em todos os critérios calculáveis.',
   4),
  ('qualitativo',
   'Qualitativo',
   'Sem nota numérica final. A avaliação é expressa por texto, conceito ou observação.',
   5);


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 3: Tabelas de Conceito — substituir JSONB faixas_conceito em dp_versoes
-- ═══════════════════════════════════════════════════════════════════════════════

CREATE TABLE dp_tabelas_conceito (
  id        UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  nome      TEXT        NOT NULL,
  descricao TEXT,
  ativo     BOOLEAN     NOT NULL DEFAULT true,
  criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE dp_faixas_conceito (
  id         UUID     PRIMARY KEY DEFAULT gen_random_uuid(),
  tabela_id  UUID     NOT NULL REFERENCES dp_tabelas_conceito(id) ON DELETE CASCADE,
  nota_min   NUMERIC  NOT NULL,
  nota_max   NUMERIC  NOT NULL,
  conceito   TEXT     NOT NULL,
  descricao  TEXT,
  cor        TEXT,                   -- ex: '#E53E3E' — opcional, para UI colorida
  ordem      SMALLINT NOT NULL,
  UNIQUE (tabela_id, ordem),
  CONSTRAINT faixa_intervalo_valido CHECK (nota_min <= nota_max)
);

-- Trigger de imutabilidade — mesmo padrão de dp_escala_opcoes (migration 065)
-- Bloqueia alteração em faixas quando a tabela está em uso por versão publicada
CREATE OR REPLACE FUNCTION dp_fn_faixas_conceito_proteger()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE v_tabela_id UUID;
BEGIN
  v_tabela_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.tabela_id ELSE NEW.tabela_id END;
  IF EXISTS (
    SELECT 1 FROM dp_versoes WHERE tabela_conceito_id = v_tabela_id AND em_uso = true
  ) THEN
    RAISE EXCEPTION 'Tabela de conceito em uso por versão publicada. Crie uma nova tabela para configurações diferentes.';
  END IF;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION dp_fn_tabela_conceito_proteger_delete()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM dp_versoes WHERE tabela_conceito_id = OLD.id AND em_uso = true
  ) THEN
    RAISE EXCEPTION 'Tabela de conceito em uso por versão publicada e não pode ser removida.';
  END IF;
  RETURN OLD;
END;
$$;

CREATE TRIGGER trg_fc_proteger_em_uso
  BEFORE INSERT OR UPDATE OR DELETE ON dp_faixas_conceito
  FOR EACH ROW EXECUTE FUNCTION dp_fn_faixas_conceito_proteger();

CREATE TRIGGER trg_tc_proteger_delete
  BEFORE DELETE ON dp_tabelas_conceito
  FOR EACH ROW EXECUTE FUNCTION dp_fn_tabela_conceito_proteger_delete();

-- Alterar dp_versoes: remover JSONB, adicionar FK para tabela de conceito
-- Pré-condição: nenhuma versão publicada existe — sem dados a migrar
ALTER TABLE dp_versoes
  DROP COLUMN faixas_conceito,
  ADD COLUMN tabela_conceito_id UUID REFERENCES dp_tabelas_conceito(id);

-- converte_para_conceito permanece: indica que esta versão usa conversão
-- Regra: se converte_para_conceito = true, tabela_conceito_id deve estar preenchido
-- (validado pela função dp_validar_versao — atualizar na UI após esta migration)


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 4: Snapshot do nome do critério ao publicar versão
-- ═══════════════════════════════════════════════════════════════════════════════

ALTER TABLE dp_versao_criterios
  ADD COLUMN criterio_nome_snapshot TEXT;

-- Trigger: quando versão é publicada (em_uso muda para true),
-- copia o nome atual de cada critério para o snapshot.
-- Garante que renomear um critério depois não afeta histórico de avaliações.
CREATE OR REPLACE FUNCTION dp_fn_versao_snapshot_criterios()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.em_uso = true AND (OLD.em_uso IS DISTINCT FROM true) THEN
    UPDATE dp_versao_criterios vc
    SET criterio_nome_snapshot = c.nome
    FROM dp_criterios c
    WHERE vc.versao_id = NEW.id
      AND vc.criterio_id = c.id
      AND vc.criterio_nome_snapshot IS NULL;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_versao_snapshot_criterios
  AFTER UPDATE OF em_uso ON dp_versoes
  FOR EACH ROW EXECUTE FUNCTION dp_fn_versao_snapshot_criterios();


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 5: Mover elegibilidade de dp_versoes para dp_ciclos
-- ═══════════════════════════════════════════════════════════════════════════════
-- Justificativa: elegibilidade é decisão operacional de cada ciclo,
-- não estrutural do modelo. O mesmo modelo pode servir ciclos com públicos diferentes.
-- Verificado: nenhuma referência no código JS. Nenhum dado existente nos campos.

ALTER TABLE dp_ciclos
  ADD COLUMN tipo_elegibilidade  dp_tipo_elegibilidade NOT NULL DEFAULT 'todos',
  ADD COLUMN elegibilidade_ids   UUID[];

ALTER TABLE dp_versoes
  DROP COLUMN tipo_elegibilidade,
  DROP COLUMN elegibilidade_ids;


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 6: GRANTs para as novas tabelas
-- (mesmo padrão da migration 066)
-- ═══════════════════════════════════════════════════════════════════════════════

GRANT SELECT, INSERT, UPDATE, DELETE ON
  dp_tipos_avaliador,
  dp_tipos_calculo_config,
  dp_tabelas_conceito,
  dp_faixas_conceito
TO anon, authenticated;

NOTIFY pgrst, 'reload schema';


-- ═══════════════════════════════════════════════════════════════════════════════
-- BLOCO 7: Validação (executar após os blocos acima e verificar resultados)
-- ═══════════════════════════════════════════════════════════════════════════════

-- Verificar tipos de avaliador migrados (esperado: 4 linhas)
-- SELECT codigo, label, ativo FROM dp_tipos_avaliador ORDER BY ordem;

-- Verificar tipos de cálculo configurados (esperado: 5 linhas)
-- SELECT codigo, label, ativo FROM dp_tipos_calculo_config ORDER BY ordem;

-- Verificar estrutura de dp_versoes (não deve mais ter faixas_conceito, tipo_elegibilidade, elegibilidade_ids)
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'dp_versoes' ORDER BY ordinal_position;

-- Verificar estrutura de dp_ciclos (deve ter tipo_elegibilidade e elegibilidade_ids)
-- SELECT column_name FROM information_schema.columns WHERE table_name = 'dp_ciclos' ORDER BY ordinal_position;

-- Verificar triggers criados (esperado: trg_fc_proteger_em_uso, trg_tc_proteger_delete, trg_versao_snapshot_criterios)
-- SELECT trigger_name, event_object_table FROM information_schema.triggers
-- WHERE trigger_name LIKE 'trg_%' AND trigger_name NOT IN
--   ('trg_eo_proteger_em_uso','trg_e_proteger_delete','trg_vc_proteger_em_uso',
--    'trg_vb_proteger_em_uso','trg_resposta_snapshot')
-- ORDER BY trigger_name;
