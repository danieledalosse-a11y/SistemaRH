-- Migration 099 — Tipo de evento: entrega_uniforme
-- Fase D: integração de unif_movimentacoes ao historico_eventos.
-- Representa uma entrega de uniformes agregada por (colaborador, data, motivo).
-- EPI ainda não existe no catálogo — será tratado em migração futura com tipo próprio.

INSERT INTO tipos_evento (
  codigo,
  label,
  categoria,
  icone_chave,
  cor_hex,
  dados_schema,
  resumo_template,
  ativo
)
VALUES (
  'entrega_uniforme',
  'Entrega de Uniforme',
  'cadastro',
  'shirt',
  '#026AA2',
  '{
    "type": "object",
    "required": ["motivo", "total_itens", "itens"],
    "properties": {
      "motivo":      { "type": "string" },
      "total_itens": { "type": "integer", "minimum": 1 },
      "itens": {
        "type": "array",
        "items": {
          "type": "object",
          "required": ["nome", "quantidade"],
          "properties": {
            "nome":       { "type": "string" },
            "variante":   { "type": ["string", "null"] },
            "tamanho":    { "type": ["string", "null"] },
            "quantidade": { "type": "integer", "minimum": 1 }
          }
        }
      }
    }
  }',
  '{{total_itens}} ite(m|ns) — {{motivo}}',
  true
)
ON CONFLICT (codigo) DO UPDATE SET
  label            = EXCLUDED.label,
  categoria        = EXCLUDED.categoria,
  icone_chave      = EXCLUDED.icone_chave,
  cor_hex          = EXCLUDED.cor_hex,
  dados_schema     = EXCLUDED.dados_schema,
  resumo_template  = EXCLUDED.resumo_template,
  ativo            = EXCLUDED.ativo;
