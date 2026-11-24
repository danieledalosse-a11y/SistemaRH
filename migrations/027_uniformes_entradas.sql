-- ─── Evolução do módulo Uniformes: entradas de lote + gênero + custo médio ────

-- 1. Gênero no catálogo
ALTER TABLE unif_catalogo
  ADD COLUMN IF NOT EXISTS genero TEXT DEFAULT 'unissex'
    CHECK (genero IN ('masculino','feminino','unissex'));

-- 2. Custo médio no estoque
ALTER TABLE unif_estoque
  ADD COLUMN IF NOT EXISTS custo_medio NUMERIC(10,2) DEFAULT 0;

-- 3. Tabela de entradas de lote (compras)
CREATE TABLE IF NOT EXISTS unif_entradas (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_id         UUID NOT NULL REFERENCES unif_catalogo(id) ON DELETE CASCADE,
  almoxarifado_id UUID NOT NULL REFERENCES unif_almoxarifados(id),
  fornecedor      TEXT NOT NULL,
  tamanho         TEXT NOT NULL,
  quantidade      INTEGER NOT NULL CHECK (quantidade > 0),
  valor_unitario  NUMERIC(10,2) NOT NULL CHECK (valor_unitario >= 0),
  logo_bordada    BOOLEAN DEFAULT false,
  data_entrada    DATE NOT NULL DEFAULT CURRENT_DATE,
  nf              TEXT,                          -- número da nota fiscal
  obs             TEXT,
  status          TEXT NOT NULL DEFAULT 'ativo'
                  CHECK (status IN ('ativo','encerrado')),
  registrado_por  TEXT,
  created_at      TIMESTAMPTZ DEFAULT now()
);

-- Índices
CREATE INDEX IF NOT EXISTS idx_unif_ent_item    ON unif_entradas(item_id);
CREATE INDEX IF NOT EXISTS idx_unif_ent_fornec  ON unif_entradas(fornecedor);
CREATE INDEX IF NOT EXISTS idx_unif_ent_status  ON unif_entradas(status);

-- RLS
ALTER TABLE unif_entradas ENABLE ROW LEVEL SECURITY;
CREATE POLICY "auth_all_unif_entradas" ON unif_entradas
  FOR ALL TO authenticated USING (true) WITH CHECK (true);
