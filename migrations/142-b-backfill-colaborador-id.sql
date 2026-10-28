-- Migration 142-b: backfill colaborador_id via avaliacao_id
-- ATENÇÃO: executar apenas após validar o SELECT abaixo e confirmar com a usuária

-- ─── PASSO 1: validar as associações propostas (SELECT — sem alterar dados) ───
SELECT
  dh.id              AS dev_historico_id,
  dh.matricula_colaborador,
  dh.avaliacao_id,
  dh.created_by,
  dcp.colaborador_id AS colaborador_id_proposto,
  c.nome             AS nome_proposto,
  c.setor            AS setor_proposto,
  c.empresa_atuacao  AS empresa_proposta
FROM dev_historico dh
JOIN dp_avaliacoes da        ON da.id = dh.avaliacao_id
JOIN dp_ciclo_participantes dcp ON dcp.id = da.participante_id
JOIN colaboradores c         ON c.id = dcp.colaborador_id
WHERE dh.tipo = 'avaliacao_concluida'
  AND dh.colaborador_id IS NULL
ORDER BY dh.matricula_colaborador::integer;

-- ─── PASSO 2: verificar se há registros SEM match (devem ser zero) ───
SELECT dh.id, dh.matricula_colaborador, dh.avaliacao_id
FROM dev_historico dh
WHERE dh.tipo = 'avaliacao_concluida'
  AND dh.colaborador_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM dp_avaliacoes da
    JOIN dp_ciclo_participantes dcp ON dcp.id = da.participante_id
    WHERE da.id = dh.avaliacao_id
  );

-- ─── PASSO 3: executar o UPDATE somente após aprovação ───
-- AGUARDAR CONFIRMAÇÃO ANTES DE EXECUTAR
UPDATE dev_historico dh
SET colaborador_id = dcp.colaborador_id
FROM dp_avaliacoes da
JOIN dp_ciclo_participantes dcp ON dcp.id = da.participante_id
WHERE dh.avaliacao_id = da.id
  AND dh.colaborador_id IS NULL
  AND dh.tipo = 'avaliacao_concluida';

-- ─── PASSO 4: verificar resultado (deve retornar 0) ───
SELECT COUNT(*) AS registros_sem_uuid
FROM dev_historico
WHERE colaborador_id IS NULL;
