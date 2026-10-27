-- Migration 140: PDI — Planos de Desenvolvimento
-- Cria tabelas pdi_planos e pdi_config, migra dados de dev_pdi, habilita RLS.
-- ⚠ EXECUTAR MANUALMENTE no Supabase Dashboard → SQL Editor
-- dev_pdi é preservada (não excluída); novas gravações vão para pdi_planos.

-- ─── 1. Tabela pdi_planos ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS pdi_planos (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  matricula_colaborador text        NOT NULL,
  titulo                text        NOT NULL,
  gatilho               text,
  ciclo_id              uuid,       -- referência soft a dp_ciclos.id (sem FK para flexibilidade)
  avaliacao_id          uuid,       -- referência soft a dp_avaliacoes.id
  dev_historico_id      uuid,       -- referência soft a dev_historico.id
  criado_por            text,
  responsavel           text,
  status                text        NOT NULL DEFAULT 'ativo',
  acoes                 jsonb       NOT NULL DEFAULT '[]',
  observacoes           text,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- ─── 2. Tabela pdi_config (linha única — parâmetros editáveis pelo RH) ──────
CREATE TABLE IF NOT EXISTS pdi_config (
  id    int  PRIMARY KEY DEFAULT 1,
  dados jsonb NOT NULL DEFAULT '{
    "gatilhos": ["Resultado de avaliação","Feedback/anotação","Iniciativa do gestor","Iniciativa RH","Outro"],
    "categorias_acao": ["Técnica","Comportamental","Liderança","Processo","Comunicação","Outro"],
    "status_opcoes": ["ativo","concluido","arquivado"]
  }'::jsonb
);
INSERT INTO pdi_config (id) VALUES (1) ON CONFLICT DO NOTHING;

-- ─── 3. Migrar dados de dev_pdi → pdi_planos ────────────────────────────────
-- dev_pdi.ciclo_id referencia dev_ciclos (tabela legada), não dp_ciclos.
-- Por isso ciclo_id é definido como NULL nos registros migrados.
-- Apenas registros com pelo menos uma ação são migrados.
INSERT INTO pdi_planos (
  matricula_colaborador, titulo, gatilho, ciclo_id, acoes, status, created_at
)
SELECT
  dp.matricula_colaborador,
  CASE
    WHEN dp.ciclo_id IS NOT NULL THEN
      'PDI — ' || COALESCE(
        (SELECT nome FROM dev_ciclos WHERE id::text = dp.ciclo_id::text LIMIT 1),
        dp.ciclo_id::text
      )
    ELSE 'PDI (ciclo não identificado)'
  END AS titulo,
  'Resultado de avaliação' AS gatilho,
  NULL::uuid               AS ciclo_id,   -- dev_ciclos ≠ dp_ciclos; não migrar referência
  COALESCE(dp.acoes, '[]'::jsonb),
  CASE
    WHEN dp.acoes IS NULL OR jsonb_array_length(dp.acoes) = 0 THEN 'ativo'
    WHEN NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(dp.acoes) a
      WHERE NOT ((a->>'done') IS DISTINCT FROM 'true')
    ) THEN 'concluido'
    ELSE 'ativo'
  END AS status,
  now()
FROM dev_pdi dp
WHERE dp.acoes IS NOT NULL AND jsonb_array_length(dp.acoes) > 0
ON CONFLICT DO NOTHING;

-- ─── 4. RLS em pdi_planos ────────────────────────────────────────────────────
ALTER TABLE pdi_planos ENABLE ROW LEVEL SECURITY;

-- RH/admin: CRUD irrestrito
CREATE POLICY pdi_rh_all ON pdi_planos
  USING      (auth_perfil() IN ('rh','admin'))
  WITH CHECK (auth_perfil() IN ('rh','admin'));

-- Diretoria: somente leitura
CREATE POLICY pdi_diretoria_sel ON pdi_planos FOR SELECT
  USING (auth_perfil() = 'diretoria');

-- Gestor: lê e escreve apenas PDIs de sua equipe
-- (mesma lógica de colaboradores.gestor ILIKE param_gestor.apelido usada em migration 113)
CREATE POLICY pdi_gestor_sel ON pdi_planos FOR SELECT
  USING (
    auth_perfil() = 'gestor' AND
    matricula_colaborador IN (
      SELECT c.matricula FROM colaboradores c
      WHERE c.gestor ILIKE (
        SELECT pg.apelido FROM param_gestor pg
        WHERE pg.user_id = auth.uid() LIMIT 1
      )
    )
  );

CREATE POLICY pdi_gestor_ins ON pdi_planos FOR INSERT
  WITH CHECK (
    auth_perfil() = 'gestor' AND
    matricula_colaborador IN (
      SELECT c.matricula FROM colaboradores c
      WHERE c.gestor ILIKE (
        SELECT pg.apelido FROM param_gestor pg
        WHERE pg.user_id = auth.uid() LIMIT 1
      )
    )
  );

CREATE POLICY pdi_gestor_upd ON pdi_planos FOR UPDATE
  USING (
    auth_perfil() = 'gestor' AND
    matricula_colaborador IN (
      SELECT c.matricula FROM colaboradores c
      WHERE c.gestor ILIKE (
        SELECT pg.apelido FROM param_gestor pg
        WHERE pg.user_id = auth.uid() LIMIT 1
      )
    )
  )
  WITH CHECK (
    auth_perfil() = 'gestor' AND
    matricula_colaborador IN (
      SELECT c.matricula FROM colaboradores c
      WHERE c.gestor ILIKE (
        SELECT pg.apelido FROM param_gestor pg
        WHERE pg.user_id = auth.uid() LIMIT 1
      )
    )
  );

-- ─── 5. RLS em pdi_config ────────────────────────────────────────────────────
ALTER TABLE pdi_config ENABLE ROW LEVEL SECURITY;

-- Todos os perfis autenticados leem a configuração
CREATE POLICY pdi_config_sel ON pdi_config FOR SELECT USING (true);

-- Apenas RH/admin alteram
CREATE POLICY pdi_config_rh ON pdi_config
  USING      (auth_perfil() IN ('rh','admin'))
  WITH CHECK (auth_perfil() IN ('rh','admin'));

-- ─── Verificação após execução ────────────────────────────────────────────────
-- SELECT COUNT(*) FROM pdi_planos;
-- SELECT COUNT(*) FROM pdi_config;
-- SELECT COUNT(*) FROM dev_pdi;   -- deve permanecer intacta
