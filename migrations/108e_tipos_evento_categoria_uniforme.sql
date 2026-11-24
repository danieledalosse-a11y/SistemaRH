-- Migration 108-E — expande CHECK constraint de tipos_evento.categoria e reclassifica tipos de uniforme
-- Motivo: categoria 'uniforme' separa os tipos de movimentação de uniforme/EPI dos eventos funcionais,
-- permitindo que a aba "Uniformes e EPIs" da Ficha filtre por categoria sem lista hardcoded no frontend.

ALTER TABLE tipos_evento
  DROP CONSTRAINT tipos_evento_categoria_check;

ALTER TABLE tipos_evento
  ADD CONSTRAINT tipos_evento_categoria_check
  CHECK (categoria = ANY (ARRAY[
    'financeiro', 'carreira', 'beneficio', 'ausencia',
    'cadastro', 'desempenho', 'uniforme'
  ]));

UPDATE tipos_evento
  SET categoria = 'uniforme'
WHERE codigo IN ('entrega_uniforme', 'devolucao_uniforme');
