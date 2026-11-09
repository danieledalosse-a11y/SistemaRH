-- Migration 145: Módulo Horas Extras — tabelas he_importacoes e he_registros
--
-- Estratégia:
--   he_importacoes: uma linha por empresa por competência por importação.
--     ativo=true identifica a versão vigente; substituições recebem ativo=false (histórico preservado).
--   he_registros: um por colaborador por importação.
--     colaborador_id nullable — registros ambíguos ou não encontrados gravam sem vínculo.
--     percentuais JSONB — estrutura flexível para 50/60/70/80/85/100% sem colunas fixas.
--
-- Tabelas existentes utilizadas (sem alteração):
--   param_empresa  → empresa de origem dos PDFs
--   colaboradores  → vínculo de matrícula com colaborador do sistema

CREATE TABLE IF NOT EXISTS public.he_importacoes (
  id               uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  competencia      text        NOT NULL,                             -- 'YYYY-MM'
  param_empresa_id integer     NOT NULL REFERENCES public.param_empresa(id),
  arquivo_nome     text,
  versao           integer     NOT NULL DEFAULT 1,
  ativo            boolean     NOT NULL DEFAULT true,
  importado_em     timestamptz NOT NULL DEFAULT now(),
  importado_por    text,
  total_colabs     integer,
  total_horas      numeric(10,2),
  total_valor      numeric(12,2),
  obs              text
);

CREATE TABLE IF NOT EXISTS public.he_registros (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  importacao_id   uuid        NOT NULL REFERENCES public.he_importacoes(id) ON DELETE CASCADE,
  colaborador_id  integer     REFERENCES public.colaboradores(id),  -- nullable
  matricula_pdf   text        NOT NULL,
  empresa_codigo  text        NOT NULL,
  competencia     text        NOT NULL,                             -- denormalizado
  percentuais     jsonb       NOT NULL DEFAULT '{}',
  dsr_quant       numeric(10,2) NOT NULL DEFAULT 0,
  dsr_valor       numeric(12,2) NOT NULL DEFAULT 0,
  total_quant     numeric(10,2) NOT NULL DEFAULT 0,
  total_valor     numeric(12,2) NOT NULL DEFAULT 0,
  status_vinculo  text        NOT NULL DEFAULT 'vinculado'
    CHECK (status_vinculo IN ('vinculado','inativo','ambiguo','nao_encontrado'))
);

CREATE INDEX IF NOT EXISTS he_importacoes_competencia_idx  ON public.he_importacoes(competencia);
CREATE INDEX IF NOT EXISTS he_importacoes_empresa_idx      ON public.he_importacoes(param_empresa_id);
CREATE INDEX IF NOT EXISTS he_importacoes_ativo_idx        ON public.he_importacoes(ativo);
CREATE INDEX IF NOT EXISTS he_registros_importacao_idx     ON public.he_registros(importacao_id);
CREATE INDEX IF NOT EXISTS he_registros_colaborador_idx    ON public.he_registros(colaborador_id);
CREATE INDEX IF NOT EXISTS he_registros_competencia_idx    ON public.he_registros(competencia);

ALTER TABLE public.he_importacoes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.he_registros   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "he_importacoes_sel" ON public.he_importacoes FOR SELECT TO authenticated USING (true);
CREATE POLICY "he_importacoes_ins" ON public.he_importacoes FOR INSERT TO authenticated WITH CHECK (true);
CREATE POLICY "he_importacoes_upd" ON public.he_importacoes FOR UPDATE TO authenticated USING (true);

CREATE POLICY "he_registros_sel"   ON public.he_registros   FOR SELECT TO authenticated USING (true);
CREATE POLICY "he_registros_ins"   ON public.he_registros   FOR INSERT TO authenticated WITH CHECK (true);
