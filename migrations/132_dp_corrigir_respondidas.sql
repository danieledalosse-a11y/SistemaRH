-- Migration 132: corrige status de avaliações em_andamento que já têm
-- todos os critérios obrigatórios respondidos → respondida.
--
-- Contexto: o status 'respondida' foi criado na migration 130. Avaliações
-- salvas antes dessa migration permaneceram com 'em_andamento' mesmo estando
-- totalmente preenchidas. Esta migration corrige esses registros.
--
-- Impacto verificado em 2026-10-16:
--   9 avaliações alteradas (ciclo Gratificação CD - Setembro/2026)
--   1 avaliação permanece em_andamento (9/10 critérios — realmente incompleta)
--   0 avaliações sem critérios obrigatórios
--
-- Somente a coluna status é alterada. Nenhum outro campo é modificado.
-- Restrito a: status = 'em_andamento' + versao_id correto via ciclo +
--             todos os critérios obrigatórios com resposta preenchida.
--
-- NÃO EXECUTAR sem aprovação explícita da usuária.

UPDATE dp_avaliacoes a
SET    status = 'respondida'
FROM   dp_ciclos ci
WHERE  a.ciclo_id = ci.id
  AND  a.status   = 'em_andamento'
  AND  (SELECT COUNT(*)
          FROM dp_versao_criterios vc
         WHERE vc.versao_id = ci.versao_id
           AND vc.obrigatorio = true) > 0
  AND  (SELECT COUNT(*)
          FROM dp_respostas dr
          JOIN dp_versao_criterios vc ON vc.id = dr.versao_criterio_id
         WHERE dr.avaliacao_id = a.id
           AND vc.versao_id    = ci.versao_id
           AND vc.obrigatorio  = true
           AND (dr.resposta_texto       IS NOT NULL
             OR dr.escala_opcao_id      IS NOT NULL
             OR dr.valor_numerico_livre IS NOT NULL))
       >= (SELECT COUNT(*)
             FROM dp_versao_criterios vc
            WHERE vc.versao_id = ci.versao_id
              AND vc.obrigatorio = true);
