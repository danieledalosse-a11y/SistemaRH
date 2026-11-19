-- Migration 147: Módulo Horas Extras — Eventos e Ocorrências
--
-- Cria he_config (tipos configuráveis pelo RH) e he_eventos.
-- Sem FK estrutural para he_importacoes/he_registros — relação é temporal.
-- Soft delete via ativo=false (sem DELETE real).
-- RLS garante visibilidade por perfil no banco, não só na interface:
--   rh/admin   → vê todos (ativos e inativos)
--   diretoria  → vê todos os ativos
--   gestor     → ativos globais + ativos de empresa/setor da sua equipe
--                (setor exige match de empresa_id também — sem falso positivo
--                 por nome de setor coincidente em outra empresa)
--
-- Dependências:
--   param_empresa  — referenciada por he_eventos.empresa_id
--   colaboradores  — referenciada por auth_gestor_equipe_ids()
--   auth_perfil()  — função de perfil existente (migration anterior)
--   auth_gestor_equipe_ids() — função existente (migration 113)

-- ─── 1. he_config ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.he_config (
  id    int PRIMARY KEY DEFAULT 1,
  dados jsonb NOT NULL DEFAULT '{
    "tipos_evento": [
      "Campanha de vendas",
      "Balanço / inventário",
      "Ação comercial",
      "Data comemorativa / evento",
      "Demanda extraordinária",
      "Reforço operacional",
      "Outro"
    ]
  }'::jsonb
);
INSERT INTO public.he_config (id) VALUES (1) ON CONFLICT DO NOTHING;

ALTER TABLE public.he_config ENABLE ROW LEVEL SECURITY;

-- Todos os perfis autenticados leem a configuração
CREATE POLICY he_config_sel ON public.he_config FOR SELECT USING (true);

-- Apenas RH/admin alteram
CREATE POLICY he_config_upd ON public.he_config
  FOR UPDATE USING (auth_perfil() IN ('rh','admin'));

-- ─── 2. he_eventos ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.he_eventos (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  titulo        text        NOT NULL,
  tipo          text        NOT NULL,
  data_inicio   date        NOT NULL,
  data_fim      date        NOT NULL,
  descricao     text,
  abrangencia   text        NOT NULL DEFAULT 'global'
                            CHECK (abrangencia IN ('global','empresa','setor')),
  empresa_id    integer     REFERENCES public.param_empresa(id),
  setor         text,
  criado_por    text,
  criado_em     timestamptz NOT NULL DEFAULT now(),
  inativado_em  timestamptz,
  inativado_por text,
  ativo         boolean     NOT NULL DEFAULT true,

  -- Banco garante integridade referencial por abrangência,
  -- independente da interface
  CONSTRAINT he_eventos_chk_data    CHECK (data_fim >= data_inicio),
  CONSTRAINT he_eventos_chk_empresa CHECK (abrangencia <> 'empresa' OR empresa_id IS NOT NULL),
  CONSTRAINT he_eventos_chk_setor   CHECK (abrangencia <> 'setor'  OR (empresa_id IS NOT NULL AND setor IS NOT NULL))
);

CREATE INDEX IF NOT EXISTS he_eventos_data_idx  ON public.he_eventos(data_inicio, data_fim);
CREATE INDEX IF NOT EXISTS he_eventos_ativo_idx ON public.he_eventos(ativo);

ALTER TABLE public.he_eventos ENABLE ROW LEVEL SECURITY;

-- rh/admin: vê todos os eventos (ativos e inativos) para gestão do histórico
CREATE POLICY he_eventos_sel_rh ON public.he_eventos
  FOR SELECT
  USING (auth_perfil() IN ('rh','admin'));

-- diretoria: todos os ativos
CREATE POLICY he_eventos_sel_dir ON public.he_eventos
  FOR SELECT
  USING (auth_perfil() = 'diretoria' AND ativo = true);

-- gestor: ativos globais + ativos de empresa/setor da sua equipe
-- Setor exige empresa_id correspondente para evitar falso positivo
-- por nome de setor coincidente em outra empresa
CREATE POLICY he_eventos_sel_ges ON public.he_eventos
  FOR SELECT
  USING (
    auth_perfil() = 'gestor' AND ativo = true AND (
      abrangencia = 'global'
      OR (
        abrangencia = 'empresa'
        AND empresa_id IN (
          SELECT pe.id
            FROM public.param_empresa pe
            JOIN public.colaboradores c ON c.empresa_registro = pe.nome_simplificado
           WHERE c.id = ANY(SELECT auth_gestor_equipe_ids())
        )
      )
      OR (
        abrangencia = 'setor'
        AND EXISTS (
          SELECT 1
            FROM public.colaboradores c
            JOIN public.param_empresa pe ON c.empresa_registro = pe.nome_simplificado
           WHERE c.id = ANY(SELECT auth_gestor_equipe_ids())
             AND pe.id  = he_eventos.empresa_id  -- mesma empresa
             AND c.setor = he_eventos.setor       -- mesmo setor
        )
      )
    )
  );

-- INSERT/UPDATE: somente rh/admin
-- (UPDATE cobre a inativação — ativo=false — e reativação)
CREATE POLICY he_eventos_ins ON public.he_eventos
  FOR INSERT WITH CHECK (auth_perfil() IN ('rh','admin'));

CREATE POLICY he_eventos_upd ON public.he_eventos
  FOR UPDATE USING (auth_perfil() IN ('rh','admin'));

-- DELETE bloqueado para todos: sem policy = bloqueado
-- Inativação é feita via PATCH ativo=false (coberto pela policy de UPDATE)

GRANT SELECT, INSERT, UPDATE ON public.he_config  TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.he_eventos TO authenticated;
