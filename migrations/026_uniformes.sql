-- ─── Módulo de Uniformes & EPI ───────────────────────────────────────────────

-- Almoxarifados
CREATE TABLE IF NOT EXISTS unif_almoxarifados (
  id   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome TEXT NOT NULL,
  empresa TEXT,
  obs  TEXT,
  ativo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Seeder: 2 almoxarifados da Revest
INSERT INTO unif_almoxarifados (nome, empresa, obs) VALUES
  ('Almoxarifado CD',     '2148 - Centro de Distribuição', 'Exclusivo para equipe de logística'),
  ('Almoxarifado Matriz', '148 - Matriz',                  'Almoxarifado central — abastece todas as filiais')
ON CONFLICT DO NOTHING;

-- Catálogo de itens (uniformes e EPIs)
CREATE TABLE IF NOT EXISTS unif_catalogo (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nome                TEXT NOT NULL,
  tipo                TEXT NOT NULL CHECK (tipo IN ('uniforme', 'epi')),
  categoria           TEXT,                          -- ex: camisa, calça, bota, capacete
  sistema_tamanho     TEXT NOT NULL DEFAULT 'letra'
                      CHECK (sistema_tamanho IN ('letra', 'numerico', 'unico')),
  -- letra = P/M/G/GG/XG  |  numerico = 34/36/38…  |  unico = tamanho único
  ca_numero           TEXT,                          -- obrigatório para EPIs (Certificado de Aprovação)
  prazo_troca_meses   INTEGER DEFAULT 24,            -- padrão 2 anos; ajustável por item
  ativo               BOOLEAN DEFAULT true,
  created_at          TIMESTAMPTZ DEFAULT now(),
  updated_at          TIMESTAMPTZ DEFAULT now()
);

-- Kits padrão por cargo (admissão)
CREATE TABLE IF NOT EXISTS unif_kits (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cargo      TEXT NOT NULL,
  item_id    UUID NOT NULL REFERENCES unif_catalogo(id) ON DELETE CASCADE,
  quantidade INTEGER NOT NULL DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(cargo, item_id)
);

-- Estoque por almoxarifado × item × tamanho
CREATE TABLE IF NOT EXISTS unif_estoque (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  almoxarifado_id   UUID NOT NULL REFERENCES unif_almoxarifados(id),
  item_id           UUID NOT NULL REFERENCES unif_catalogo(id) ON DELETE CASCADE,
  tamanho           TEXT NOT NULL,
  quantidade        INTEGER NOT NULL DEFAULT 0 CHECK (quantidade >= 0),
  estoque_minimo    INTEGER DEFAULT 2,
  updated_at        TIMESTAMPTZ DEFAULT now(),
  UNIQUE(almoxarifado_id, item_id, tamanho)
);

-- Movimentações: entregas e devoluções por colaborador
CREATE TABLE IF NOT EXISTS unif_movimentacoes (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  colaborador_id          INTEGER NOT NULL REFERENCES colaboradores(id),
  item_id                 UUID NOT NULL REFERENCES unif_catalogo(id),
  almoxarifado_id         UUID REFERENCES unif_almoxarifados(id),
  tipo                    TEXT NOT NULL CHECK (tipo IN ('entrega', 'devolucao')),
  motivo                  TEXT NOT NULL,
  -- admissao | troca_programada | troca_antecipada | demissao | ajuste
  tamanho                 TEXT NOT NULL,
  quantidade              INTEGER NOT NULL DEFAULT 1,
  ca_numero_lote          TEXT,                    -- CA do lote entregue (EPI)
  data_movimentacao       DATE NOT NULL DEFAULT CURRENT_DATE,
  confirmado              BOOLEAN DEFAULT false,
  confirmado_em           TIMESTAMPTZ,
  confirmacao_token       TEXT UNIQUE,             -- token para link de confirmação
  registrado_por          TEXT,
  solicitacao_id          UUID,                    -- ref para unif_solicitacoes
  obs                     TEXT,
  created_at              TIMESTAMPTZ DEFAULT now()
);

-- Solicitações de troca (pelo colaborador)
CREATE TABLE IF NOT EXISTS unif_solicitacoes (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  colaborador_id    INTEGER NOT NULL REFERENCES colaboradores(id),
  item_id           UUID NOT NULL REFERENCES unif_catalogo(id),
  tamanho_atual     TEXT,
  tamanho_solicitado TEXT,
  motivo            TEXT NOT NULL,                 -- obrigatório em trocas antecipadas
  tipo              TEXT NOT NULL
                    CHECK (tipo IN ('troca_antecipada', 'reposicao_normal')),
  status            TEXT NOT NULL DEFAULT 'pendente'
                    CHECK (status IN ('pendente','aprovado','rejeitado','entregue','cancelado')),
  aprovado_por      TEXT,
  aprovado_em       TIMESTAMPTZ,
  obs_rh            TEXT,
  movimentacao_id   UUID REFERENCES unif_movimentacoes(id),
  created_at        TIMESTAMPTZ DEFAULT now(),
  updated_at        TIMESTAMPTZ DEFAULT now()
);

-- Índices úteis
CREATE INDEX IF NOT EXISTS idx_unif_mov_colab    ON unif_movimentacoes(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_unif_mov_item     ON unif_movimentacoes(item_id);
CREATE INDEX IF NOT EXISTS idx_unif_sol_colab    ON unif_solicitacoes(colaborador_id);
CREATE INDEX IF NOT EXISTS idx_unif_sol_status   ON unif_solicitacoes(status);
CREATE INDEX IF NOT EXISTS idx_unif_estoque_alm  ON unif_estoque(almoxarifado_id);

-- RLS: habilitar (ajustar policies conforme perfis do sistema)
ALTER TABLE unif_almoxarifados  ENABLE ROW LEVEL SECURITY;
ALTER TABLE unif_catalogo       ENABLE ROW LEVEL SECURITY;
ALTER TABLE unif_kits           ENABLE ROW LEVEL SECURITY;
ALTER TABLE unif_estoque        ENABLE ROW LEVEL SECURITY;
ALTER TABLE unif_movimentacoes  ENABLE ROW LEVEL SECURITY;
ALTER TABLE unif_solicitacoes   ENABLE ROW LEVEL SECURITY;

-- Policy permissiva temporária (authenticated)
DO $$ DECLARE t TEXT;
BEGIN FOR t IN SELECT unnest(ARRAY[
  'unif_almoxarifados','unif_catalogo','unif_kits',
  'unif_estoque','unif_movimentacoes','unif_solicitacoes'
]) LOOP
  EXECUTE format('CREATE POLICY "auth_all_%s" ON %I FOR ALL TO authenticated USING (true) WITH CHECK (true)', t, t);
END LOOP; END $$;
