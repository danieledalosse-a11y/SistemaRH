-- ─── Adiciona variante e logo ao catálogo de uniformes ───────────────────────

ALTER TABLE unif_catalogo
  ADD COLUMN IF NOT EXISTS variante TEXT,   -- ex: Manga Curta, Com Forro, Sem Forro
  ADD COLUMN IF NOT EXISTS logo     TEXT;   -- ex: Logo Grupo Revest, Logo Revest Acabamentos, Jovem Aprendiz

-- Limpa dados importados incorretamente (reimportação virá em seguida)
TRUNCATE unif_movimentacoes, unif_estoque, unif_entradas, unif_kits, unif_catalogo RESTART IDENTITY CASCADE;
