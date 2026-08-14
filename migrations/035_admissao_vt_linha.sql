-- Migration 035: Add vt_linha to admissao_fichas
ALTER TABLE admissao_fichas
  ADD COLUMN IF NOT EXISTS vt_linha TEXT;
