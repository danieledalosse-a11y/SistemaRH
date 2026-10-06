-- Migration 075 — Tabela historico_remuneracao
-- Histórico oficial de alterações salariais e de cargo.
-- Fonte única de verdade para: aba Financeiro da Ficha, eSocial futuro (S-2206),
-- e rastreabilidade de reajustes originados pelo módulo Processos.

CREATE TABLE historico_remuneracao (

  -- Identidade
  id                BIGSERIAL     PRIMARY KEY,
  colaborador_id    BIGINT        NOT NULL REFERENCES colaboradores(id),
  processo_id       BIGINT        REFERENCES processos_rh(id),
  -- null = admissão inicial ou correção manual sem processo vinculado

  -- O que mudou
  data_vigencia     DATE          NOT NULL,
  salario_anterior  NUMERIC(12,2),
  -- null apenas no primeiro registro (admissão sem histórico prévio)
  salario_novo      NUMERIC(12,2) NOT NULL,
  percentual        NUMERIC(6,2),
  -- recalculado no momento da aplicação; null quando salario_anterior é null
  cargo_anterior    TEXT,
  cargo_novo        TEXT,
  -- null quando não houve mudança de cargo no reajuste

  -- Contexto
  motivo_codigo     TEXT,
  motivo_descricao  TEXT,
  observacao        TEXT,

  -- Rastreabilidade
  registrado_por    TEXT          NOT NULL,
  registrado_em     TIMESTAMPTZ   NOT NULL DEFAULT NOW(),

  -- Quando o salário efetivamente entrou em vigor em colaboradores.salario
  aplicado_em       TIMESTAMPTZ,
  -- null enquanto data_vigencia > hoje (aguardando cron ou lazy load)

  -- Estorno futuro (estrutura preparada; sem implementação agora)
  estornado         BOOLEAN       NOT NULL DEFAULT FALSE,
  estorno_id        BIGINT        REFERENCES historico_remuneracao(id),
  -- aponta para o registro de estorno quando existir; registro original nunca deletado

  -- eSocial futuro (evento S-2206 — Alteração de Contrato de Trabalho)
  esocial_enviado   BOOLEAN       NOT NULL DEFAULT FALSE,

  -- Idempotência: um processo gera exatamente um registro por colaborador
  CONSTRAINT uq_hr_processo UNIQUE (colaborador_id, processo_id)

);

-- Índice usado pelo cron diário e pelo lazy load ao carregar colaborador:
-- busca rápida de reajustes com vigência vencida ainda não aplicados.
CREATE INDEX idx_hr_pendentes
  ON historico_remuneracao (colaborador_id, data_vigencia)
  WHERE aplicado_em IS NULL AND estornado = FALSE;

-- Índice para consultas da aba Financeiro na Ficha (histórico por colaborador).
CREATE INDEX idx_hr_colaborador
  ON historico_remuneracao (colaborador_id, data_vigencia DESC);
