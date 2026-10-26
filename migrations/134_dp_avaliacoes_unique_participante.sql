-- Migration 134: unique constraint em dp_avaliacoes.participante_id
-- Impede que condições de corrida (duplo clique, requisições paralelas)
-- criem duas avaliações para o mesmo participante.
--
-- Pré-requisito: não deve existir nenhuma duplicata em dp_avaliacoes.
-- Verificar antes de executar:
--   SELECT participante_id, COUNT(*) FROM dp_avaliacoes
--   GROUP BY participante_id HAVING COUNT(*) > 1;
-- Se retornar linhas, limpar as duplicatas primeiro.
--
-- NÃO EXECUTAR sem aprovação explícita da usuária.

ALTER TABLE dp_avaliacoes
  ADD CONSTRAINT dp_avaliacoes_participante_id_key UNIQUE (participante_id);
