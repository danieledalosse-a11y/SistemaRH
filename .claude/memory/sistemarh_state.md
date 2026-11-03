---
name: sistemarh-state
description: "Estado atual do SistemaRH — módulos implementados, banco de dados, fluxos e pendências"
metadata: 
  node_type: memory
  type: project
  updated: 2026-10-16T00:00:00
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-11-03T19:10:47.196Z
---

## Férias — Fix JSON bruto na visão Gestor (commits 6312ceb/16fb381, 03/11/2026)

**Problema:** ao solicitar alteração de data de férias via Gestor, o drawer exibia o JSON de metadados (`obs_gestor`) como texto de observação no primeiro período (p1), mesmo quando a alteração era no segundo (p2).

**Causa:** `l._obsGestor`, `_rhObsMap.get(l.inicio)` e `row.obs_gestor` são todos derivados do campo `obs_gestor` do banco. Quando status = `Alteracao_Solicitada` / `Cancelamento_Solicitado`, esse campo contém JSON — não texto legível. Os três apareciam na cadeia de fallback de `_notaTxt`. Além disso, `l._obsGestor` é copiado para **ambos** os lancamentos (p1 e p2) na montagem de `GESTOR_LANCAMENTOS`.

**Fix:** guarda `_temMetaPendente` bloqueia as três fontes quando há meta pendente. O banner azul/amarelo já exibe a informação formatada corretamente.

**Regra permanente:** ao adicionar novas fontes à cadeia `_notaTxt` na visão Gestor, sempre incluí-las na guarda `_temMetaPendente`.

---

## Processos + Admissão — Empresa na listagem do Workflow (commits b60694e/7b5de21/3abe4dd/8522450, 30/10/2026)

**Melhorias visuais na listagem de processos:**
- Queries de andamento, cancelados e concluídos incluem `colaboradores(empresa_registro)` via embedded select Supabase (sem N+1)
- Empresa exibida como pill sutil ao lado do nome em todos os cards — fundo `var(--bg-alt)`, borda `var(--border)`, 11px semi-bold, `border-radius:4px`
- Para admissão (`colaborador_id=null`): usa `dados_extras.unidade`; para demais: usa `colaboradores.empresa_registro` via JOIN
- Processos sem o campo não exibem a informação (sem erro)
- Subtexto com detalhes operacionais do VT (cartão/passes/linha) removido da listagem; badge colorido permanece
- Data de criação do convite removida dos cards da listagem de admissão (dado continua no banco, `created_at`)

**Fix layout pill empresa (commit 8522450):** `.row-nome` tem `flex:1` na classe CSS. Inline style mudado de `flex-shrink:0` para `flex:0 0 auto` — sem isso, o nome expandia e empurrava o pill para a extrema direita (junto à barra de progresso). Regra: sempre usar `flex:0 0 auto` no span do nome quando o pill deve ficar colado.

**Módulo Admissão — `unidade` em `dados_extras`:**
- `criarProcesso` de admissão agora grava `unidade: currentConvite?.unidade || null` em `dados_extras`
- Campo disponível para uso no Workflow sem JOIN adicional
- Processos antigos sem o campo: corrigidos via UPDATE pontual no banco (`dados_extras || jsonb_build_object('unidade', valor)`)

**Regra "Não utiliza" (Alelo + VT):** botão visível apenas no hover (`.checklist-item:hover .btn-nao-utiliza`). Cobre itens de GRUPOS_ADMISSAO com `naoUtilizavel:true`.

**Alelo — Vitor Hugo (processo_id=83):** INSERT manual executado. Item aparece corretamente com botão "Não utiliza".

---

## Processos — Checklist admissão via JSON com cache:no-store (commit d506ab6, 30/10/2026)

**Problema resolvido:** processo de admissão criado com JS em cache (browser sem F5 após deploy) gerava checklist desatualizado — item "Pedir cartão Alelo Pagamento" ausente, item legado "Cadastro no sistema concluído" presente indevidamente.

**Solução:**
- Criado `modulos/processos/checklist-admissao.json` como fonte de verdade dos itens de admissão
- `criarProcesso` busca o JSON com `cache:'no-store'` para tipo `admissao`; ignora `CHECKLISTS.admissao` em memória
- Se o fetch falhar: processo bloqueado com mensagem de erro (nunca cria processo incompleto)
- Alelo incluído no JSON na posição correta (após "Inserir no Vale Gás", antes de "Incluir no Mixtra")
- Removida inserção dinâmica do Alelo que dependia do JS atualizado
- Demais tipos (demissão, VT, reajuste etc.) continuam usando `CHECKLISTS` em memória — não afetados

**Para alterar itens de admissão no futuro:** editar `modulos/processos/checklist-admissao.json` (não CHECKLISTS.admissao) e fazer push.

**Correção pontual do Vitor Hugo (processo_id=83):** INSERT manual no Supabase adicionou o Alelo; botão "⊘ Não utiliza" confirmado funcionando (visível no hover).

**Regra "Não utiliza":** botão aparece apenas no hover (`display:none` por padrão, `display:inline-block` no `.checklist-item:hover`). Cobre todos os itens de GRUPOS_ADMISSAO com `naoUtilizavel:true` — Benefícios e Planos & Seguros.

---

## D&P — Fix chips histórico: status 'concluida' e tipo integer (migration 143, commit 14ae0c4, 03/11/2026)

**Problema:** chips de referência histórica no formulário de avaliação ficavam em "Carregando..." para colaboradores com ciclo anterior encerrado.

**Causa raiz 1 — filtro de status:** `dp_fn_historico_criterio` filtrava `a.status = 'publicada'` apenas. Ciclos encerrados sem publicação formal (`status='concluida'`) nunca eram localizados.
**Fix:** filtro ampliado para `IN ('concluida', 'publicada')`.

**Causa raiz 2 — mismatch de tipo:** `dp_fn_historico_criterio_batch` declarava `p_colaborador_id BIGINT` mas a função interna espera `INTEGER`. Com parâmetros nomeados (`=>`), PostgreSQL não faz cast implícito — gerava erro 42883 silencioso, sbRpc retornava `null`.
**Fix:** tipo alinhado para `INTEGER` + `DROP FUNCTION` da sobrecarga `bigint` sobrante (CREATE OR REPLACE com assinatura diferente cria overload, não substitui).

**Regra permanente:** ao criar/corrigir funções PostgreSQL com parâmetros nomeados, verificar que os tipos são idênticos na cadeia de chamadas. Nunca assumir que bigint↔integer é compatível com parâmetros nomeados.

---

## D&P — Modal sugestão automática e toast z-index (commits 5b968f7 / a33252e, 29-30/10/2026)

**Modal "Gerar sugestão automática" melhorado (commit 5b968f7):**
- Título dinâmico: "Novo participante encontrado" (1) ou "X novos participantes encontrados" (muitos)
- Para 1 colaborador: nome + cargo + setor + texto explicativo "Atende aos critérios deste ciclo, mas ainda não está na lista de participantes. Deseja incluí-lo?"
- Para múltiplos: lista com nome/cargo/setor de até 5 itens + "e mais X…" se houver mais
- Botão "Confirmar" → "Adicionar" (ou "Adicionar X participantes")
- Cancelar = nenhuma ação; Adicionar = insere em `dp_ciclo_participantes` + gera avaliação na mesma operação

**Toast `#toast` z-index corrigido (commit a33252e):**
- Problema: toast ficava atrás dos modais (z-index 999 vs modais até 10000)
- Fix: `z-index: 10001` no `#toast` CSS — sempre visível acima de qualquer modal

---

## D&P — Trajetória: identificação única por colaborador_id (migrations 142-a/b, 28/10/2026)

**Problema resolvido:** `matricula_colaborador` é não-único entre empresas/setores. Ana Justiniano (Matriz Adm, mat 127) via contaminação de avaliações do ORIEL (CD, mat 127).

**Solução:**
- Migration 142-a: `dev_historico.colaborador_id integer FK colaboradores.id` + índice
- Migration 142-b: backfill de 73 registros via `avaliacao_id → dp_avaliacoes → dp_ciclo_participantes.colaborador_id`
- 1 registro manual (id=76, test feedback ADILSON VAZ → colaborador_id=1691)
- Final: `COUNT(colaborador_id IS NULL) = 0`

**Código (`modulos/desenvolvimento/index.html`):**
- `_trDetectColaboradorIdExists()`: probe raw fetch — distingue HTTP 400 (coluna ausente) de 200 vazio
- `_trFetchHist(matricula, colaboradorId)`: prioriza `colaborador_id=eq.X`; fallback matrícula só para legados NULL com matrícula única; matrícula ambígua retorna `[]`
- `trAbrirPerfil(matricula, nome, colaboradorId)`: recebe `c.id` da lista
- `trRenderLista`: passa `c.id` no onclick
- `trSalvarFeedback`, `dpGravarTrajetoriaDP`, `pdiSalvarDrawer`: incluem `colaborador_id` condicionalmente
- Commits: 74daa16 (feature) + 08c15db (fix compatibilidade Window A)

**Validado em produção:** Ana Justiniano → 0 registros; ORIEL → avaliação CD correta; ADILSON VAZ → feedback de teste correto.

---

## D&P — KPIs por equipe, PDI concluído na timeline, timeline expansível (commit b904dad, 28/10/2026)

**KPIs da Trajetória filtrados por equipe do gestor:**
- `renderTrajetoria` constrói `equipeSet` (Set de matrículas da equipe do gestor) e filtra `kpiRegistros` e `kpiMatriculas`; `ciclosRealizados` para gestor = distinct `ciclo_id` na equipe (antes era `_dpCiclos` globais)
- Select global de `dev_historico` agora inclui `ciclo_id`

**Conclusão de PDI registrada em `dev_historico`:**
- `pdiSalvarDrawer` captura `statusAnterior` antes de atualizar; POST em `dev_historico` com `tipo=pdi` somente quando status muda para `concluido` (guard `statusAnterior !== 'concluido'`); falha silenciosa — não bloqueia o save

**Timeline expansível (accordion):**
- `trBuildExpandHtml(h)`: constrói HTML de detalhe por tipo — avaliação usa `_trSnapshotFullMap` (todos os critérios), PDI usa `_trPdiData`, feedbacks exibem `descricao + created_by`; retorna `''` quando sem dados
- `trToggleHistItem(idx)`: abre/fecha item e fecha os demais; chevron rotaciona 180°
- `trRenderTimelineItens` atualizado: cada item tem `id`, onclick e chevron quando expansível; `event.stopPropagation()` no botão Excluir
- Remove antigo `<details>` "Observações por competência" (substituído pelo expand)

**KPI "PDI ativos":** continua exibindo `—` — pendente implementação separada

---

## Cadastro + D&P — Fix período de experiência (commits dc461c6 / 6680267, migration 141, 27/10/2026)

**Problema:** campo `em_experiencia` (boolean) nunca era atualizado automaticamente no banco. 31 colaboradores exibiam badge "Em experiência" incorretamente no D&P — alguns desde 2014.

**Solução implementada nos 3 módulos:**
- `desenvolvimento/index.html`: funções `isEmExperiencia(c)` e `isEmExperienciaNoContexto(snap, cicloDataFim)`
- `cadastro/index.html`: `isEmExperiencia(c)` no guard de workflows e na badge do cadastro
- `colaborador/ficha-render.js`: `isEmExperiencia(c)` substituindo leitura direta do booleano

**Regra obrigatória:** nunca usar `c.em_experiencia` diretamente para exibir badge — usar sempre `isEmExperiencia(c)`. Prioridade: `data_fim_experiencia` > fallback admissao+90d > false.

**`isEmExperienciaNoContexto`:** para ciclos históricos no D&P, usa `data_fim` do ciclo como referência em vez de hoje — preserva o significado do badge na época da avaliação.

**Snapshot D&P:** ao adicionar participante, `data_fim_experiencia` agora é gravado no snapshot além de `em_experiencia`.

**Correções adicionais em `cadastro/index.html`** (commit 6680267): campos `c.data_admissao` → `c.dataAdmissao` e `c.data_demissao` → `c.dataDemissao` em `verificarExperienciaWorkflows` (linhas ~2061, 2079, 2124) e `mostrarStatusBonus` (linhas ~4669, 4670, 4675). Esses campos seguem o mapeamento de `supabaseToJS` (camelCase).

**Migration 141 executada em produção (27/10/2026):** corrigiu 31 registros com `em_experiencia=true` e `data_fim_experiencia < CURRENT_DATE`. Verificação pós: `incorretos_restantes = 0`.

---

## D&P — PDI como seção dentro do módulo (commits 7560a79/223c954/2627e05/7dbbb21/28180fb/2fe2570, migration 140, 27/10/2026 + redesign drawer 28/10/2026)

**Migration 140 executada em produção:** cria `pdi_planos` (planos autônomos, desvinculados de ciclos) e `pdi_config` singleton (listas dinâmicas de gatilhos, categorias, status). `dev_pdi` preservada mas não lida em nenhum ponto do código. Migração de dev_pdi→pdi_planos idempotente via WHERE NOT EXISTS.

**RLS em `pdi_planos`:** rh/admin CRUD, diretoria SELECT, gestor SELECT/INSERT/UPDATE filtrado por `auth_colaborador_id() + param_gestor` (mesmo padrão migration 113).

**JSONB `acoes`:** campos `done`, `concluido_em`, `cancelada`, `historico[]` por ação. Ações com histórico nunca deletadas — recebem `cancelada:true`. Prazo vencido detectado automaticamente (prazo < hoje AND done=false AND cancelada≠true).

**Trajetória:** `trCarregarPdi(matricula)` substituiu leitura de `dev_pdi`; agrupa por plano, filtra `cancelada≠true`. Relatório: planos ativos primeiro, concluídos depois; histórico por ação quando existe.

**Variáveis de módulo:** `_pdiConfig`, `_pdiPlanos`, `_pdiDrawerPlano`. Todas operações PATCH com `return=minimal`.

**Redesign drawer PDI (28/10/2026, commits 077fc8e / ba64c5b / ad7c581 / 953a0c9 / a8046d3):**
- Label "Plano de Desenvolvimento" movido para o header (chip roxo à direita dos chips de status), eliminando linha separada no body — libera espaço vertical
- Card do plano começa direto nos campos (sem `.pdi-plan-card-hdr`)
- **Ícone de categoria = toggle de conclusão** — elemento único no card de ação, sem checkbox separado: pendente=círculo colorido, concluída=círculo verde+visto, cancelada=cinza+traço
- Ações visíveis com ícones diretos (lápis + lixeira), sem menu `···` oculto
- `pdiConfirmModal(msg, label)` — modal overlay customizado substitui `confirm()` nativo em `pdiExcluirHistorico` e `pdiExcluirPlanoById`
- Contador do botão `pdi-hist-toggle` atualizado cirurgicamente após exclusão de registro (sem re-render do card inteiro)
- Cabeçalho do painel histórico mostra só "HISTÓRICO DA AÇÃO" — sem repetir contador já exibido no botão

---

## D&P — Remoção abas legado + fix spinner Modelos (commits 12a046e/614a49a/f5dbcf9/5f27b98, 27/10/2026)

Abas "Colaboradores · legado" e "Avaliações · legado" removidas da UI (tabelas e JS mantidos). Elementos removidos do DOM: `#cicloSelect`, `#cicloBadge`, `#colabList`, `#searchInput`, `#filterStatus`, `#filterSetor`. Null guards adicionados em `populateCicloSelect`, `onCicloChange`, `populateSetorFilter`, `renderColabList`. `renderModelos()` permanece **após** o `await Promise.all` no `init()` — nunca encadear dentro de `.then()` interno. Filtro de setor da Trajetória usa `_dpSetores` (param_setor) como fonte oficial, com normalização de prefixo numérico.

---

## D&P — Trajetória — filtros com dropdown customizado e busca interna (commits e891d71/4758fc6/e2b3fb3/2975d22, 28/10/2026)

Filtros da lista de colaboradores na aba Trajetória Profissional melhorados:
- **Nome:** campo com lupa, X para limpar, foco automático
- **Setor e Função:** `<select>` nativos substituídos por dropdowns customizados com `top: calc(100% + 4px)` — sempre abrem para baixo. Cada dropdown tem campo de busca interna (filtra itens em tempo real) + X para limpar busca, com foco automático ao abrir. Os `<select>` ocultos com os IDs originais são mantidos para compatibilidade com JS que lê `.value` e popula `.options`. Após popular selects ocultos, chamar `trSyncDropdown('setor')` e `trSyncDropdown('cargo')`.

**Why:** `<select>` nativo abre para cima quando há pouco espaço abaixo — impraticável com lista grande de setores/funções.

---

## D&P — Trajetória Profissional — permissões por perfil (commit ade208f, 27/10/2026)

**Feedback/anotação — excluir na timeline:**
- `trRenderTimelineItens`: botão "Excluir" apenas em tipos editáveis (`feedback_positivo`, `ponto_melhoria`, `anotacao`); RH/admin sempre vê, Gestor vê apenas `created_by === _nomeUsuario`, Diretoria nunca vê
- `trExcluirFeedback(id)`: guard para Diretoria + consulta ao banco confirmando `created_by` antes do DELETE para Gestor
- `_trMatriculaAtual`: variável armazena matrícula aberta no perfil; usada para recarregar timeline após exclusão
- `dev_historico` não tem RLS — proteção é inteiramente no frontend

**PDI — somente leitura para Diretoria:**
- `renderPDIHtml`: `_pdiPodeEditar = (_perfil === 'rh' || 'admin' || 'gestor')` — oculta formulário e botões de excluir para Diretoria
- `adicionarPDIItem` e `deletePDIItem`: guards bloqueiam Diretoria na função
- `togglePDIItem` (marcar concluído): sem restrição de perfil

---

## D&P — Trajetória — título ciclo, resultado financeiro, gráfico e cor (commits 4519ee7/dea6bf0/31238cb, 27/10/2026)

**Migration 137:** `resultado_valor NUMERIC` nullable em `dev_historico`.
**Migration 138:** `resultado_valor_max NUMERIC` nullable em `dev_historico` — valor máximo possível do ciclo para cálculo de percentual.

**`dpGravarTrajetoriaDP`:** grava `titulo = cicloNome`, `resultado_valor = valor_bonus`, `resultado_valor_max = SUM(valor_se_sim)` dos critérios da versão, `descricao = cargo · ciclo · R$ valor`, `created_by = _nomeUsuario`.

**Todos os selects de `dev_historico` na Trajetória** incluem `resultado_valor` e `resultado_valor_max`.

**Cor por percentual (`trCorAting`):** verde ≥100%, âmbar ≥70%, vermelho <70%. Aplicado na linha "cargo · Resultado: R$ X,XX" da timeline e nos pontos/valor do gráfico.

**Timeline (`trRenderTimelineItens`):** avaliação concluída exibe `"cargo · Resultado: R$ X,XX"` (cargo do 1º segmento de descricao; R$ colorido). Seção `<details>` colapsável de observações por competência — só aparece quando `snapshot_criterios` tem entradas com `observacao` preenchida.

**`snapshot_criterios`:** inclui campos `observacao` e `nome` (criterio_nome_snapshot) desde commit 3f1a47e. Gravado em `dpCalcularAvaliacao` (conclusão e ajuste RH). Setembro: observações foram adicionadas via ajuste RH para Adriana (Apresentação Pessoal: "TESTE") e Adilson Vaz (Pontualidade: "sempre chega na hora"). Snapshots legados com `nome: ""` resolvidos em tempo de exibição por `trAbrirPerfil` via `dp_versao_criterios` — sem alterar banco.

**Performance (`renderTrajetoria`):** `_trInicializado` flag evita re-fetch ao voltar à aba. Select global reduzido a 3 campos (`matricula_colaborador,tipo,data`). Invalidado em `dpGravarTrajetoriaDP` após nova avaliação concluída.

**Performance (`trAbrirPerfil`, commit d3a20d0):** ao trocar de colaborador na lista, `tr-perfil-resumo`, `tr-perfil-timeline` e `tr-perfil-form` eram limpos só após as queries retornarem (1–2 s de conteúdo antigo visível). Fix: limpeza imediata dos três elementos antes do primeiro `await` — usuário vê "Carregando..." instantaneamente. Queries permanecem sequenciais (segunda depende de `avalIds` da primeira).

**Backfill setembro/2026:** 73 registros — `resultado_valor` (200–400), `resultado_valor_max=400`. Validado: total=73, com_resultado_valor=73, com_max=73. D3 (responsável) não recuperável para setembro.

## D&P — Relatório Completo do Colaborador (commits 69db8ce/495847a, 27/10/2026)

Botão "Relatório completo" no breadcrumb da view de perfil da Trajetória Profissional. Código único compartilhado entre RH, Gestor e Diretoria.

- `trGerarRelatorio(matricula)` — zero fetches; usa `_trHistAtual` + `_trSnapshotCriteriosMap` + `_dpCiclos` + `_colaboradores`
- `_trHistAtual = []` e `_trSnapshotFullMap = {}` — vars de módulo adicionadas; `_trHistAtual` populado ao final de `trAbrirPerfil`; `_trSnapshotFullMap` e `_trSnapshotCriteriosMap` resetados juntos no início de cada `trAbrirPerfil`
- Overlay `#trRelatorioOverlay` fullscreen; botão "Imprimir / Salvar PDF" via `window.print()` com `@media print @page A4`
- Conteúdo: cabeçalho (avatar, nome, cargo/setor, empresa, admissão + tempo na empresa, matrícula), KPIs (ciclos, registros, último resultado), linha do tempo (mais recente → topo): avaliações com resultado financeiro + observações por competência apenas quando existem (`_trSnapshotCriteriosMap` — só critérios com observação, formato compacto `Nome — comentário`), feedbacks, pontos de melhoria e anotações com data + autor
- `created_by` exibe "—" para registros históricos sem autor (setembro/2026)
- Gestor: `_trSnapshotCriteriosMap` fica vazio (RLS) → observações por competência não aparecem. Permissões a tratar em tarefa futura.

---

**Próxima feature planejada — Análise por critério (implementar após 2º ciclo):**
Seção "Pontos de atenção" no perfil da Trajetória. Dados disponíveis em `dp_respostas` + `dp_resultados_bonus.snapshot_criterios` (criterio_id, resposta, valor_apurado; `nome` do critério vem de `dp_versao_criterios`). Blocos: Pontos fortes (sempre "sim"), Pontos de atenção ("não" em ≥2 ciclos consecutivos), Em observação (variação). Fotografia de 1 ciclo exibe sem inferência de tendência; análise de recorrência só com ≥2 ciclos do mesmo modelo.

---

## D&P — Trajetória Profissional — feature completa (commits cb588c6/7ed2703/3f8a5e3/d18613a, 27/10/2026)

Feature que rastreia histórico de desempenho por colaborador, gravando em `dev_historico` a cada avaliação concluída e exibindo linha do tempo no D&P e no Cadastro.

**Migrations executadas em produção:**
- 135: `ciclo_id uuid` + `avaliacao_id uuid` nullable em `dev_historico`
- 136: `created_at TIMESTAMPTZ` em `dev_pdi`

**Etapa 1–3 (cb588c6):** `dpGravarTrajetoriaDP` grava em `dev_historico` com `modulo_origem='dp'` ao concluir avaliação. Seção Trajetória no drawer D&P: `renderTrajetoria`, `trFiltrar`, `trRenderLista`, `trAbrirPerfil`, `trRenderTimeline`, `trSalvarFeedback`.

**Etapa 4 (7ed2703):** Aba "Desempenho" no drawer do Cadastro (`renderDesempenhoDP`). Usa `sbGet(tabela, params)` — dois args, padrão Cadastro. `c.codigo` = matrícula.

**Etapa 5 (3f8a5e3):** `renderPDI` e `salvarPDI` corrigidos — bloqueio explícito quando `_cicloAtivo` é null (sem consultar banco), e filtro `ciclo_id=eq.X` em todas as leituras e gravações quando ciclo ativo.

**Etapa 6 (d18613a):** Aba Resultados oculta para Gestor: `(ativoOuEncerrado && _perfil !== 'gestor')` em `dpAbrirDrawerCiclo`.

---

## D&P — Fluxo Ajustar e reformulação do Relatório Excel (commits 3f…/e885120/eff1736, 27/10/2026)

### Etapa 0 — Fix fluxo Ajustar avaliação concluída (migration 133)

**Três causas corrigidas:**

| Causa | Correção |
|---|---|
| Trigger `trg_bloquear_reverter_conclusao` bloqueava `concluida→respondida` | Migration 133: exceção para `concluida→respondida` quando `auth_perfil() IN ('rh','admin')` |
| `dpAbrirAjuste` passava `avaliacaoId` para função que esperava `participanteId` | Reescrita como `dpIniciarAjuste(participanteId)` |
| ENUM `dp_evento_historico` sem `avaliacao_ajuste_iniciado`/`concluido` | Adicionados na migration 133 via `ADD VALUE IF NOT EXISTS` |

**Novo fluxo (fix permanente, commit f7a0af5):** ícone lápis na aba Avaliações (apenas avaliações `concluida`, apenas RH/admin) → `dpIniciarAjuste` → **sem PATCH de status** (banco permanece `concluida`) → registra evento → `_dpModoAjuste = true` → abre formulário → ao salvar: `await fecharFormAval(true)` → recalcula + PATCH `concluida_em` (sem alterar status) + toast "Ajuste salvo". Fechar sem salvar não altera banco.

**Nova variável:** `let _dpModoAjuste = false` — suprime toast duplicado de "Avaliação concluída." durante ajuste; controla se `fecharFormAval` recalcula ao fechar.

**Causa raiz do bug "preso em Respondida":** `dpIniciarAjuste` patcheava DB para `respondida` antes de abrir o form; se a página era recarregada durante o ajuste, `_dpModoAjuste` voltava a `false` mas DB ficava `respondida` para sempre. Fix permanente: eliminar o PATCH em `dpIniciarAjuste` — DB nunca muda de `concluida` durante o ajuste. Commit `f7a0af5`.

**Fix CSS campo Observação (commit bab3be1):** `.aval-obs-expanded` expande no fluxo flex, sem `position: absolute`. Regra correta: `height: auto; min-height: 80px; max-height: 160px; overflow: auto; resize: vertical; align-self: flex-start; box-shadow: ...; border-color: var(--accent)`. Sem `position/right/top/z-index` — causam desalinhamento de coluna e cobertura dos botões Sim/Não. `dpAvalObsBlur` remove a classe e reseta `el.style.height` para recolher.

**Trajetória — foto do colaborador na lista e no perfil (commit f6100a1):** avatar usa `foto_url` de `_colaboradores` quando disponível; fallback para iniciais coloridas. Ambos os locais: `trRenderLista` e `trAbrirPerfil`.

**Trajetória — edição e exclusão de registros manuais na timeline (commits d6c14a1, 75c00bf):** ícone lápis abre textarea inline pré-preenchido com o texto atual (PATCH `descricao` em `dev_historico`); ícone lixeira abre `pdiConfirmModal` antes de deletar. Disponível apenas para `tipo IN (feedback_positivo, ponto_melhoria, anotacao)`. Registros de avaliação não têm edição.

**Fix contaminação Trajetória por matrícula (commit 75b2e29, out/2026):** `_trHistoricoMap` era indexado por `matricula_colaborador` (não único). Colaboradores com mesma matrícula compartilhavam badges e KPIs indevidamente. Correção: query passa a buscar `colaborador_id` em vez de `matricula_colaborador`; mapa indexado por `colaborador_id`; registros sem UUID ignorados sem fallback; `trRenderLista` usa `c.id`; KPI do gestor usa `c.id`/`r.colaborador_id`. Migration 142-b (backfill) dispensada — Passo 1 retornou zero linhas; todos os registros existentes já tinham `colaborador_id` gravado corretamente.

**Fix embed PostgREST (commits c77e11d, 3f1a47e):** observações da Trajetória nunca apareciam. Causa: `dp_resultados_bonus.resultado_id` tem constraint `UNIQUE` → PostgREST retorna embed como **objeto**, não array. Acesso `[0]` retornava `undefined` silenciosamente. Correção: `row.dp_resultados_bonus?.snapshot_criterios` (era `[0]`); `res?.[0]?.dp_resultados_bonus?.valor_bonus` (era `[0]`). Nomes dos critérios em snapshots legados (`nome: ""`) resolvidos em `trAbrirPerfil` via query a `dp_versao_criterios` usando `_dpCiclos` em memória — sem alterar dados históricos. Novos snapshots já incluem `criterio_nome_snapshot` no select de `dpCalcularAvaliacao`.

### Resultados — limpeza visual

- **Bônus duplicado removido:** `"bônus: R$ X"` abaixo do nome eliminado; badge à direita permanece único.
- **Botões Recalcular/Calcular por linha removidos:** toolbar mantém apenas batch, exportar e encerrar. Cards viram lista somente leitura.

### Exportação Excel — reformulação completa

**Colunas:** Empresa · Matrícula · Nome · Cargo · Valor · Status (antes: Matrícula · Nome · Cargo · Setor · Unidade · Status · Nota · Conceito)

**Regras:**
- Participantes primeiro; não-participantes no final
- **Empresa:** `_colaboradores.find(c => c.id === p.colaborador_id)?.empresa_registro_nome` (não snapshot — campo não existia nos snapshots antigos)
- **Valor:** `valor_bonus` de `_dpResultadosBonus` formatado como `R$ X.XXX,XX`
- **Lookup avaliação:** `a.participante_id === p.id` (não `colaborador_id` — campo inexistente em `dp_avaliacoes`)
- `loadColaboradores` e query de retroativos agora incluem `empresa_registro_nome` no select
- `<colgroup>` com larguras fixas: Nome 220pt, Cargo 180pt, Empresa 160pt, Status 120pt, Valor 90pt, Matrícula 70pt
- Status badge colorido inline via `<span>` com fundo/cor por valor

---

## D&P — Setas de navegação respeitam filtro de status (commit eab7e09, 26/10/2026)

**Why:** ao selecionar o card "Em andamento" (ou qualquer chip de status) e abrir uma avaliação, as setas percorriam todos os 73 participantes em vez de só os filtrados pelo chip.

**Fix:** em `dpAbrirFormAvaliacao` (linha ~6113), a construção automática da `_dpFormNavList` agora aplica `_dpFiltrarPorStatus(base, _dpAvalFiltroStatus, _dpAvaliacoes)` após o filtro de nome/cargo, quando `_dpAvalFiltroStatus` está ativo. Sem filtro de status o comportamento é idêntico ao anterior.

**How to apply:** qualquer futura lógica de "abrir formulário e navegar" deve considerar os três filtros acumulados: nome, cargo e status.

---

## D&P — "Não participa" — feature completa (commits 5b7648b / 0c379d5, 26/10/2026)

**Why:** botão ⊘ no modal "Não participa deste ciclo" não gravava — dois bugs independentes mais migrations não executadas.

**O que foi feito:**
- Migrations 122, 123, 125 e 124 executadas manualmente no Supabase Dashboard (nessa ordem — 125 antes de 124)
- Commit 5b7648b: modal fecha APENAS após sucesso da RPC; erros exibidos no `#dpNpErro` inline (modal permanece aberto)
- Commit 0c379d5: `sbRpc` trata corpo vazio de RPCs VOID — antes `r.json()` em resposta vazia lançava `SyntaxError`, que o `catch` capturava como `_sbLastError`, fazendo a ação parecer falha silenciosa. Fix: `r.text()` + `JSON.parse` condicional.

**Funciona em:** visão RH (aba Participantes e aba Avaliações) e visão Gestor (aba Avaliações do drawer).

**How to apply:** qualquer RPC que retorne `VOID` funcionará corretamente com `sbRpc` — não criar workarounds. O `sbRpc` já lida com corpos vazios.

---

## Férias — Fix mapeamento de status alteração/cancelamento (commit f2b84a8, nov/2026)

**Problema:** solicitações de tipo `Alteracao_Solicitada` e `Cancelamento_Solicitado` não apareciam na "Atividade Recente" (visão Gestor) nem em "Aguardando aprovação" (visão RH), embora o card de contagem mostrasse as pendências corretamente.

**Causa raiz:** dois dicionários com valores encurtados que nunca faziam match com os status reais:
- `_statusPendG` (Gestor, `_gestorProcessoInfo`): usava `'cancelamento'` e `'alteracao'` em vez de `'cancelamento_solicitado'` e `'alteracao_solicitada'`
- `_statusPendente` (RH, `_rhEhRecente`): usava `'Cancelamento'` e `'Alteracao'` em vez de `'Cancelamento_Solicitado'` e `'Alteracao_Solicitada'`

**Correção (2 linhas):**
```js
// _gestorProcessoInfo — linha ~8840
const _statusPendG = { solicitado: 'pendente', cancelamento_solicitado: 'cancelamento_solicitado', alteracao_solicitada: 'alteracao_solicitada' };

// _rhEhRecente — linha ~8900
const _statusPendente = { solicitado: 'Pendente', cancelamento_solicitado: 'Cancelamento_Solicitado', alteracao_solicitada: 'Alteracao_Solicitada' };
```

**Regra permanente:** os valores nesses dicionários devem ser os valores **exatos** de `ferias.status` no banco. `solicitado` é exceção — normalizado pelo parse para `'Pendente'`/`'pendente'`. Ver skill ferias.md seção "_statusPendG".

---

## Férias — Múltiplas solicitações por PA (commit 16de87c, 26/10/2026)

Gestor agora pode fazer mais de uma solicitação dentro do mesmo PA, mesmo com anterior pendente de aprovação RH. Bloco `jaSolicitado` removido de `gestorEnviarSolicitacao`.

**Saldo disponível = `gestorSaldoPeriodo` − dias pendentes (status `solicitado`):** calculado independentemente no modal (`gestorAbrirModal`) e no envio (`gestorEnviarSolicitacao`) — sem estado compartilhado, sem risco de duplicação.

Após RH aprovar (`solicitado→aprovado`): dias entram em `gestorSaldoPeriodo`, saem de `_diasSolPend` — saldo correto. Após RH reprovar (`solicitado→recusado`): nenhuma das duas contagens inclui `recusado` — saldo integralmente restaurado.

Validações que permanecem: data passada, consistência `ano/pa_fim`, datas fora da concessão (`pa_inicio … pa_fim+366d`), datas iguais a lançamento recusado.

---

## Férias — Cards do drawer Gestor e validações (commits 22a1af1 / ee8a406 / bede823, 26/10/2026)

**Validações em `gestorEnviarSolicitacao` e `gestorEnviarAlteracao` (commit 22a1af1):**
1. Consistência `ano` vs. `pa_fim` — bloqueia se os dois divergem (import incorreto)
2. Data de início fora do período de concessão (`pa_inicio` → `pa_fim + 366 dias`)

**Cards do drawer (PA Vigente · Saldo · Vencimento) — regra canônica (commits ee8a406 / bede823):**
Os três cards usam `_paBase = pa || paVig` como fonte única:
- `pa` = `gestorPeriodoAtivo` (mais antigo com saldo > 0)
- `paVig` = `gestorPeriodoVigente` (vigente por data — fallback quando saldo=0)
- `saldo`, `venc` e `paAno` TODOS lidos de `_paBase` — nunca `pa` ou `paVig` isolados

Vencimento = dobra (`_addOneYear(pa_fim)`), não data fim do PA.

**Correção de vinculação — Luciano (banco direto, 26/10/2026):**
Lançamento (27/01→25/02/2027·30d) movido de PA 2027 (id=1339) para PA 2026 (id=1907) com status "solicitado". PA 2026 ficou "Pendente" para aprovação RH.

---

## Férias — Ordenação cronológica dos lançamentos (commits f3a81e9 / e28c890, 26/10/2026)

**Visão RH — fonte:** sort adicionado em `supabaseParaModelo` (~linha 2625), logo após o array `lancamentos` ser construído (caminho `periodos[]` JSONB e fallback flat):
```js
lancamentos.sort((a, b) => (a.inicio || '').localeCompare(b.inicio || ''));
```
Garante que a aba "Períodos" do drawer RH mostre lançamentos de cada PA do mais antigo para o mais recente. A função que renderiza (`r.lancamentos.map(...)` na linha ~3589) não precisa de sort adicional — herda a ordem da fonte.

**Visão Gestor — drawer `gestorAbrirSolicitacoes`:** dois sorts adicionados no mesmo commit (f3a81e9):
- Blocos de PA: ordenados por `pa_fim || pa_inicio` ascending
- Lançamentos dentro de cada PA: `(a.inicio||'').localeCompare(b.inicio||'')` ascending

**Regra:** ordenação cronológica pertence à fonte (construção do array), não à renderização.

---

## Férias — Toggle expand/collapse nos títulos das abas (commit c2cd11e, 26/10/2026)

Clicar no título da aba ativa (Atividade recente / Histórico) alterna expand/collapse da lista. Clicar em aba diferente troca e sempre expande. Chevron continua funcionando. Comportamento idêntico RH e Gestor — 4 linhas alteradas.

---

## Férias — Unificação do Histórico em helper compartilhado (commit 875bc6e, 26/10/2026)

`_renderCardHistoricoShared(g, opts)`: único helper para card colapsável do Histórico, usado por RH e Gestor via opts `{expandedSet, rerenderFn, processInfoFn, fmtD, fmtDH}`. ~70 linhas duplicadas removidas. `_rhHistExpanded` (Set global novo): estado de expansão do RH, independente de `_gestorHistExpanded`. `_rhProcessoInfo(h)`: adapta `_acaoInfo` + `h.detalhe` para o formato `{cls, estado, inicio, fim, dias, motivo}` do helper. Aba "Atividade Recente" não alterada.

---

## Férias — Série de correções (commits d73950b / 4db6fe5 / 37174d8, 26/10/2026)

**1. `renderRhAtividade` não atualizava após aprovar/rejeitar (commit d73950b):**
`renderRhAtividade()` não faz parte de `renderAll()` — deve ser chamada explicitamente. Adicionada nos 6 pontos de saída de `aprovarPendente()` e `rejeitarPendente()` (fluxos padrão, alteração, cancelamento). Visão Gestor não tinha o problema.

**2. `excluirLancamento` dessincronizava campos flat (commit 4db6fe5):**
Mapeava `periodos[].id` diretamente ao slot flat (id=0→periodo1_*, id=1→periodo2_*). Quando o id não correspondia ao slot real dos dados, os campos errados ficavam preenchidos. Corrigido: recalculo posicional dos campos flat a partir dos períodos ativos restantes.

**3. Bloqueio de datas retroativas no Gestor (commit 4db6fe5):**
`gestorEnviarSolicitacao` passou a bloquear `inicio < hoje` com mensagem orientando a verificar o ano. Exclusivo da visão Gestor; RH permanece irrestrito.

**4. `processGestorFerias` exibia períodos excluídos (commit 37174d8):**
Loop sobre `periodos[]` não filtrava `status: "excluido"`, causando divergência visual entre RH e Gestor. Correção: `if (_stNormP === 'excluido') return` espelha a regra da visão RH. `recusado`/`cancelado` continuam visíveis (fluxo "Remarcar" preservado). Regra: filtro de excluido deve existir no ponto de construção do lançamento, não só no cálculo do saldo.

**Caso Diego Messias Florencio PA 2026 (id=1734):** dados corrigidos via PATCH — `periodos[0].status="excluido"` (28d antigo), `periodos[1].status="aprovado"` (2d ref. coletivas jan/2026), flat `periodo1_*`=2d, `periodo2_*`=null. Saldo 28d correto nas duas visões.

---

## D&P — Fix: filtro de status divergia da renderização + KPI cor errada (commits 33d223b/bccc753, 26/10/2026)

**Problema 1 — filtro divergente:** ao clicar no chip "Não iniciada", um participante (Diego) aparecia com badge "Respondida". Causa raiz: `Array.find` retorna o **primeiro** registro com aquela chave; `new Map` **sobrescreve** e retorna o último. Quando havia dois registros em `dp_avaliacoes` para o mesmo `participante_id`, o filtro via `find` pegava o antigo (nao_iniciada) e a renderização via Map pegava o novo (respondida) — divergência garantida.

**Correção:** `_dpFiltrarPorStatus` e `_dpStatusCounts` agora constroem Maps internos antes do loop, idênticos ao `dpRenderAvaliacoes`. As três funções sempre enxergam o mesmo registro. **Regra permanente:** nunca usar `Array.find` no lookup de avaliação por status — sempre usar Maps.

**Problema 2 — KPI "Não participam" com texto cortado e cor neutra:** ajustado para vermelho (`#DC2626`) e `labelSize: '9px'` para caber no grid de 5 colunas sem corte.

**Limpeza de dados (26/10/2026):** 3 avaliações duplicadas removidas do banco (Diego + 2 outros de testes). Origem: condição de corrida — duplo clique criava dois POSTs antes do primeiro retorno atualizar `_dpAvaliacoes`, passando a guarda `find`.

**Migration 134** (`dp_avaliacoes_unique_participante`): `UNIQUE (participante_id)` aplicado em produção — condição de corrida bloqueada em nível de banco.

---

## D&P — Otimização de performance: return=minimal (commit a3d93b6, 23/10/2026)

Causa identificada: `sbUpsert` e `sbPatch` com `return=representation` forçavam PostgREST a executar SELECT pós-escrita, dobrando custo de RLS. Ganho medido em produção: UPSERT ~4.700ms → ~580ms (−88%), PATCH ~1.850ms → ~360ms (−80%), total save ~6.500ms → ~940ms (−86%).

Solução: duas funções locais `_dpUpsertMinimal` e `_dpPatchMinimal` (return=minimal, sem SELECT pós-escrita), usadas SOMENTE nas 4 chamadas de save do D&P (`salvarAvaliacao` e `_dpSalvarParaNavegar`). Funções globais `sbUpsert`/`sbPatch` intactas. `_dpRespostasAtual` atualizado via merge cirúrgico por `versao_criterio_id` (sem depender do retorno do banco).

**Lição aprendida registrada:** ver [[feedback-return-minimal]]. Aplicar `return=minimal` em qualquer módulo novo que não precise do retorno do banco nas operações de escrita.

Migration 128 (`dp_fn_historico_criterio_batch`) aplicada em produção (23/10/2026). Nota: no plano gratuito Supabase, PGRST202 pode persistir por ~15 min após criação da função (schema cache assíncrono). Validar com curl + service key para confirmar que a função existe; aguardar refresh para o browser.

---

## D&P — Unificação tela Ciclos RH × Gestor + banner premium (commits c546268/079e417/f9e5017, 23/10/2026)

`dpRenderCiclosUnificado(ciclosInput, opts)` — função compartilhada substitui `gestorDpRenderCiclos`. Sidebar adicionada ao Gestor (`.content-area > .list-col + .sidebar-col`). Banner de ciclo redesenhado: fundo azul claro (`#f0f5ff`), borda sutil, dark mode. Percentual de conclusão exibido à direita da barra. Base do cálculo: `respondidas = status ∈ [respondida|concluida|publicada]` ÷ total de participantes ativos (em andamento e não iniciadas ficam fora do numerador). `loadDpModelos()` chamado no Gestor via `Promise.all` apenas se `_dpModelos.length === 0`, garantindo nome completo do modelo. Onclick em HTML dinâmico usa `window._dpCicloClickFn`. IDs do banner com sufixo `_${containerId}` para evitar colisão. `_dpSidebarAvalCounts` restrito ao RH.

---

## D&P — Fix: filtro de status exibia não participantes indevidamente (commit `6d5bd84`, 23/10/2026)

Clicar em qualquer KPI de status (Em andamento, Respondida etc.) mostrava o resultado correto mais a seção "NÃO PARTICIPAM DESTE CICLO" abaixo. Causa: `.concat(naoParticipa)` no branch `else if (filtroStatus)` em 3 locais (`_dpRenderAvaliacoesComFiltro`, `salvarAvaliacao` sync-gestor, `gestorDpShowTab`). Corrigido removendo o concat nesses 3 pontos. Regra permanente: não-participantes só aparecem quando nenhum filtro de status está ativo, ou quando o KPI "Não participam" é clicado explicitamente.

---

## D&P — KPI "Não participam" clicável (commits `ab31288`, `125786f`, `06572e6`, 23/10/2026)

5º chip KPI na aba Avaliações, implementado sem alterações no banco. Funções-chave: `_dpStatusCounts` (inclui `nao_participa` count), `_dpStatusChipsHtml` (grid 5 colunas, estilo neutro), `_dpFiltrarPorStatus` (early return para `'nao_participa'`), `_dpRenderAvaliacoesComFiltro` e `gestorDpShowTab` (branch triplo). Visual: chip cinza; linhas NP com borda vermelha, badge FEE2E2. Filtros de nome/cargo continuam funcionando com todos os filtros de status.

---

## D&P — Fix: status da avaliação não atualizava na lista do Gestor (23/10/2026)

**Commit:** `ab31288`
**Causa raiz:** Após salvar avaliação, `dpLoadAvaliacoes` recarregava `_dpAvaliacoes` e renderizava via `_dpRenderAvaliacoesComFiltro()` — mas essa função usa o container `dpAvaliacoesBody` (RH). No contexto do Gestor, o container visível é `gdptab-avaliacoes` e o mirror `_gdpAvaliacoes` não era atualizado.
**Correção:** No final de `salvarAvaliacao`, após o reload, verifica `_gdpCicloAtual`; se ativo, sincroniza `_gdpAvaliacoes = _dpAvaliacoes` e re-renderiza `gdptab-avaliacoes` preservando filtros de nome, cargo e status.
**Padrão confirmado:** Existem duas funções `salvarAvaliacao` no arquivo — linha 2154 (legado, tabela dev_avaliacoes) e linha 6561 (motor dp_*, com fix aplicado). O botão do formulário moderno chama sempre a da linha 6561.

---

## Fotos de perfil Admin/RH/Diretoria — vínculos realizados (22/10/2026)

`colaborador_id` preenchido via PATCH direto no banco (service role). Usuários vinculados:
- id=1 Daniele → colab 1611 | id=2 Evelyn → colab 1612 | id=3 Heloisa → colab 1619
- id=11 Algacir (Diretoria) → colab 1642 | id=24 André → colab 1643

**Pendente:** 5 diretores ainda sem `usuarios_perfil` — Barbara(1644), Fernando(1645), João Pedro(1646), Pedro Augusto(1647), Rita(1648). IDs de colaboradores já identificados; vincular ao criar os usuários.

---

## Home Dashboard — Arquitetura compartilhada RH/Gestor/Diretoria (migration 074, out/2026)

**Commits:** `8547cfe` (renderHomeDashboard + routeHomePerfil + login.html), `6a6190f` (UI Parâmetros), `983df51` (guard _hcColExists + _homeConfigDirty + migration), `2df1656` (fix dois saves)

### Função única `renderHomeDashboard(p, secoes)`

Substitui `renderHomeGestor(p)`. Única função para todos os perfis. Seções visíveis controladas pelo array `secoes` passado pelo `routeHomePerfil`.

- `temEquipe = secoes.some(s => ['ferias_equipe','atividades','eventos'].includes(s))` — controla se dados de equipe são buscados
- Busca de equipe: `perfil === 'gestor'` → filtra por `param_gestor.apelido`; `rh`/`diretoria` → todos os colaboradores ativos (RLS scopes real access)
- Bell (`hd-bell-wrap`) e `_loadPendencias` → restritos a `perfil === 'gestor'`
- Fetches condicionais: cada seção só busca dados se incluída em `secoes[]`

### `routeHomePerfil` atualizado

```js
const hc = p.home_config || null;
const showDash = hc ? hc.dashboard === true : perfil === 'gestor'; // fallback preserva Gestor
const secoes = (hc && Array.isArray(hc.secoes)) ? hc.secoes
  : (perfil === 'gestor' ? ['ferias_equipe', 'atividades', 'eventos'] : []);
renderHomeDashboard(p, secoes).catch(e => console.error('[renderHomeDashboard]', e));
```

### `home_config` JSONB na tabela `perfis`

**Migration 074** (`ALTER TABLE perfis ADD COLUMN IF NOT EXISTS home_config JSONB DEFAULT NULL`) — executada em produção (21/10/2026). Todas as linhas ficam NULL; comportamento de fallback preserva o sistema anterior.

Estrutura: `{ "dashboard": true, "secoes": ["ferias_equipe", "atividades", "eventos"] }`

`login.html` busca `home_config` junto com `permissoes` no login e grava em `sb_perfil` no localStorage (apenas quando não null).

### Configuração via Parâmetros Gerais

Modal "Perfis de Acesso" ganhou seção "Home Dashboard" com: checkbox "Habilitar" + wrap de 3 checkboxes de seções (visível apenas quando habilitado).

**`_homeConfigDirty` flag:** evita que salvar outros campos sobrescreva `home_config = null` de perfis não configurados. Ativada pelo `onchange` do checkbox principal.

**Guard de coluna:** `_hcColExists` verifica via `Object.prototype.hasOwnProperty.call(allPerfis[0], 'home_config')` antes de incluir no payload — protege contra erro de banco se migration não tiver sido executada.

### RLS em `colaboradores` (verificado 21/10/2026)

- Policy `authenticated_select`: `admin, rh, gestor, diretoria` têm SELECT em todos os registros
- Policy `anon_all = true`: acesso anônimo a todos os dados — **pré-existente, não alterado; pendência de segurança separada**
- O filtro JS de equipe por gestor é apenas display — RLS é a camada de segurança efetiva

---

## Home — Comunicados da Home (migrations 117 e 118 executadas, out/2026)

**Commits:** `ab3ee3a` (feature base), `5c8c286` (destinatários múltiplos), `a4e9b97` (fix checkboxes), `7bbd099` (abas Formulário/Histórico), `3490fe2` (carousel v1), `fd8b9d2` (carousel v2 — visual), `bac3107` (card único + espaçamento), `534f8be` (card único 100% + ícone megafone)

**Tabela `param_aviso_home`:** avisos configuráveis pelo RH exibidos abaixo dos módulos na Home. Campos: `titulo`, `corpo` (opcional), `tipo` (`info`/`lembrete`/`urgente`), `publico TEXT[]` (ex: `['gestor','rh']` ou `['todos']`), `colaboradores_ids INTEGER[]` (pessoas específicas, nullable), `data_inicio DATE`, `data_fim DATE` (nullable), `ativo BOOLEAN`.

**Migrations 117 e 118:** ambas executadas em produção. 118 converteu `publico TEXT→TEXT[]`, adicionou `colaboradores_ids INTEGER[]` e recriou policies com lógica array.

**Home (`index.html`) — Carousel v2 + float card (commit `61f4a75`):** `_renderAvisos(perfil)` gera carousel com setas laterais (flex row), cards coloridos por tipo (urgente=`#fff5f5`, info=`#ebf4ff`, lembrete=`#fffbeb`), badges sólidos escuros, ícone circular 42px no canto do card, footer com data + seta. Bolinhas separadas abaixo do carousel. Quando `avisos.length === 1`: wrap recebe `.single`, card expande 100% (sem setas/bolinhas). Setas apenas para 3+ avisos (`multi = avisos.length >= 3`). Ícone da seção = megafone (não sino — sino já existe na topbar). **Subtítulo removido (commit `61f4a75`).** Título em 16px, ícone 32px. Ao clicar num card: `_avisosVerCard(idx)` anima float card (`position:fixed`) da posição exata do card original até o centro da tela com `transition: left/top/width/opacity 0.3s`; mesmo visual do card original, corpo sem `line-clamp`; fecha com ×, backdrop ou Esc. Constante `_avisosCalSvg` e variável `_avisosFloatRect` declaradas em módulo-level.

**Filtro JS de gestores específicos (commit `bec5bca`, out/2026):** quando aviso tem `publico=['gestor',...]` e `colaboradores_ids` não vazio, o filtro restringe a exibição aos gestores da lista. Gestores fora da lista não veem o aviso mesmo com `'gestor'` em `publico`. Lista vazia mantém comportamento anterior (todos os gestores veem). RH, Admin e Diretoria não são afetados por `colaboradores_ids`.

**Espaçamento global da Home (out/2026):** `.home-dash { gap:10px; padding:20px 24px 40px }` — era `gap:12px; padding:24px 24px 48px`. Card interno: `padding:14px; gap:8px` — era `16px/10px`.

**Fix tempo de casa — data_ingresso_grupo (commit `25b3262`, out/2026):** `_colSelectHome` passou a incluir `data_ingresso_grupo` na query da equipe. `_renderEventos` calcula o aniversário de empresa com `_refCasa = c.data_ingresso_grupo || c.data_admissao` — mesma regra já adotada em Relatórios e Cadastro. Card sidebar e modal "Ver todos" corrigidos. Férias, admissão e demais rotinas inalteradas. Autoatendimento ainda usa `data_admissao` (avaliação pendente).

**Layout de duas colunas — Home Gestor (commit `fd54464`, out/2026):** `#container-home-dashboard > .home-dash` usa `display:grid; grid-template-columns:1fr 288px; gap:16px; align-items:start`. Coluna principal `.hd-main` (flex column, gap:10px) contém: saudação, módulos, comunicados, férias, atividades. Coluna lateral `.hd-sidebar` (flex column, gap:10px, `position:sticky; top:20px`) contém os dois cards de eventos (Aniversariantes + Tempo de Casa). Cards de eventos na sidebar exibem lista vertical de pessoas: `hd-person-grid` vira `flex-direction:column`, cada `hd-person-col` vira row com avatar 38px + `.hd-person-info` (wrapper com nome + detalhe em coluna). Override via seletores `.hd-sidebar .hd-person-*`. Função `_personColHtml` ganhou wrapper `<div class="hd-person-info">` para agrupar nome+detalhe no layout row. **Breakpoints:** `≤900px` → `.home-dash { grid-template-columns:1fr }` + sidebar em grid `1fr 1fr` + layout horizontal de pessoas restaurado; `≤700px` → sidebar `grid-template-columns:1fr`. IDs dos cards de eventos (`hd-aniv-list`, `hd-casa-list`, `hd-aniv-vertodos`, `hd-casa-vertodos`) e toda a lógica JS preservados — apenas CSS reorganizado.

**Parâmetros (`modulos/parametros/index.html`):** seção "Comunicados da Home" no CATS (`aviso_home`). Formulário compacto (`.modal--compact`) com checkboxes de perfis múltiplos (Todos / Gestores / RH / Diretoria) + busca de colaboradores específicos com chips removíveis. Título clicável na lista abre o modal diretamente. Campo `corpo` é `type:'richtext'` — editor `contenteditable` com barra de ferramentas (N/I + 6 cores) em vez de textarea (commit `4eb027e`). Enter insere `<br>` via `insertLineBreak` (commit `eb91829`). Save chama `_avSanitizarCorpo()` — converte `<div>` em `<br>`, permite apenas b/strong/i/em/span(color)/p/br. Home: card preview usa `innerHTML` direto + `white-space:pre-wrap` + `-webkit-line-clamp:3` (commit `54e9b4b`); float card e modal "Ver todos" também usam `innerHTML`. Formatação idêntica nas duas visões.

**Abas do modal (ao editar):** duas abas — "Formulário" (padrão) e "Histórico" (criado em / última alteração + accordion histórico de alterações). Ao criar: sem abas. Função `avSwitchTab(tab)` controla alternância. Informações de auditoria em `#avAuditBlock` (aba Histórico), nunca em `#modalFields`.

**Checkboxes de destinatários (commits `496d1c6`, `1fa88c1`):** solução definitiva usa labels com `for=` + `addEventListener('change', ...)` programático após `insertAdjacentHTML`. `onchange` inline e event delegation não eram confiáveis. Labels têm estilos inline sobrescrevendo `.field label` (`text-transform:none`). Funções `avToggleTodos`/`avTogglePerfil` ainda existem no código (não remover — legado).

**Dropdown gestores específicos (commit `1fa88c1`):** `avColabDropdown` movido para `document.body` após abertura do modal (`document.body.appendChild`) e removido em `fecharModal` (`avDd.remove()`). Fix para stacking context do modal que sobrepunha o footer ao dropdown. Busca usa `avBuscarGestor` (query em `param_gestor` com `SB_HEADERS`/JWT) em vez de `avBuscarColab` (colaboradores). `param_gestor.colaborador_id` deve estar preenchido; gestors sem ele são filtrados.

**Layout formulário (commit `7153908`):** campo `tipo` width 2→4; `data_inicio` e `data_fim` (ambos width 2) ficam lado a lado na mesma linha.

**RLS:** sem policy anon; `_hdGet` envia JWT → role `authenticated`; SELECT filtra `'todos' = ANY(publico) OR auth_perfil() = ANY(publico) OR (colaboradores_ids @> ARRAY[auth_colaborador_id()]) OR auth_perfil() IN ('admin','rh')`.

---

## Home do Gestor — Escopo adicional de aniversariantes (migration 133, validado em produção out/2026)

**Commits:** `f954d15` (feature), `f1f5f46` (fix Parâmetros), `460ca6a` (fix busca param_gestor)

**Nova tabela `param_escopo_home`:** escopo adicional de visualização na Home, independente de Férias. Campos: `gestor_id INTEGER` (FK para `param_gestor.id`), `modulo TEXT` (`'aniversarios'` agora; extensível), `tipo` (gestor/empresa_atuacao/setor/tipo_vinculo/cargo/colaborador/todos), `valor`, `valor2 TEXT` (nullable — empresa de atuação opcional para tipo_vinculo), `gestor_ref_id`, `ativo`. Sem RLS própria — mesmo padrão de `param_escopo_ferias`. **Migrations 133 (tabela) e ALTER TABLE valor2 aplicadas manualmente no Supabase Dashboard.**

**Parâmetros Gerais — escopo_home** (commits `1e83e0b`, `e3c718c`, `d46ddb4`, out/2026): seção renomeada para "Home". Renderização com dois níveis: card por gestor (nível 1) + linha por grupo `modulo+tipo` com chips de valores condensados (nível 2, commit `d46ddb4`). Modal redesenhado para seleção múltipla por grupo — criação: INSERT de N chips de uma vez; edição: diff chips (INSERT novos, DELETE removidos, inalterados sem ação); duplicatas e registros inativos preservados sem reativação. `allRows` flat inalterado. Banco sem migration.

**Home (`index.html`):** `_resolverEscoposHome(gestorId, modulo, idsBase, colSelect)` resolve escopos localmente sem dependência de Férias. `renderHomeGestor` separa `team` (equipe base) de `teamAniversarios` (base + extras). Apenas `_renderEventos` usa `teamAniversarios`. Tipos suportados: gestor, empresa_atuacao, setor, tipo_vinculo (com valor2 para empresa), cargo (normalização NFD), colaborador, todos. Tipos cargo/tipo_vinculo/colaborador sem filtro CLT.

**Bug crítico corrigido (commit `460ca6a`):** `param_gestor` NÃO tem coluna `gestor_id` — a busca original `param_gestor?gestor_id=eq.${uid}` sempre falhava silenciosamente, fazendo `apelido` cair no fallback de primeiro nome (ex: "CARLOS" em vez de "JUNINHO") e `pgGestorId` ficar nulo. Corrigido para `colaborador_id=eq.${p.colaborador_id}`. Todos os 15 gestores ativos têm `colaborador_id` preenchido. Validado em produção (19/10/2026).

---

## Módulo Férias — Histórico: rótulos e datas legíveis (commits `36f2e77`, `b5e47e4`, out/2026)

`acaoLabel`/`acaoCor` nas funções `renderDrawerAuditoria` (RH) e `_renderGsolHistoricoAuditoria` (Gestor) agora cobrem todas as ações presentes no banco: `gozo_solicitado`, `lancado_rh`, `editado_rh`, `excluido_rh`, `gestor_ciente`. `perStr` unificado para ler `inicio||saida||inicio_novo` e `fim||retorno||fim_novo`. Footer "+Nova solicitação" corrigido para aparecer só na aba Férias. Registros de teste `gestor_ciente_teste` (ids 21,22) removidos do banco.

---

## Módulo Férias — Relatório mensal: filtro por início + acordos de gozo (commit `b7c67dd`, out/2026)

**Regra de filtro:** relatórios RH e Gestor agora incluem apenas períodos com `inicio` dentro do mês — não basta sobreposição. Gantt/Mapa Anual/drawer inalterados. **Validado em produção (19/10/2026).**

**Escala do Gestor (commit `549b8cc`):** `_getDadosEscalaGestor` usava filtro de sobreposição (`inicio > mesFim || fim < mesInicio`), incluindo férias iniciadas no mês anterior. Corrigido para `inicio` dentro do mês — mesmo critério do RH. PDF e Excel do Gestor usam a mesma função; ambos corrigidos com uma linha.

**Realizações (acordos Daniele-type):** `_getDadosRelatorio` passou a iterar `reg.realizacoes` além de `reg.lancamentos`. Condições: `saida` no mês, lançamento pai (`lancIdx`) fora do mês, dedup por `saida` por colaborador (`_realizSet`). `gestorGerarRelatorio` ganhou bloco de dedup usando `_parentLancsPresentes` (por `periodo_id`) e `_seenRealizacoes` (por `colaborador_id|inicio`).

**Correção de dado — Anderson (row 1864):** PA 2022 com `periodo1_inicio='2026-11-02'` (data incorreta no fallback flat-fields) gerava 20 dias fantasmas no relatório de novembro/2026. Corrigido via `PATCH ferias?id=eq.1864` com `{"periodo1_inicio": null}`. Realizações históricas preservadas.

**Heloisa (row 1016):** PA 2025 com `periodo1_inicio='2026-01-26'` — mantido sem alteração até confirmação de que o agendamento era válido.

**Padrão de risco:** buscar `ferias?pa_fim=lt.2025-01-01&periodo1_inicio=not.is.null&periodos=eq.[]` para encontrar outros registros com data incorreta no fallback. Ver seção completa na skill `ferias.md`.

---

## Módulo Processos — Melhorias UX checklist admissão (commits `cf928bf`→`9fcb7ab`, out/2026)

Item "Cadastro no sistema concluído" removido de `CHECKLISTS.admissao` e `GRUPOS_ADMISSAO` (redundante). Meta de conclusão compacta: `✓ [primeiro nome]` com tooltip completo no hover. "Não utiliza" por item em Benefícios e Planos & Seguros: botão ⊘ aparece no hover junto ao texto, grava `concluido=true + observacao='N/A: não utiliza'`, texto cinza + rótulo vermelho, reversível com ↩. `ITENS_NAO_UTILIZAVEL` derivado da flag `naoUtilizavel: true` nos grupos. Funções: `marcarNaoUtiliza` / `reverterNaoUtiliza`.

**Alelo em todas as admissões (commit `f60520a`):** condição `if (/vendedor/.test(cargo))` removida — cargo é sempre null na criação (pré-efetivação). Item incluído em todos os checklists; não-utilizadores marcam "Não utiliza". Processos abertos corrigidos via SQL INSERT.

**Ordem grupo Sistemas (commit `4b6442f`):** Fronter → Sênior → Solicitar e-mail TI. Processos existentes corrigidos via UPDATE na coluna `ordem`.

**Item "Cadastro no sistema concluído" em processos antigos:** gravado no banco antes da remoção do código, aparecia no grupo fallback "📌 Outros". Removido dos processos abertos via SQL DELETE. Grupo "📌 Outros" mantido intencionalmente como rede de segurança — não remover.

---

## Módulo Processos — Badge urgência e agrupamento restritos a demissões (commits `9341113`, `0f0f0d7`, `e57fbe6`, out/2026)

`⚠ Prazo vencido` e `⏰ Vence hoje` em `buildCard` só aparecem quando `p.tipo === 'demissao'`.

Datas de prazo nos itens do checklist exibidas apenas em demissões (`tipo === 'demissao'`); para admissão, VT e outros: items visíveis sem datas.

Agrupamento "Atrasados / Próximos / Em andamento" governado por `TIPOS_COM_PRAZO_REGULATORIO = new Set(['demissao'])` explicitamente nas três linhas de `_renderAndamento` — sem sentinela numérico artificial. `_diasRestantesProcesso` é cálculo puro de dias; regra de exclusão fica no agrupamento. Skill `processos.md` atualizada.

---

## Módulo Admissão — Modais ocultos atrás do painel (commits `a4cb980`, `e6d13af`, out/2026)

Modais (`modalPDF`, `modalEfetivar`, `modalAprovar`, `modalCancelamento`) ficavam atrás do painel de revisão. Causa: `panel-overlay` tem `position:fixed; z-index:300`, criando contexto de empilhamento próprio — modais declarados antes dele no DOM não conseguem renderizar acima, mesmo com `z-index:500`. Fix: modais movidos para **depois** do `#panelOverlay` no HTML + `z-index:500` em cada um. Regra documentada na skill `admissao.md`. Validado em produção (20/10/2026).

---

## Módulo Admissão — "Ver ficha" no card aprovado (commit `4bc23c4`, out/2026)

Card com `status='aprovado'` agora exibe dois botões separados: **"Ver ficha"** (secundário, consulta dados e faz upload de documentos sem efetivar) e **"Efetivar contratação"** (verde). Ambos abrem o mesmo painel via `verFicha(token)`. A efetivação real só ocorre ao confirmar o modal dentro do painel. Skill `admissao.md` atualizada.

---

## Home — Fix avatar modal sem foto (commit `502fa41`, out/2026)

`.hd-modal-av` estava sem `display:flex; align-items:center; justify-content:center; color:#fff` — iniciais de colaboradores sem foto apareciam desalinhadas no modal "Ver todos" de aniversários. Adicionadas as 4 propriedades ao CSS. Demais classes de avatar (`.hd-mini-av`, `.hd-act-av`, `.hd-ferias-stack-av`, `.hd-person-av`, `.proto-avatar`, `.search-dd-avatar`, `.gantt-av`, `.an-cal-av`) já tinham flex correto — sem alteração.

---

## Módulo Home — Tipos "Tipo de vínculo" e "Cargo" no escopo Home (commits `6a24816`, `f62784d`, out/2026)

`param_escopo_home` aceita `tipo='tipo_vinculo'`: valor armazena `codigo` de `param_tipo_vinculo`; `valor2` opcional para filtrar também por `empresa_atuacao` (normalizada). Sem filtro CLT — inclui promotoras, pró-labore etc. `param_escopo_home` aceita `tipo='cargo'`: valor armazena nome do cargo (DISTINCT de colaboradores ativos); normalização lowercase+trim+NFD para comparação robusta. Sem filtro CLT. `carregarCargos()` popula `cargosList[]` no módulo Parâmetros. `_colSelectHome` já inclui `tipo_vinculo,empresa_atuacao` (confirmar que inclui `cargo` também na query de equipe quando necessário).

---

## Módulo Home — Tipo "Colaborador específico" no escopo Home (commit `3a6562c`, out/2026)

`param_escopo_home` aceita `tipo='colaborador'`: valor armazena o `colaborador_id` como string, `gestor_ref_id = null`. Parâmetros Gerais: opção adicionada ao dropdown Tipo; Valor lista todos os colaboradores ativos (CLT + promotoras + pró-labore). `_resolverEscoposHome` no `index.html` busca por `id=eq.{valor}` sem filtro CLT. Escopos existentes não afetados.

---

## Módulo Admissão — Rotação de documentos com persistência (commits 4f4c5d4, 816501c, 9888e2f, out/2026)

RH pode girar imagens na aba Anexos da ficha. Rotação salva em `admissao_fichas.docs` JSONB como `_rot_<key>`. Lightbox interno (`#imgLightbox`) abre imagens com `transform:rotate()` aplicado. PDFs abrem em nova aba normalmente. Geração do PDF da ficha já aplicava `_docRotations` — inalterado. Autenticação via `SB_HEADERS` (não `HDR`).

---

## Módulo D&P — Melhorias UX e fix upsert (out/2026)

**Commits:** `2725b25` (nome clicável na aba Avaliações), `a68631e` (fix 409 upsert dp_respostas)

- **Nome clicável:** nome do colaborador na lista de avaliações abre o formulário conforme status (avaliar/visualizar/nada para não participante). Funciona em RH e Gestor via `dpRenderAvaliacoes`. Botões de ação preservados.
- **Fix 409:** `sbUpsert` em `dp_respostas` agora usa `?on_conflict=avaliacao_id,versao_criterio_id` — resolve o erro ao salvar avaliação retomada (em andamento). **Regra:** todo `sbUpsert` deve incluir `?on_conflict=<colunas_unique>` na URL; sem isso o PostgREST usa a PK implicitamente e falha.
- **Fix status na lista:** `salvarAvaliacao` agora chama `_dpRenderAvaliacoesComFiltro()` após `fecharFormAval()` — status "Respondida"/"Em andamento" atualiza imediatamente na lista sem reentrar no ciclo. Commit `ffc789d`.

---

## Módulo D&P — "Não participará" na aba Participantes (commit c30e31e, 2026-10-16)

Botão ⊘ e badge "⊘ Não participa" adicionados a `dpRenderParticipantes`. Disponível para RH/admin em ciclos `aberto`/`em_andamento` (não em rascunho, não na visão do gestor). Reutiliza modal, RPCs e permissões existentes sem duplicação. Após marcar/reverter, ambas as abas (Participantes e Avaliações) são re-renderizadas automaticamente. Aba Avaliações inalterada.

---

## Módulo D&P — Status "Respondida" + Redesign Avaliações (2026-10-16)

**Commits:** `6a9cdb6`, `fe1463d`, `618fd69`, `c7a4da8`, `c4f13b0`, `0684f76`, `5e08f7a`, `f2698e1`, `e7d1dfb`, `1a5fe90`

### Status "Respondida" (migrations 130, 131, 132)

Novo status intermediário no ENUM `dp_status_avaliacao` entre `em_andamento` e `concluida`.
- Auto-detectado em `salvarAvaliacao` e `_dpSalvarParaNavegar` quando todos os critérios obrigatórios estão preenchidos
- Frontend guard em `dpConcluirAvaliacaoIndividual`: só conclui se `status === 'respondida'`
- Backend trigger `trg_validar_conclusao` (migration 131): bloqueia `status→concluida` se critérios incompletos
- 9 avaliações corrigidas de `em_andamento` → `respondida` via migration 132

### Redesign visual da aba Avaliações

- Avatar circular com foto real (de `_colaboradores.foto_url`) + fallback iniciais coloridas (`_dpAvatarColor`)
- Bolinha de status (11px) sobreposta no canto inferior direito do avatar, cor = cor do KPI
- Badge de status visível para **todos** os status (antes só para concluída)
- Layout de 4 colunas fixas: `[avatar] [flex:1 info] [120px badge] [120px botões]` — alinhamento garantido
- Botões ícone-only 30×30px com tooltip: clipboard=Avaliar, olho=Visualizar, check-verde=Concluir, lápis=Editar(RH), ⊘=Não participante
- Barra de progresso conta `respondida + concluida` (antes só `concluida`); texto "X respondidas · Y%"
- KPI cards com fundo sempre preenchido (não só branco)
- Bug corrigido: `${badgeLeft}` referenciando variável inexistente causava loop de carregamento

**Estado D&P atual:**
- Ciclo Setembro/2026: 70 não iniciadas · 1 em andamento · 9 respondidas · 1 concluída
- Ciclo Outubro/2026: rascunho — não abrir sem aprovação da usuária

---

## Módulo D&P — Otimizações de Performance (2026-10-16 → 2026-10-23)

**Commits:** `fca3346`, `a96bea9`, `4671245`, `172f23f`

O módulo D&P recebia reclamações de lentidão perceptível. Diagnóstico e otimizações aplicadas em dois ciclos:

### Ciclo 1 (commits fca3346/a96bea9/4671245, 2026-10-16)

| Gargalo | Fix |
|---|---|
| Critérios/escalas re-buscados a cada colaborador | `_dpFormCache` — cache de dados estáticos da versão |
| N RPCs de histórico (1 por critério) | Migration 128: `dp_fn_historico_criterio_batch` — 1 HTTP por abertura |
| Aba Resultados/Histórico recarregando sempre | Guards `_dpResultadosCicloId` / `_dpHistoricoCarregadoCicloId` |
| Drawer Gestor re-buscando ciclo+versão | `_gdpCiclosCarregados` — cache do `gestorDpLoadCiclos` |
| 2 queries para resultados + bônus | PostgREST embed `dp_resultados?select=*,dp_resultados_bonus(*)` |
| `.find()` O(n²) no render loop | Maps O(1) antes do loop |
| `dpRegistrarEvento` bloqueando abertura | Fire-and-forget (sem `await`) |
| `gestorDpLoadCiclos` sequencial | `Promise.all` versoes + participantes |

### Ciclo 2 (commit 172f23f, 2026-10-23) — abertura e fechamento sem bloqueio

| Gargalo | Fix |
|---|---|
| Abertura bloqueada por batch RPC (400–700ms) | Batch disparado em background (fire-and-forget); formulário abre após sbGet de respostas apenas |
| Guard de corrida na navegação rápida | `_thisAvalId = aval.id` capturado antes do fire-and-forget; resultado descartado se usuário navegar |
| Chips de histórico bloqueavam render | `<span id="dp-hist-{vc.id}">` renderizado vazio; preenchido por `_dpAtualizarChipsHistorico()` após batch |
| Fechamento travava tela (~400ms re-render) | `setTimeout(0)` em `salvarAvaliacao`: `fecharFormAval()` executa antes, lista re-renderiza no próximo tick |
| Integridade preservada | `fecharFormAval()` só chamado após `await sbUpsert` + `await sbPatch` confirmados; em erro, formulário permanece aberto |

**Migrations executadas em produção:**
- `127_dp_rls_bonus_gestor.sql` — SELECT de `dp_resultados_bonus` para gestor (2026-10-16)
- `128_dp_historico_batch.sql` — função `dp_fn_historico_criterio_batch` (2026-10-16)

**Estado pós-ciclo 2:** aguardando validação da usuária no ambiente real. Custo de re-render de 82+ cards (~400ms) permanece, mas foi deslocado para fora da percepção (após fechamento do modal).

**Why:** usuária reportou lentidão generalizada no módulo D&P, especialmente ao clicar em "Avaliar" e ao salvar. Performance é pré-requisito para o ciclo de outubro entrar em produção.

**How to apply:** ao trabalhar no D&P, respeitar os padrões de cache — nunca remover os guards, o `_dpFormCache` ou o `setTimeout(0)` sem entender o impacto.

---

## Home Dashboard do Gestor — UX/UI revisado 2026-10-09 (commits 3eabdf4 → 37f4835)

**Redesign visual completo aprovado e implementado. Regras de negócio, queries, RLS e segurança salarial intactas.**

### Visual atual

- **Layout**: `display:flex; flex-direction:column; gap:12px` — mais compacto, sem margens entre seções
- **Módulos**: tiles centralizados, ícone 52px + nome 14px bold, sem descrição; grid `minmax(140px,1fr)`
- **Cabeçalho (saudação)**: avatar 80px (era 46px), título 22px (era 18px), padding 24px 28px (era 16px 20px) — fundo e cores inalterados
- **Aniversários e Tempo de Casa**: janela de busca 60 dias (era 30 dias); layout horizontal (`hd-person-grid`), 3 registros mais próximos exibidos no card
  - Avatar 46px com foto (background-image) ou iniciais (fallback `_avHtml`)
  - `ring-today` (amber) = aniversário hoje; `ring-top` (verde) = maior tempo de casa
  - Nome: 2 primeiros nomes completos, 10px bold, max-width 76px
  - Aniversários: data em cinza claro abaixo do nome (sem pill com fundo); "Hoje!" em âmbar
  - Tempo de Casa: anos em verde texto (`hd-years-text`, sem fundo) + data do aniversário de empresa abaixo; troféu 🏆 (`.hd-marco-icon`, 11px) inline após os anos para marcos ativos de `param_marco_tempo_casa` — mesmo indicador no modal "Ver todos" (commit `22eba53`)
- **Botão "Ver todos →"**: aparece sempre que há registros (`length > 0`), independente do limite visual
  - **Filosofia**: Home = resumo compacto; "Ver todos" = porta para consulta completa
  - Modal exibe lista completa (todos os 60 dias) com: `_avHtml` (foto + fallback) + nome + cargo · setor + data em cor de acento; **sem subtítulo de contagem** (removido 2026-10-09)
  - Cargo e setor já disponíveis na query de equipe — sem query adicional
  - Preparado para futura visão de Diretoria (contexto de cargo/setor essencial para equipe grande)
- **Férias da equipe**: dois stats (em gozo / agendadas 30 dias) com número grande + stack de avatares sobrepostos (máx 5 fotos + "+N") + linha de nomes resumida + botão "Ver todos" sempre visível quando há pessoas; modal abre foto + nome + cargo + período com contagem de dias (`DD/MM → DD/MM · N dias`). Fonte: `periodos[]` JSONB por item (aprovado/agendado), fallback campos flat para registros legados. Deduplicação por `colaborador_id` em ambos os contadores. `_openModal` é função global (escopo de script), não local a `_renderEventos` — acessível por qualquer função da Home. (commits 5ff0387, 446292e, 219688a, 0422888, 5f8a1be, eaebfc2 — 2026-10-13)
- **Atividades**: badge colorido por tipo (`.promocao`, `.reajuste`, `.ferias`, `.avaliacao`, `.admissao`, `.doc`) + título sem redundância cargo/nome
  - Promoção: título = "Cargo · Nome", resumo = só percentual + mês/ano
  - Reajuste: título = nome, resumo = completo com "cargo mantido"
- **Títulos de seção**: removidos; títulos agora ficam dentro de cada card
- **Ícones de card**: bolo (âmbar, 36px) e relógio (verde, 36px) — aumentados de 30px em 2026-10-13
- **Topbar variante Gestor**: classe `.topbar-gestor` aplicada via JS no início de `renderHomeGestor` — fundo branco, sombra sutil, texto escuro. Não afeta admin nem outros perfis.
- **Bell de pendências** (commits `54b1987`→`01c10d7`, 2026-10-13): sininho na topbar exibe badge com contagem total de pendências de férias. Clicar abre painel suspenso (`.bell-panel`, `position:absolute`). Primeiro 5 itens + "Ver mais N itens" (expansão inline). Cada item tem `href` próprio via `_getItemHref(h)`. Fecha ao clicar fora. Badge 18px com animação `bell-pulse` (pulso vermelho a cada 2,4s).
  - **Duas categorias** no painel — dot azul + chip "Ag. Ciente" (RH respondeu, Gestor precisa confirmar) e dot âmbar + chip "Ag. RH" (Gestor solicitou, aguardando RH). "Ag. Ciente" aparece primeiro.
  - **`_loadPendencias`** consulta `ferias_historico` + tabela `ferias` em paralelo (`Promise.all`). Registros com `status solicitado/pendente` na tabela `ferias` sem entrada no histórico são injetados como fallback `_fallback:true` — espelha o mesmo mecanismo do módulo Férias. Historico prevalece sobre fallback no mesmo `ferias_id`.
  - **Janela de tempo**: "Ag. Ciente" respeita `dias_resposta_visivel` de `param_ferias_config` (produção = 10 dias); "Ag. RH" sem limite (item permanece até RH responder).
  - **Validação de órfãos**: candidatos "Ag. RH" vindos do `ferias_historico` (não fallback) são cruzados com a tabela `ferias` para descartar `ferias_id` inexistentes.
  - **`ACOES_CIENTE`**: `aprovado | rejeitado | alteracao_aprovada | alteracao_recusada | cancelamento_aprovado | cancelamento_recusado` — **nunca** `_rejeitada` ou `_rejeitado`
  - **`ACOES_AGUARDANDO`**: `solicitado | alteracao_solicitada | cancelamento_solicitado`
  - Routing extensível: `_BELL_MODULO_MAP` (ação → módulo) + `_BELL_MODULO_HREF` (módulo → URL). Novo módulo = entradas nesses dois objetos + labels em `_BELL_ACAO_LABEL`.

### Regra crítica do modal
**Nunca recriar lógica de avatar no modal.** Sempre usar `_avHtml(nome, foto_url, 'hd-modal-av')`.
Bug anterior: modal usava `r.foto` (campo inexistente) em vez de `r.foto_url` → fotos não apareciam.

---

## Home Dashboard do Gestor (aprovado 2026-10-08, commit 118a75d)

**Arquivo:** `index.html`

**Arquitetura reutilizável:**
- `routeHomePerfil(p)` — dispatcher; perfil `gestor` esconde `.container` e mostra `#container-home-dashboard`; perfis futuros (RH, Diretoria) só precisam de `else if` aqui
- `renderHomeGestor(p)` — lê `sb_perfil` + consultas Supabase somente leitura; delega rendering para `_renderFeriasHints`, `_renderEvents`, `_renderDates`, `_renderModules`, `_renderAtividades`

**REGRA CRÍTICA — constantes antes da IIFE (TDZ):** As constantes `_AV_COLORS`, `_HD_URL` e `_HD_KEY` estão declaradas **ANTES** da IIFE RBAC (linha ~415 em `index.html`) — e **nunca devem ser movidas para depois**. O motivo é o JavaScript Temporal Dead Zone (TDZ): `const` declaradas depois da IIFE já não estão inicializadas quando a IIFE chama `routeHomePerfil → renderHomeGestor` sincronamente. O `_hdGet` tem `try/catch` que silencia o `ReferenceError` e retorna `[]`, causando a foto do gestor não aparecer — sem nenhum erro visível no console. **Padrão: toda constante usada dentro de `renderHomeGestor` (ou qualquer função chamada sincronamente pela IIFE) deve ficar antes da IIFE.** Commit do fix: `e766d3e`.

**Foto do Gestor (fix 2026-10-08, commit e766d3e):** `colaborador_id` vem de `sb_perfil` (gravado em `login.html` via SELECT `usuarios_perfil` que inclui esse campo). A `renderHomeGestor` faz `_hdGet('colaboradores', 'id=eq.${p.colaborador_id}&select=foto_url')` para buscar a URL e aplica via `backgroundImage`. Funcionou só após mover `_HD_URL`/`_HD_KEY` para antes da IIFE — o `_hdGet` silenciava o TDZ com `catch`.

**Dados consumidos (somente leitura, sem escrever):**
| Dado | Query |
|---|---|
| Equipe | `colaboradores?gestor=ilike.${apelido}&data_demissao=is.null` — mesma query do módulo Férias |
| Apelido do gestor | `param_gestor?gestor_id=eq.${uid}` — mesma tabela do módulo Férias |
| Férias | `ferias?colaborador_id=in.(...)&select=colaborador_id,status,periodos,periodo1_inicio,periodo1_fim,periodo2_inicio,periodo2_fim` — periodos[] JSONB como fonte principal; campos flat como fallback |
| Atividades | **`v_historico_eventos_home`**`?colaborador_id=in.(...)&select=id,colaborador_id,tipo,titulo,resumo_home,data_evento&order=id.desc&limit=5` |
| Datas | `data_nascimento`, `data_admissao` da equipe (já carregados na query de equipe) |
| Marcos tempo de casa | `param_marco_tempo_casa` — `select=anos&ativo=eq.true` — `.catch(()=>[])` isolado; falha silenciosa (sem troféus), não bloqueia Home |

**Segurança salarial na Home — REGRA OBRIGATÓRIA:**
- A Home do Gestor nunca deve buscar nem exibir `salario_anterior` ou `salario_novo`.
- Atividades são lidas de `v_historico_eventos_home` (view segura), não de `historico_eventos`.
- Eventos `reajuste_salarial` e `promocao` retornam em `resumo_home` apenas: percentual (`+6%`), mês/ano (`ago/2026`) e cargo (`novo cargo: Vendedor(a) Pleno`).
- Demais eventos retornam o `resumo` original (auditado — sem valores nominais).
- Fonte oficial completa da timeline continua sendo `historico_eventos` (imutável). A view é somente camada de apresentação.
- **Nunca substituir a view por query direta a `historico_eventos` na Home** — violaria o princípio de privacidade salarial aprovado.

**View `v_historico_eventos_home` — migration 111:**
- Arquivo: `migrations/111_v_historico_eventos_home.sql`
- Status: executada no Supabase (2026-10-08)
- Campos expostos: `id, colaborador_id, tipo, titulo, data_evento, resumo_home`
- Campos NUNCA expostos: `dados` (JSONB completo), `resumo` original de eventos salariais, `salario_anterior`, `salario_novo`
- RLS: SECURITY INVOKER (padrão) — respeita as políticas RLS de `historico_eventos` normalmente

**Layout Últimas Atividades:**
- `hd-act-title`: nome do colaborador + descrição (linha superior, largura total)
- `hd-act-footer`: `hd-act-sub` (resumo_home) à esquerda + `hd-act-time` (data) à direita — flex, mesma linha
- CSS: `.hd-act-footer { display:flex; justify-content:space-between; align-items:baseline; gap:8px }`

**Módulos na Home — `_renderModules(p)`:**
- Exibe SOMENTE os módulos presentes em `p.acesso_modulos` — nunca mostra tiles "Em breve"
- Usa `filter(m => !acesso.length || acesso.includes(m.chave))` — sem fallback de "Em breve"

**Princípio aprovado:** Home é camada de apresentação/resumo. Regras oficiais pertencem ao respectivo módulo. KPI "em férias hoje" é estimativa visual (ini <= hoje <= fim), não réplica da lógica do módulo Férias.

**Módulos de RH e Diretoria:** NÃO desenvolver ainda. Validar a Home do Gestor em uso primeiro.

**RBAC:** inalterado. `_renderModules(p)` usa `p.acesso_modulos` para gerar atalhos — não cria novas permissões.

---

## O que é o SistemaRH

Sistema interno de RH da Revest do Brasil, hospedado no **GitHub Pages**:
`https://danieledalosse-a11y.github.io/SistemaRH`

Repositório local: `C:\Users\reves\SistemaRH`
Deploy: automático do branch `main` após push (1–3 min de delay).

**Não usar Netlify** — migrado para GitHub Pages.

**Tecnologia:** HTML/CSS/JS puro — sem framework. Consome Supabase via REST API com publishable key no browser.

---

## Recursos compartilhados — arquitetura (commit `5c82b82`, 2026-10-13)

### `shared.css` — fonte única de estilos compartilhados

Arquivo na raiz do projeto. Contém estilos reutilizáveis entre módulos e Homes.

**Carregamento:**
- `index.html` (Home): `<link rel="stylesheet" href="shared.css">` no `<head>`
- Módulos: carregado automaticamente via `permissoes.js` (injeção dinâmica no `<head>`)

**Componentes disponíveis:**
- `.btn-sair` — botão Sair com ícone SVG logout + texto "Sair", padrão topbar azul

### `.btn-sair` — padrão visual

```css
/* shared.css — padrão topbar azul (módulos e futuras Homes com topbar escura) */
.btn-sair { display:inline-flex; align-items:center; gap:5px; background:none;
  border:1px solid rgba(255,255,255,0.30); border-radius:7px; cursor:pointer;
  color:rgba(255,255,255,0.75); font-size:12px; font-weight:500;
  padding:5px 10px; margin-left:4px; font-family:inherit; transition:... }
.btn-sair:hover { border-color:#fff; color:#fff; background:rgba(255,255,255,0.08); }
```

**Override topbar branca (Home Gestor) — em `index.html`:**
```css
.topbar-gestor .btn-sair { border-color:var(--border); color:var(--text-ter); background:var(--bg); }
.topbar-gestor .btn-sair:hover { border-color:var(--text-sec); color:var(--text); background:var(--border); }
```

**Regra para futuras Homes:** topbar azul herda automaticamente; topbar branca adiciona `.topbar-<perfil> .btn-sair { ... }` em `index.html`.

### Módulo `colaborador` — exceção

`modulos/colaborador/index.html` (Ficha do Colaborador) **não carrega `permissoes.js`** e não usa `.btn-sair` — tem topbar e design próprios. Essa é a única exceção intencional.

### Regra obrigatória para novos módulos

Todo `modulos/<nome>/index.html` deve incluir no `<head>`:
```html
<script src="../../permissoes.js"></script>
```
Isso garante automaticamente: autenticação (`guardModulo`), carregamento de `shared.css` e todos os padrões visuais compartilhados. Documentado em `CLAUDE.md` (seção "Recursos compartilhados").

---

## Módulos implementados

| Módulo | Caminho | Skill | Status |
|---|---|---|---|
| Home | `index.html` | `home` | ✅ |
| Login | `login.html` | — | ✅ |
| Cadastro de Colaboradores | `modulos/cadastro/index.html` | — | ✅ |
| Férias | `modulos/ferias/index.html` | `ferias` | ✅ |
| Admissão Online (candidato) | `admissao-online.html` | `admissao` | ✅ |
| Admissão (painel RH) | `modulos/admissao/index.html` | `admissao` | ✅ |
| Desenvolvimento & Performance | `modulos/desenvolvimento/index.html` | `desenvolvimento` | ✅ |
| Workflow (Processos RH) | `modulos/processos/index.html` | `processos` | ✅ |
| Uniformes & EPI | `modulos/uniformes/index.html` | `uniformes` | ✅ |
| Autoatendimento (colaborador) | `modulos/autoatendimento/index.html` | — | ✅ (pendente validação RLS) |
| Central de Relatórios | `modulos/relatorios/index.html` | `relatorios` | ✅ |

---

## Central de Relatórios — arquitetura (adicionado 2026-09-16)

**Arquivo:** `modulos/relatorios/index.html` — módulo standalone, sem dependência do Cadastro.

**Padrão RELATORIOS dict:** cada relatório é uma entrada no objeto `RELATORIOS` com `cat`, `title`, `desc`, `note`, `renderFiltros()`, `pdf()`, `excel()`. Adicionar novo relatório = nova entrada no dict + card HTML na central + implementar `_dados*()`, `gerar*PDF()`, `gerar*Excel()`.

**6 relatórios implementados:** Aniversários do Mês, Tempo de Casa, Dependentes, Por Empresa/Setor, Por Gênero, PCD e Jovem Aprendiz.

**Query enxuta:** só os campos necessários para relatórios (`id, nome, cargo, data_admissao, data_nascimento, data_demissao, empresa_registro, empresa_atuacao, setor, gestor, sexo, pcd, pro_labore, dependentes_lista`).

**Regra obrigatória Excel:** `<x:WorksheetOptions>` deve sempre ter `<x:DisplayGridlines/>` — WorksheetOptions vazio causa erro "Desconhecido" no Excel.

**Painel lateral:** filtros e botões PDF/Excel ficam no `.detail-panel` (width: 0→360px), nunca diretamente nos cards.

**Independência do Cadastro:** funções como `_dadosCadastro`, `gerarCadastroPDF`, `gerarCadastroExcel`, `_dadosCotas` são reimplementações autônomas — não chamam código do Cadastro.

---

## Módulo Cadastro — ícone olho (acesso direto à Ficha, 2026-10-08)

**Commit:** `ad249dd`

Botão `.btn-ver-ficha` adicionado na célula do colaborador, logo após o símbolo de gênero — mesma linha, sem alteração de layout.

**Estrutura HTML da célula:**
```
${listAvatar}${c.nome}${sexoIcon}${c._sbId ? `<button class="btn-ver-ficha" ...>👁</button>` : ''}
```

**Comportamento:**
- Clique na linha → `abrirFicha(idx)` → abre o drawer do Cadastro (igual antes)
- Clique no olho → `event.stopPropagation(); window.open('../colaborador/index.html?id=${c._sbId}','_self')` → abre Ficha Completa
- Ícone só aparece quando `c._sbId` está preenchido
- Tooltip "Ver Ficha Completa" via `.bvf-tip` em CSS (hover)

**Objetivo:** atalho de navegação durante o uso da lista — o botão "Ver Ficha" dentro do drawer do Cadastro continua existindo normalmente.

---

## Módulo Cadastro — KPIs e filtros (atualizado 2026-09-17)

**KPI "Empresas":** conta `EMPRESAS_PARAM.length` (param_empresa ativo) — não mais distinct de `empresa_registro`. Clique abre `renderTelaEmpresas()`. Não tem filtro de colaboradores (são múltiplas empresas).

**KPI "Promotoras":** filtra `tipoVinculo === 'promotora' && situacao === 'Ativo'`. Clique filtra a lista. IDs: `m-promotoras` (telaEmpresas), `ml-promotoras` (telaLista), `ml-card-promotora` (card clicável de telaLista).

**KPI "Pró-labore":** filtra `tipoVinculo === 'pro_labore' && situacao === 'Ativo'`. Clique filtra a lista. IDs: `m-prolabore` (telaEmpresas), `ml-prolabore` (telaLista), `ml-card-pro_labore` (card clicável de telaLista).

**Regra do `active-filter`:** a classe `active-filter` nos cards `ml-card-promotora` e `ml-card-pro_labore` é **sincronizada ao final de `aplicarFiltros()`** — não nos calling sites individualmente. Isso garante que qualquer caminho que chame `aplicarFiltros()` (filtrarLista, filtrarGlobal, setSituacaoTab, etc.) sempre deixe o card correto destacado. Código ao final de `aplicarFiltros()`:
```js
['promotora','pro_labore'].forEach(t => {
  const el = document.getElementById('ml-card-' + t);
  if (el) el.classList.toggle('active-filter', t === window._filtroVinculo);
});
```

**`filtrarGlobal` também sincroniza:** quando acionado a partir de telaEmpresas, `filtrarGlobal` também aplica `active-filter` nos `ml-card-*` antes de chamar `aplicarFiltros()`.

**KPI grid:** `repeat(7, 1fr)` — 7 cards em uma linha. Card "Empresas" (amber) foi removido em 2026-09-18 por ser contador passivo sem ação. Se adicionar novo KPI, ajustar para `repeat(8, 1fr)`.

**Upload de foto — guard:** usa `!c._sbId` (nunca `!c.codigo`) — colaboradores sem matrícula (Promotoras, Pró-labore) têm `_sbId` mas não têm `codigo`.

**Filtro Pró-labore em `aplicarFiltros`:** linha `if (c.tipoVinculo === 'pro_labore' && window._filtroVinculo !== 'pro_labore') return false;` exclui pro_labore de todos os resultados EXCETO quando `_filtroVinculo === 'pro_labore'`. Essa linha precede o guard genérico de vinculo.

---

## Módulo Cadastro — regras críticas

**Agrupamento de relatórios por `empresa_atuacao` (adicionado 2026-09-16):** o relatório Por Empresa/Setor usa `empresaAtuacao` (onde a pessoa trabalha) como primeiro nível do agrupamento — não `empresa` (empresa de registro/CNPJ). Hierarquia: Empresa de Atuação → Setor → colaboradores. `stripNum()` remove prefixos numéricos ("01 - Matriz" → "Matriz") dos nomes de empresa e setor.

**Bug `empresa_atuacao` não salvava (corrigido 2026-09-16):** função `up()` convertia o valor selecionado para maiúsculas → "Matriz" virava "MATRIZ" → não batia com nenhuma `<option>` → salvo como null. Fix: removido `up()` do campo `empresaAtuacao`; usa `.value.trim()` diretamente. Fix secundário: ao abrir ficha, `popularSelectEmpresaAtuacao()` popula as options antes de definir `.value`.

**SQL de limpeza (executado 2026-09-16):** `UPDATE colaboradores SET empresa_atuacao = 'Matriz' WHERE empresa_atuacao = 'MATRIZ'`

**Campo "Quem Indicou" (armadilha — corrigido 2026-08-26):** ao abrir um colaborador sem indicação (campo `indicado_por = false`), o bloco de indicação é ocultado, mas o campo de busca e seleção do indicador **deve ser limpo** com `limparIndicador()` — não apenas escondido. Sem isso, o indicador do colaborador anterior fica preenchido no estado interno e causa erro de busca no próximo colaborador aberto.

```js
// Correto (no else do bloco indicacao):
document.getElementById('bloco-indicacao').style.display = 'none';
limparIndicador(); // limpa df-indicadorBusca, df-indicadorId, esconde dropdown e card selecionado
```

**`sbPatch` — detecção de RLS silencioso (corrigido 2026-09-18):** Supabase retorna `200 OK` com corpo vazio quando RLS bloqueia um PATCH, indistinguível de sucesso com `Prefer: return=minimal`. Fix: trocado para `Prefer: return=representation` e adicionada validação `if (!Array.isArray(linhas) || linhas.length === 0) throw new Error('Nenhuma linha atualizada...')`. Superficia o problema ao usuário em vez de silenciar. Motivo: colega não conseguia salvar endereço de Promotora — sistema exibia "Salvo ✓" mas dado não persistia no banco.

---

## Módulo Processos RH — JWT refresh (corrigido 2026-09-09)

`_sbRefreshSession()` adicionada ao módulo (`modulos/processos/index.html`). `_executarConclusao` faz retry automático se o PATCH retornar JWT expired — renova sessão silenciosamente via `refresh_token` e refaz a chamada. Mesmo padrão do módulo Cadastro.

---

## Etapa 1 — Migração empresa_id (concluída 2026-09-17)

### Regra de negócio obrigatória

- `empresa_registro` = empresa/CNPJ ao qual o colaborador está **registrado** (contrato). Não deve mudar em transferência de unidade.
- `empresa_atuacao` = unidade onde o colaborador **atua** no dia a dia. Pode mudar sem alterar o registro.
- Os dois campos são **independentes** em todos os módulos.

### Migrations executadas (Etapa 1)

| Migration | Conteúdo | Status |
|---|---|---|
| 054 | `matricula` DROP NOT NULL | ✅ executada |
| 055 | RLS SELECT anon para `param_empresa` | ✅ executada |
| 056 | ADD COLUMN `empresa_registro_id INTEGER`, `empresa_atuacao_id INTEGER` (nullable) | ✅ executada |
| 057 | Popular `_id` via `nome_simplificado` + LOWER/TRIM para 4 registros uppercase | ✅ executada |

### Coluna `empresa_registro_id` / `empresa_atuacao_id`

- Tipo: `INTEGER`, nullable, sem FK (FK fica para Etapa 3)
- Mapeados via `param_empresa.id` usando `nome_simplificado` como chave
- 676 colaboradores com `empresa_registro_id` preenchido (100%)
- 671 colaboradores com `empresa_atuacao_id` preenchido (5 com `empresa_atuacao IS NULL` — sem unidade, correto)
- 4 registros uppercase corrigidos no texto também: `MATRIZ`→`Matriz`, `PARANAVAÍ`→`Paranavaí`, `PORTO RICO`→`Porto Rico`

### Módulos atualizados para gravar `_id`

**Admissão** (`modulos/admissao/index.html`):
- `loadUnidades` busca `id,nome_simplificado` — armazena `data-id` no option
- Payload de efetivação inclui `empresa_registro_id` e `empresa_atuacao_id` (mesmo id — na admissão, atuação = registro)

**Cadastro** (`modulos/cadastro/index.html`):
- `carregarEmpresasParam` busca `id,codigo,nome_simplificado,razao_social`
- `popularSelectEmpresaAtuacao` armazena `data-id` em cada option
- `novoColaborador` usa `EMPRESAS_PARAM` (com `data-id`) para o select de empresa de registro
- Objeto colaborador: novos campos `empresaRegistroId` e `empresaAtuacaoId`
- Payload novo colaborador: lê `_id` do option selecionado em ambos os selects
- Payload edição: grava `empresa_atuacao_id` do select, `empresa_registro_id` de `c.empresaRegistroId`
- **Bug foto corrigido:** guard `!c.codigo` substituído por `!c._sbId` — Promotoras/Pró-labore sem matrícula agora podem fazer upload de foto

**Processos** (`modulos/processos/index.html`):
- Select de destino na transferência busca `id,nome_simplificado` (com `data-id`)
- Formulário de abertura tem radio "Tipo de movimentação": `● Transferência de unidade` / `● Alteração de CNPJ/contrato`
- `dados_extras` inclui `empresa_destino_id` e `tipo_transferencia` (`'unidade'` | `'cnpj'`)
- Conclusão: `tipo=unidade` → altera só `empresa_atuacao` + `empresa_atuacao_id`; `tipo=cnpj` → altera os 4 campos
- Fallback `'unidade'` para processos antigos sem `tipo_transferencia` — preserva `empresa_registro`

### Etapa 2 (frontend — pendente)

Relatórios e Férias ainda leem `empresa_registro`/`empresa_atuacao` como texto — sem urgência, campos TEXT preservados. Etapa 2 deferred.

### Etapa 3 (FK constraint — pendente)

Adicionar `FOREIGN KEY` em `empresa_registro_id` e `empresa_atuacao_id` só após validação completa de todos os módulos.

---

## Módulo Processos RH — features implementadas 2026-09-17

### Tipo `transferencia_cnpj`

Processo para transferência entre empresas do grupo. Campos: `empresa_origem` (auto-fill), `empresa_destino` (select de `param_empresa`), `data_transferencia`, `tipo_transferencia` (radio). Ao concluir, faz PATCH respeitando o tipo de movimentação. **Nunca altera `data_ingresso_grupo`**.

### Campo `data_ingresso_grupo` em colaboradores

Novo campo DATE na tabela `colaboradores` (migration `050`). Preenchido manualmente pelo RH no módulo Cadastro quando o colaborador tem histórico anterior na empresa (ex: veio de outro CNPJ do grupo).

**Regra global de tempo de casa (padronizada 2026-10-07):** sempre usar `data_ingresso_grupo || data_admissao` como data de referência para cálculo e exibição de tempo de empresa. `data_admissao` é dado **contratual** (CNPJ atual) — nunca substitui `data_ingresso_grupo` para exibição de tempo.

Telas que aplicam essa regra:
- `modulos/relatorios/index.html` — Relatório Tempo de Casa (`_refData = dataIngressoGrupo || dataAdmissao`)
- `modulos/cadastro/index.html` — coluna Admissão na lista e exportação CSV (`refAdm = c.dataIngressoGrupo || c.dataAdmissao`)
- `modulos/colaborador/ficha-render.js` — card Tempo de Casa e texto "desde X" no Resumo (`c.data_ingresso_grupo || c.data_admissao`)
- `modulos/colaborador/ficha-data.js` — função `tempoStr()` recebe a data de referência já resolvida

O campo "Admissão" contratual (data do CNPJ atual) permanece exibido separadamente — não deve ser alterado.

### Ficha de Encaminhamento VT — campos atuais (2026-09-17)

**Seção Dados do Colaborador:** Colaborador, Matrícula, CPF (editável — salva em `colaboradores.cpf`), Data de Nascimento, Setor (sem prefixo numérico), Empresa/Unidade, Mês de Vigência (editável, default próximo mês, salvo em `dados_extras.mes_vigencia`).

**Removidos intencionalmente:** Cargo e Data de Admissão (não relevantes para processo VT).

**Seção Dados do VT:** Cartão, Passes/dia, Linha de Ônibus, **Viação** (novo — `dados_extras.vt_viacao`). Todos editáveis com auto-save. `vt_viacao` fica só em `dados_extras` — sem coluna em `colaboradores`.

**Foto do Cartão:** fluxo 2 etapas (selecionar → preview com rotação → confirmar envio). Após upload: botões Trocar e Excluir. Upload usa `Bearer ${SB_KEY}`, nunca `SB_HEADERS.Authorization`.

**Impressão (`_imprimirFichaVT`):** async, busca dados frescos do colaborador, HTML próprio (não reutiliza DOM interativo). Mês de vigência por extenso (ex: "Outubro / 2026"). Grid 2×2 para dados VT.

### Formulário de criação VT — campos atuais

Inclusão: Cartão (`xVtCartao`), Passes (`xVtPasses`), Linha (`xVtLinha`), Viação (`xVtViacao`), Foto (opcional).
Alteração: `xVtCartaoAlt`, `xVtPassesAlt`, `xVtLinhaAlt`, `xVtViacaoAlt`.

---

## Módulo Processos RH — visão geral

**Arquivo:** `modulos/processos/index.html`  
**Skill:** `processos`

### Tabelas Supabase

| Tabela | Descrição |
|---|---|
| `processos_rh` | `id, tipo, status, colaborador_id, colaborador_nome, dados_extras (JSONB), criado_em, criado_por` |
| `processos_checklist` | `id, processo_id, item, concluido, prazo_dias, ordem` |
| `param_bonus_indicacao` | `id, valor, vigencia_inicio, vigencia_fim` — valor do bônus por período |
| `param_motivo_reajuste` | `id, codigo, descricao, ordem, ativo, criado_por` — motivos de reajuste salarial (migration 074) |
| `colaboradores` | Campos de controle: `indicado_por_id, indicacao_bonus_gerado, em_experiencia, prorrogacao_45_gerado, avaliacao_90_gerado` |

### Tipos de processo (`tipo`)

| Tipo | Descrição |
|---|---|
| `bonus_indicacao` | Bônus para quem indicou colaborador após 90 dias |
| `prorrogacao_experiencia` | Avaliação e prorrogação do 1º período (45 dias) |
| `avaliacao_final_experiencia` | Avaliação final antes de efetivação (90 dias) |

### Regra do bônus de indicação

- **Quem recebe:** o colaborador que **indicou** (não o indicado)
- **Quando:** workflow criado 12 dias antes ou até 30 dias após completar 90 dias do indicado
- **Valor:** consultado em `param_bonus_indicacao` usando a **data de admissão do indicado** como referência (não data atual) — garante que o valor vigente na admissão seja preservado
- **Competência de pagamento:** mês em que vence os 90 dias (incluso na folha do mês)

### dados_extras do bonus_indicacao

```js
{
  indicado_id: <id>,
  indicado_nome: '<nome>',
  data_admissao_indicado: 'YYYY-MM-DD',
  mes_folha: 'MM/YYYY',
  valor_bonus: 300.00
}
```

### Ficha de Solicitação de Bônus (UI)

- Bloco colapsável âmbar dentro do card do processo, estilo similar ao VT de férias
- Renderização lazy: só carrega quando o card é aberto pela primeira vez (`fichaBonus._loaded`)
- Botão "Copiar solicitação" no header da ficha — copia texto estruturado (sem formato de e-mail)
- `wrap._emailTexto` armazena o texto de cópia no DOM element

### Chips de filtro por tipo (painel Em andamento)

- Aparecem dinamicamente quando há 2+ tipos diferentes no painel
- Scroll horizontal sem quebra de linha (`flex-wrap: nowrap; overflow-x: auto; scrollbar-width: none`)
- `filtroAtivo` guarda o tipo ativo; `_filtrarAndamento()` reaplica ao limpar busca

### Criação automática de workflows (server-side)

**Edge Function:** `verificar-workflows` (Supabase Deno)  
**Cron:** todo dia às **07:00 BRT** (10:00 UTC) — job id 1 em `pg_cron`  
**Arquivo local:** `supabase/functions/verificar-workflows/index.ts`  
**Migration:** `migrations/032_cron_verificar_workflows.sql`

Funções da Edge Function:
- `verificarBonusIndicacao()` — janela: 12 dias antes até 30 dias após os 90 dias
- `verificarExperiencia()` — 45 e 90 dias, janela de 12 dias antes do vencimento
- `limparExperienciaVencida()` — marca `em_experiencia=false` para contratos vencidos

---

## `tipo_vinculo` — diretrizes obrigatórias (aprovado 2026-09-17, validado 2026-09-21)

- **Sem hardcode no frontend:** opções carregadas de `param_tipo_vinculo` (tabela Supabase com `codigo, descricao, ativo, ordem`)
- **Fonte única de verdade:** `tipo_vinculo` é o campo canônico em Cadastro, Relatórios e Férias — não duplicar lógica usando setor ou cargo
- **Nunca usar setor ou cargo para identificar vínculo no código** — apenas `tipo_vinculo`
- **Nunca excluir fisicamente** tipos já vinculados a colaboradores — usar `ativo=false` para inativar; histórico preservado
- **`pro_labore` (booleano antigo):** manter na tabela por retrocompatibilidade; não remover nesta etapa
- **Relatórios:** filtros de vínculo devem ser checkboxes configuráveis (CLT / Promotora / Pró-labore) — padrão já implementado em `modulos/relatorios/index.html` com helper `vinculos()`
- **Antes de alterar módulo:** verificar impacto e reutilizar lógica existente; não duplicar filtros

### Setor `'Pro-labore'` — validado 2026-09-21

- `param_setor` tem `id=21, descricao='Pro-labore', ativo=true` — criado manualmente pela usuária
- Todos os 9 registros com `tipo_vinculo='pro_labore'` têm `setor='Pro-labore'` — 100% consistentes
- O Cadastro carrega setores **exclusivamente de `param_setor`** (dinâmico, sem hardcode) — confirmado em `modulos/cadastro/index.html:1348`
- Setor e tipo de vínculo são independentes: setor representa área organizacional, `tipo_vinculo` representa vínculo contratual
- `modulos/cadastro/CLAUDE.md` atualizado com essas regras (commit `10ac684`)

---

## Banco de dados (Supabase)

**Projeto:** SistemaRH
**URL:** `https://rujtbxwssiofiialnbbg.supabase.co`
**Chave publicável (browser):** começa com `eyJhbGci...` — ver arquivos HTML
**Chave secreta:** apenas em scripts Python locais (nunca no browser)

### `param_motivo_desligamento` — estado atual (migration 073, out/2026)

12 registros com `codigo` únicos, `ordem` 1–12. Constraint `UNIQUE(codigo)` **executada** (migration 073 aplicada manualmente no Supabase Dashboard).

### `historico_remuneracao` — criada (migration 075, out/2026)

Tabela append-only e imutável para histórico estruturado de remuneração. **Migration executada** manualmente no Supabase Dashboard.

```sql
CREATE TABLE historico_remuneracao (
  id               BIGSERIAL PRIMARY KEY,
  colaborador_id   BIGINT NOT NULL REFERENCES colaboradores(id),
  processo_id      BIGINT REFERENCES processos_rh(id),   -- NULL = registro manual/migrado
  data_vigencia    DATE NOT NULL,
  salario_anterior NUMERIC(12,2),
  salario_novo     NUMERIC(12,2) NOT NULL,
  percentual       NUMERIC(6,2),
  cargo_anterior   TEXT,
  cargo_novo       TEXT,
  motivo_codigo    TEXT,
  motivo_descricao TEXT,
  observacao       TEXT,
  registrado_por   TEXT,
  registrado_em    TIMESTAMPTZ DEFAULT NOW(),
  aplicado_em      TIMESTAMPTZ,   -- NULL = vigência futura pendente
  estornado        BOOLEAN DEFAULT FALSE,
  estorno_id       BIGINT REFERENCES historico_remuneracao(id),  -- auto-referência (futuro)
  esocial_enviado  BOOLEAN DEFAULT FALSE,
  CONSTRAINT uq_hr_colaborador_processo UNIQUE (colaborador_id, processo_id)
);
```

**Indexes:** `idx_hr_pendentes` (partial: `aplicado_em IS NULL AND estornado = FALSE`) + `idx_hr_colaborador`.

**Regras:** nunca UPDATE ou DELETE registros. `NULL != NULL` no PostgreSQL → múltiplos registros com `processo_id IS NULL` são permitidos (migração histórica).

### `fn_concluir_reajuste` — criada (migration 076, out/2026)

Função PL/pgSQL com `SECURITY DEFINER` que conclui um reajuste salarial atomicamente.

**Retorno:** `JSONB { ok, aplicado, data_vigencia, salario_novo, percentual }` ou `{ ok: false, erro }`.

**BUG CRÍTICO corrigido fora da migration:** a migration 076 no repositório tem `salario = v_salario_novo::TEXT` na Etapa 7, mas a coluna `colaboradores.salario` é `NUMERIC`. O fix (`salario = v_salario_novo`) foi executado via `CREATE OR REPLACE FUNCTION` diretamente no Supabase Dashboard. **Se recriar a função a partir do arquivo de migration, corrigir antes de executar.**

**Migration 077 — migração de histórico legado (out/2026):** `historico_salarial` (JSONB) de todos os colaboradores estava vazio → 0 linhas migradas. Resultado esperado. Campo `historico_salarial` mantido no banco como backup.

### `param_motivo_reajuste` — criada (migration 074, out/2026)

Nova tabela para motivos de reajuste salarial. **Migration executada** manualmente no Supabase Dashboard.

```sql
CREATE TABLE param_motivo_reajuste (
  id SERIAL PRIMARY KEY, codigo TEXT NOT NULL, descricao TEXT NOT NULL,
  ordem INTEGER DEFAULT 0, ativo BOOLEAN DEFAULT true, criado_por TEXT,
  CONSTRAINT uq_pmr_codigo UNIQUE (codigo)
);
```

6 registros padrão: Mérito (0.1), Promoção (0.2), Dissídio coletivo (0.3), Equiparação salarial (0.4), Acordo coletivo (0.5), Enquadramento (0.6).

### Tabelas principais

| Tabela | Descrição |
|---|---|
| `colaboradores` | Cadastro master — todos os módulos leem daqui. Inclui `foto_url TEXT` (adicionado 2026-08). |
| `admissao_convites` | Convites de admissão (token, status, cargo, salário) |
| `admissao_fichas` | Fichas preenchidas pelos candidatos |
| `ferias` | Períodos aquisitivos e lançamentos de férias |
| `param_empresa` | Empresas/unidades cadastradas |
| `param_tipo_contrato` | CLT, Jovem Aprendiz, PJ, Estágio |
| `param_tipo_vinculo` | CLT, Promotora, Pró-labore (migration 052 — carregado dinamicamente, sem hardcode) |
| `param_motivo_desligamento` | Motivos de rescisão |
| `param_regime_horas` | Regimes de jornada |
| `param_tipo_experiencia` | Tipos de contrato de experiência |
| `dev_competencias` | Biblioteca de competências (39 cadastradas) |
| `dev_ciclos` | Ciclos de avaliação de desempenho |
| `dev_avaliacoes` | Avaliações por colaborador por ciclo (notas 1-5 por competência) |
| `dev_pdi` | Planos de desenvolvimento individual |
| `dev_historico` | Timeline unificada do colaborador |
| `processos_rh` | Processos abertos/concluídos de RH (bônus, experiência, etc.) |
| `processos_checklist` | Itens de checklist vinculados a cada processo |
| `param_bonus_indicacao` | Tabela de valores do bônus de indicação por vigência |
| `ferias_historico` | Audit log imutável de ações em férias (adicionado 2026-09-14) |
| `colaborador_documentos` | `colaborador_id, nome, categoria, url, tipo_arquivo, data_documento, criado_por` — arquivos do colaborador (fotos VT, docs admissão etc.) |
| `historico_remuneracao` | Histórico estruturado e imutável de reajustes salariais (migration 075, out/2026) |
| `tipos_evento` | Tabela de referência dos tipos de evento da timeline (migration 078) |
| `historico_eventos` | Fonte única de verdade da timeline do colaborador — push-based (migration 078) |
| `processo_auditoria` | Audit trail interno dos processos concluídos — não exibido na timeline (migration 078) |
| `dp_param_motivos_nao_participacao` | Motivos configuráveis para não participação em ciclo D&P. `id UUID PK, descricao TEXT, ativo BOOLEAN, criado_em`. RLS: RH/admin CRUD; gestor/diretoria SELECT ativo=TRUE. 4 seeds ativos (migration 120, out/2026). |

### Storage

- Bucket `admissao-docs` — documentos dos candidatos. Path: `{token}/{key}.{ext}`
- Bucket `colaborador-docs` — arquivos do colaborador (foto VT, etc.). Path: `{colaborador_id}/vt/{timestamp}.jpg`. **Auth: sempre `Bearer ${SB_KEY}` (publishable key) — nunca `SB_HEADERS.Authorization` (access_token).**

---

## Módulo Férias — `periodos[]` JSONB e correção bug overwrite (2026-10-09)

### Contexto

Bug confirmado em produção: `confirmarDrawerLancamento` tinha lógica binária `length===0 ? p1 : p2` que sobrescrevia o 2º período ao lançar o 3º. **Casos de perda confirmados:** Victor Hugo (mat.402) e Valdir Felix (mat.439) — datas do período sobrescrito não recuperáveis do sistema.

### Migration 073 — executada em produção

```sql
ALTER TABLE ferias ADD COLUMN IF NOT EXISTS periodos JSONB NOT NULL DEFAULT '[]'::jsonb;
CREATE INDEX IF NOT EXISTS idx_ferias_periodos ON ferias USING GIN (periodos);
```

Arquivo: `migrations/073_ferias_periodos_jsonb.sql`. Todos os registros existentes ficaram com `periodos = []` (migração não retroativa — compatibilidade via fallback).

### Commits

- `2745d68` — 11 funções modificadas para usar `periodos[]` como fonte de verdade
- `ea7c99e` — Log de operações RH adicionado ao `ferias_historico`

### Regras da nova arquitetura

- `periodos[]` é **append-only**: nunca remover itens; exclusão = `status:'excluido'`; cancelamento = `status:'cancelado'`
- `id` de cada item é sequencial e imutável — `lancIdx` dos acordos de gozo depende disso
- Campos flat `periodo1_*/periodo2_*` mantidos em paralelo para `id=0` e `id=1` (compat)
- Fallback: registros antigos (`periodos=[]`) são reconstruídos dos campos flat em `supabaseParaModelo` e `processGestorFerias`
- `reg._periodos` em memória = array original da row (lido em `supabaseParaModelo`)

### Log de operações RH no `ferias_historico`

Novas ações adicionadas (commit `ea7c99e`):

| `acao` | Função | Detalhe |
|---|---|---|
| `'lancado_rh'` | `confirmarDrawerLancamento` | `{ inicio, fim, dias, id_periodo, nota }` |
| `'editado_rh'` | `salvarEditLanc` | `{ id_periodo, inicio_anterior, fim_anterior, inicio_novo, fim_novo, dias_novo }` |
| `'excluido_rh'` | `excluirLancamento` | `{ id_periodo, inicio, fim, dias }` |

Todas usam `sbPost('ferias_historico', ...).catch(() => {})` diretamente (não via `_logAtiv`).

---

## Módulo Férias — Sistema de Auditoria `ferias_historico` (2026-09-14)

### Tabela Supabase

```sql
CREATE TABLE ferias_historico (
  id             BIGSERIAL PRIMARY KEY,
  ferias_id      BIGINT NOT NULL,      -- FK para ferias.id
  colaborador_id BIGINT NOT NULL,      -- FK para colaboradores.id
  acao           TEXT NOT NULL,        -- 'solicitado' | 'aprovado' | 'rejeitado'
  usuario        TEXT,                 -- nome de quem agiu (perfil do localStorage)
  detalhe        JSONB,                -- { inicio, fim, dias, slot, status, obs_gestor }
  criado_em      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Variável global e carregamento

`FERIAS_HISTORICO` — array global carregado na inicialização via `carregarDoSupabase` (e na carga do Gestor):
```js
sbGet('ferias_historico', 'select=*&order=criado_em.desc&limit=500').catch(() => [])
```

### Helper `_logAtiv` — **corrigido commit `3fca0d2`**

Propaga erros de INSERT (sem try/catch interno). `FERIAS_HISTORICO.unshift` só executa após POST bem-sucedido. Cada caller envolve `_logAtiv` em seu próprio try/catch com flag `_histFalhouXxx` para distinguir falha da operação principal vs. falha só no log.

13 callers mapeados na skill `ferias`. Novos: `alteracao_solicitada`, `cancelamento_solicitado`, `alteracao_aprovada/recusada`, `cancelamento_aprovado/recusado`, `gestor_ciente`.

### KPI "Pendentes de Aprovação" do Gestor — **corrigido commit `d442144`**

`_computeGestorMetricas` só filtrava `GESTOR_LANCAMENTOS`, mas quando o PA usa `periodos[]` JSONB o lancamento mantém `status:'aprovado'` e o status real fica em `ferias.status` (= `_feriasRow.status`). Fix: inclui `GESTOR_PERIODOS` como fonte complementar para `alteracao_solicitada` e `cancelamento_solicitado`, unindo via `Set` para evitar duplicidade.

### Botão "Ciente" para Gestor — **commit `993c54f`**, corrigido em **commit `6bbdfad`**

Quando o RH responde (aprovado, rejeitado, alterações, cancelamentos), o Gestor vê botão "Ciente" na Atividade Recente. Clicar insere `gestor_ciente` em `ferias_historico` via `gestorMarcarCiente()`. Dedup natural: `_gestorAgruparProcessos` elege `gestor_ciente` como mais recente → `ativo:false` → item sai da Atividade Recente.

**Bug corrigido (commit `6bbdfad`, 2026-10-10):** botão "Ciente" sempre exibia toast de erro, mesmo com INSERT bem-sucedido. Causa raiz: `_normGA` (usada em `renderGestorAtividade` na aba Histórico) não estava definida → clicar "Histórico" lançava `ReferenceError` sem atualizar o DOM → botões "Ciente" antigos ficavam visíveis → ao clicar, INSERT ocorria com sucesso mas `renderGestorAtividade()` lançava novamente → catch exibia toast e reabilitava o botão. Duas correções: (1) definir `_normGA` idêntica a `normGestor`; (2) separar `gestorMarcarCiente` em dois try/catch — erro de INSERT → toast + reabilita botão; erro de render → apenas `console.error`.

### Escala por período — nova feature Gestor (commits 927407a + e0f8818 + b850a82 + a22894e, 2026-10-13)

Modal `#modalEscalaGestor`: Gestor seleciona um mês e exporta PDF ou Excel com quem estará de férias naquele período. Reutiliza `_buildRelatorioHTML`/`_buildExcelHTML` (mesmo visual do RH) via `opts.hideColumns: ['empresa','setor','matricula']`. Colunas visíveis: Nome | Cargo | Dias | Início | Fim. Legenda colorida de setores suprimida no Excel quando `setor` está oculto.

### Fluxos do Gestor — Alterar datas da solicitação + Retirar solicitação (commit `85373c9`, 2026-10-13)

Implementados dois novos fluxos para o Gestor operar sobre períodos com status `'solicitado'` no `periodos[]` JSONB — enquanto o RH ainda não aprovou.

**Botões:** aparecem na aba "Férias" do drawer (`gsolListaRHConteudo` / `_renderGsolHistoricoRH`) — apenas para lancamentos `status='solicitado'` com `inicio > hoje`. **Não** aparecem na aba "Solicitações" (`gsolLista`).

**Funções novas:** `_encontrarPeriodoSolicitado`, `gestorAbrirModalAltSol`, `gestorConfirmarRetirada`, `gestorExecutarRetirada`, branch `_modoSolicitado` em `gestorEnviarAlteracao`.

**Proteção de concorrência:** PATCH condicional com filtro `status=eq.Pendente` + `Prefer: return=representation` — array vazio = conflito. `aprovarPendente` ganhou pre-check (`sbGet`) + PATCH com `atualizado_em=eq.{tsLido}`.

**Regra crítica:** `abrirModalConfirm` usa `textContent` internamente — nunca passar HTML tags no campo `texto`.

**Novas ações em `ferias_historico`:** `solicitacao_retirada` e `solicitacao_datas_alteradas`.

**T4 (concorrência simultânea):** implementado, não validado em ambiente real.

Detalhes completos na skill `ferias.md` → seção "Fluxos do Gestor — Alterar datas da solicitação e Retirar solicitação".

### `dias_resposta_visivel` — valor em produção (verificado 2026-10-14)

`param_ferias_config.dias_resposta_visivel = 10` (default do código = 7). Desfechos (`aprovado`, `rejeitado` etc.) ficam 10 dias na Atividade Recente do Gestor antes de migrar para Histórico.

**Nota operacional:** `FERIAS_HISTORICO` é carregado uma única vez por sessão (`initGestor`). Se o Gestor estava com a página aberta antes de um evento ser gravado, ele não aparecerá até F5 completo — comportamento esperado, não é bug. Confirmado em 2026-10-14 (Marcelo/Francisco, ids 16/17).

### KPI "Acordos em Andamento" removido da visão Gestor (commits `27c2a76` + `5274678`, 2026-10-13)

Card KPI e filtro de alerta removidos — KPI não era acionável pelo Gestor (quem registra realizações é o RH). Chip contextual "↩ Acordo em andamento" nos cards individuais foi mantido (informação útil por colaborador). `window._gestorAcordosAndamento` e função `_gestorColabsComAcordoAndamento` preservadas.

### Histórico do Gestor — timeline completa + collapse/expand (commits `87c3723` + `ea3278e`, 2026-10-10)

**Problema anterior:** `_gestorAgruparProcessos` guardava só o evento mais recente por `ferias_id`, fazendo o Histórico mostrar apenas "Ciente" sem revelar que o RH aprovou ou recusou antes.

**Fix (commit `87c3723`):** o Histórico agora coleta todos os eventos dos processos concluídos de `FERIAS_HISTORICO`, subagrupados por `ferias_id` dentro do card de cada colaborador, em ordem cronológica. Cada linha exibe chip de estado + timestamp + responsável + motivo (se existir). Regra de não-sobreposição: um processo aparece na Atividade Recente OU no Histórico — nunca nos dois — determinado pelo `ativo` do evento mais recente.

**Collapse/expand (commit `ea3278e`):** cards do Histórico colapsados por padrão. Header mostra nome + cargo + chip do status mais recente. Clicar expande a timeline. Estado em `_gestorHistExpanded` (Set de colaborador IDs — persistido durante a sessão, não em localStorage).

### Atividade Recente

Tanto `renderGestorAtividade` quanto `renderRhAtividade` lêem de `FERIAS_HISTORICO` (não mais inferem de `GESTOR_LANCAMENTOS`). Dismiss key = `String(h.id)` (id numérico do registro de auditoria). localStorage keys: `ferias_ativ_dismissed_g` (Gestor) e `ferias_ativ_dismissed_r` (RH).

### Abas Histórico nos drawers

**Drawer RH** — dois tabs: "Períodos" (`drawerHistorico`) e "Histórico" (`drawerAuditoria`). Controlado por `setDrawerTab(tab)` e variável `_drawerTab` (reset para 'periodos' a cada abertura). Renderização: `renderDrawerAuditoria(colab)` — timeline vertical filtrada pelos `ferias_id` dos PAs do colaborador.

**Drawer Gestor (`gsolDrawer`)** — três tabs: Solicitações | Férias | Histórico. `gsolMostrarAba('hist')` chama `_renderGsolHistoricoAuditoria()` — mesmo formato de timeline, filtrado por `colaborador_id === _gsolColabId`.

---

## Módulo Admissão — fluxo obrigatório Aprovar → Efetivar (corrigido 2026-09-09)

**Problema:** havia botão "Efetivar" direto na lista de convites (`status='aprovado'`) que chamava `efetivarDireto()`, pulando o "Aprovar Ficha". Sem passar por `_confirmarAprovar`, nenhum processo de admissão era criado no Workflow — o checklist de onboarding só aparecia depois da efetivação (caso da Raissa).

**Fix:** botão "Efetivar" direto removido. Função `efetivarDireto` excluída. Convites aprovados agora exibem apenas "Efetivar contratação", que abre o painel completo da ficha — onde o botão de efetivação real exige que a aprovação já tenha ocorrido.

**Regra de negócio:** processo de admissão (checklist de onboarding) sempre criado no "Aprovar Ficha" (`_confirmarAprovar`), com `colaborador_id=null` e `dados_extras.convite_id`. O `colaborador_id` é vinculado apenas na efetivação.

---

## Fluxo de Admissão Online

```
RH cria convite → candidato recebe link com token
→ preenche ficha (5 steps) → envia documentos
→ RH valida no painel → clica "Efetivar Contratação"
→ modal abre com matrícula gerada automaticamente
→ confirmar → cria registro em colaboradores
→ convite muda para status "efetivado"
→ colaborador aparece em TODOS os módulos
```

### Documentos da admissão

**Obrigatórios:** RG (frente), CPF, Foto 3x4, Comprovante de residência, Carteira de trabalho

**Opcionais:** CNH, Título de eleitor, Comprovante bancário, Certidão dos dependentes, **Histórico Escolar** (adicionado 2026-08)

**Download:** painel RH tem botão de download para todos os documentos (cross-origin via fetch+blob)

---

## Módulo Férias — Relatório Mensal (redesenhado 2026-09-09)

### Funções do relatório RH

- `_buildRelatorioHTML(linhas, mesLabel, opts?)` → PDF/visualização: ícone 📅, header azul escuro `#1e3a5f`, separador por empresa (`<tr class="emp-sep">`), legenda com bolinhas CSS `position:fixed`
- `_buildExcelHTML(linhas, mesLabel, opts?)` → Excel: **todos os estilos inline** (Excel ignora `<style>`), legenda em células coloridas, sem `position:fixed`
- `exportarRelatorioExcel()` usa `_buildExcelHTML` — funções separadas por necessidade
- `c.empresa` é o campo correto (não `c.empresaRegistro`, que nunca é preenchido neste módulo)
- Excel gera aviso de formato ao abrir — é esperado; usuário clica "Sim"

**Parâmetro `opts` (adicionado 2026-10-13):**
- `opts.hideColumns: string[]` — array com keys das colunas a ocultar: `'empresa' | 'setor' | 'matricula' | 'nome' | 'cargo' | 'dias' | 'inicio' | 'fim'`
- Quando omitido ou `{}`: comportamento 100% idêntico ao original — o RH nunca passa opts
- Larguras de colgroup redistribuídas proporcionalmente; colspan do separador usa nCols dinâmico
- Separador `emp-sep` suprimido quando `'empresa'` está oculta; legenda de setores no Excel suprimida quando `'setor'` está oculta

### Visão Gestor — abas e exportação (reestruturado 2026-09-09)

- **Abas:** Painel | Timeline (aba "Relatório" removida — padrão de mercado)
- **KPIs** (`gestorAlerts`, `gestorAtividade`) ficam fora do card de abas — sempre visíveis independente da aba ativa
- **Abas dentro do card principal** usando `.proto-view-tabs` — mesmo padrão visual da visão RH
- **Botão "Exportar"** → dropdown com "Visualizar PDF" e "Exportar Excel" (fecha ao clicar fora)
- `toggleGestorExportMenu()` controla abertura/fechamento do dropdown

**Busca gestor — correções (2026-09-10):**
- `gestorBuscaSelecionar`: não limpa o input após selecionar colaborador. Texto persiste no campo para nova busca após fechar drawer.
- Situação "Agendado" no export: critério é `!lRef` (ativo ou futuro), não `!lancs.length`. Lançamentos concluídos não geram "Agendado".

**Exportação do Gestor — formato atual (2026-09-10):**
- **8 colunas (PDF e Excel):** Nome | Cargo | Ano PA | Período Aquisitivo | Férias Início | Férias Fim | Saldo | Situação
- Coluna **Setor removida** — separador colorido de setor entre grupos já identifica a área
- **Ano PA:** usa `pa.ano` (campo do banco, exposto diretamente no objeto `periodo` de `processGestorFerias` como `ano: row.ano`). **NÃO usar `pa.pa_inicio.slice(0,4)`** — colaboradores com aniversário no 2º semestre têm pa_inicio no ano anterior ao PA real (PA 2027 inicia em set/2026 → slice retorna "2026", errado). Fallback: `pa.pa_inicio?.slice(0,4)` só se `pa.ano` for nulo. **Causa raiz do bug (corrigido 2026-09-10):** `processGestorFerias` não incluía `ano` no objeto período — fazendo `pa.ano` ser sempre `undefined` e o fallback errado ser usado. Fix: adicionado `ano: row.ano` ao objeto `periodo`.
- **Período Aquisitivo:** datas completas `DD/MM/AAAA → DD/MM/AAAA`. Para colaboradores sem PA no banco (`semPA`), exibe datas calculadas com sufixo `(prev.)`: `_fmtData(data_admissao) → _fmtData(addDays(data_admissao, 364)) (prev.)`. **Nunca mostrar só "Previsto"** — o gestor precisa saber a qual período se refere.
- **Férias Início / Férias Fim:** duas colunas separadas com `_fmtData(lRef.inicio)` e `_fmtData(lRef.fim)`. Quando não há lançamento, ambas exibem `'—'`. Campos `agendIni` e `agendFim` no objeto `linhas`.
- **Situação com data da dobra:** níveis de risco exibem `"Nível · Dobra em DD/MM/AAAA"` como texto completo (campo `situacao`). Campo `sitKey` = só o nível ("Crítico"/"Atenção"/"No radar") para lookup de cor. Funções: `_sitBadge(sitKey, situacao)` e `_sitXls(sitKey)`.
- **Excel — cor por situação:** Nome (bold) e Saldo usam fundo/texto de `_sitXls(sitKey)`. Período Aquisitivo usa cor do setor (`_corSetor`) para manter identificação de grupo.
- **Excel — AutoFilter + Freeze:** `<x:AutoFilter x:Range="A3:H3"/>` + freeze 3 linhas (`SplitHorizontal=3`, `TopRowBottomPane=3`). Atualizar range se mudar colunas.
- **Cores dos níveis de risco:** Crítico `#FEE2E2`/`#7F1D1D` · Atenção `#FDE68A`/`#78350F` · No radar `#DBEAFE`/`#1E3A8A` — mais saturadas que o sistema para destaque no relatório impresso.
- **Ano PA para `semPA`:** `fimPrev.slice(0,4)` (ano de término do PA). Nunca usar `fimPrev.year - 1`.
- **Saldo:** cor semântica (azul >5d, âmbar ≤5d, verde zerado) — helper `_saldoCor(saldo)`
- **Situação — diferença entre PDF e Excel:**
  - **PDF:** badge pill colorido com borda (`_sitBadge(sit)`) — visual mais rico
  - **Excel:** célula com fundo e texto coloridos (`_sitXls(sit)`) — inline styles, Excel ignora badge HTML
- Ordenação: setor → nome; separador colorido `colspan="8"`
- **Filtros:** cargo e gestor respeitados. **Busca ignorada** (é filtro de navegação, não de exportação)
- **Guards obrigatórios:** toast + return se `GESTOR_COLABS.length === 0` ou `linhas.length === 0`
- **Download Excel:** `appendChild → click → removeChild → revokeObjectURL` — sem appendChild falha silenciosamente
- **`_normG` é local:** definida dentro de cada função de export, não é global. Usada para comparar nomes de gestor sem acento/case
- **Aviso de formato no Excel é esperado:** arquivo é HTML disfarçado de `.xls`, usuário clica "Sim"

---

## Módulo Férias — correções banco de dados (2026-09-10 / 2026-09-11)

### Regra `dias_antecipados` — onde o campo deve ficar

`dias_antecipados` fica no PA que **emprestou** os dias (o PA futuro que cedeu dias ao período anterior). **Nunca no PA que os utilizou.**

Saldo = `30 - dias1 - dias2 - dias_antecipados - abono_pecuniario`

**Padrão de erro corrigido (19 colaboradores):** férias de dez/2025 cruzando jan/2026 (ex: 22/12 → 02/01 = 12 dias). Os 2 dias de jan/2026 pertencem ao PA 2026 → `dias_antecipados=2` correto no PA 2026. O erro era ter `dias_antecipados=2` também no PA 2025 (double-counting). Fix: zerar `dias_antecipados` no PA 2025.

**Padrão Adilson/Alécio (antecip=18):** dias tomados do PA seguinte mas lançados como `dias_antecipados` no PA atual em vez de `dias1` no PA correto. Fix: zerar `dias_antecipados`; registrar os dias como `dias1` com datas reais no PA correto. Referência: Adilson Vaz PA 2026 (id=1462), Alécio Leite da Silva PA 2026 (id=1470) — corrigido 2026-09-11.

### Coluna Agendamentos — `lRef` sem fallback para passado (2026-09-11)

Visão RH (`renderListaAnual`) e Gestor (`renderGestorAtencao`) usavam `lRef = ativo || futuro || passado`. O `|| passado` fazia lançamentos já concluídos aparecerem na coluna Agendamentos quando o PA tinha saldo pendente mas nenhum lançamento futuro/ativo (ex: Adilson, Alécio). Fix: `lRef = ativo || futuro` nas duas funções. Coluna exibe `—` corretamente nesses casos.

### `gestorSaldoPeriodo` — bug corrigido (2026-09-11)

A função `gestorSaldoPeriodo` (Visão Gestor) não subtraía `dias_antecipados`, causando saldo inflado no Gestor para qualquer PA com esse campo > 0. A visão RH calculava corretamente (28d) mas o Gestor mostrava 30d.

**Fix:** adicionado `- antecipados` no cálculo:
```js
const antecipados = Number(periodo._feriasRow?.dias_antecipados) || 0;
return direito - usados - abono - antecipados;
```
Afeta **todos** os colaboradores com `dias_antecipados > 0`, não apenas um caso específico.

### `_renderGsolHistoricoRH` — saldo e chip antecipados (2026-09-11)

O drawer do Gestor usa `_renderGsolHistoricoRH` para renderizar os blocos de PA. Esta função tem seu **próprio cálculo local de saldo** (independente de `gestorSaldoPeriodo`). O saldo local não subtraía `dias_antecipados`, causando discrepância: header do drawer mostrava 28d (via `gestorSaldoPeriodo`, já corrigido) mas o bloco do PA dentro do drawer mostrava 30d.

**Fix:** adicionado `antecipados` ao cálculo local:
```js
const abono       = Number(row.abono_pecuniario) || 0;
const antecipados = Number(row.dias_antecipados) || 0;
const usados = lancamentos.reduce((s, l) => s + (Number(l.dias) || 0), 0);
const saldo  = diasDir - usados - abono - antecipados;
```

**Chip de visibilidade:** chip laranja "Dias antecipados ao PA anterior · Xd" adicionado ao bloco do PA quando `antecipados > 0`, para deixar explícito ao consultar:
```js
const antecipHtml = antecipados > 0
  ? `<span style="background:#FFF7ED;border:1px solid #FED7AA;color:#C2410C;...">Dias antecipados ao PA anterior · ${antecipados}d</span>`
  : '';
```
Posicionado após o chip de abono pecuniário no template. Commit: a78fda8.

---

## Módulo Férias — regras críticas

**Risco de dobra** — thresholds (atualizados 2026-08):
- `critico`: dpd < 60 dias — vermelho
- `atencao`: dpd <= 120 dias — âmbar
- `noradar`: dpd <= 180 dias — azul
- > 180 dias: não aparece no filtro Risco

**Badge Agendado:** azul (`#1849A9`) — diferencia de Concluído (verde)

**Filtro "Em férias hoje":** busca por lançamento ativo no dia (qualquer ano), não por PA do ano corrente

**Layouts dinâmicos por filtro:**
- Risco → `proto-grid-5` (5 colunas, sem coluna "Férias futuras")
- Hoje → `proto-grid-4` (4 colunas, apenas período ativo)
- Demais → 6 colunas padrão

**Situação "Agendado" em PAs não-vigentes (corrigido 2026-08-26):** colaborador com PA vigente sem lançamentos, mas com lançamento futuro em PA anterior zerado, deve aparecer como "Agendado". `paBadge(reg, todosRegs)` e a coluna Agendamentos verificam todos os PAs via `l.fim >= HOJE` quando o PA vigente não tem lançamento futuro. Exibe sublinha "PA anterior" quando o lançamento vem de outro PA.

### Banner de PA ativo fora da área visível — implementado 2026-09-09

**Problema:** `getRegistroParaLancar` retorna o PA mais antigo com saldo > 0 (regra CLT). Quando esse PA é antigo (ex: PA 2022), o botão "+ Lançar" aparece no fundo do drawer e o RH não percebe. Parece que o botão "sumiu".

**Fix:** Banner âmbar no topo do drawer (`drawerHistorico`) quando `regParaLancar` não é o primeiro PA da lista reversa. Mostra "PA XXXX tem Nd de saldo pendente — clique para ir ao período ativo". Clicar faz `scrollIntoView` suave até `#pa-block-${regParaLancar._sbId}`. Cada bloco de PA tem agora `id="pa-block-${r._sbId}"`. Só aparece na visão RH (`IS_RH`).

### Melhorias UX no lançamento RH — implementadas 2026-09-08

**Drawer permanece aberto após confirmar lançamento:** `confirmarDrawerLancamento` salva `_drawerKey` antes de `renderAll()`, depois chama `_abrirDrawerInterno(_keyParaReabrir)` para reabrir. Ordem: renderAll → _abrirDrawerInterno (essencial — se invertido, renderAll fecha o drawer).

**Observação salva no lançamento:** campo `dMotivo` (textarea "Observação") agora é incluído no PATCH como `nota1`/`nota2` e no objeto em memória como `nota`. Campo exibido via `l.nota` no drawer e no print.

**Ano com mais de 4 dígitos em campos de data:** listener global no `document` (capture phase) intercepta todos os `input` em `type="date"` não-readonly e trunca o ano para 4 dígitos se ultrapassar.

**Colaborador sem PA de férias — Cleber mat.208 (Paranavaí):** módulo só exibe colaboradores com registro em `ferias`. Cleber tem dois vínculos: mat.229 (Matriz, desde 2014, com PAs 2020–2026) e mat.208 (Paranavaí, desde 2023-10-01, sem PAs). PAs criados via script Python para mat.208/id=1796: PA 2024 (id=1877), PA 2025 (id=1878), PA 2026 (id=1879). Ambos os vínculos aparecem separadamente na lista — comportamento correto (vínculos distintos).

### Fluxo pendente_gestor (Gozo Solicitado pelo Gestor) — implementado 2026-09

**Tabela:** `ferias.realizacoes` JSONB — entradas `{ saida, retorno, dias, lancIdx, obs, status? }`  
**Status `'pendente_gestor'`** = Gestor solicitou gozo, aguardando aprovação do RH.

**GESTOR_LANCAMENTOS** inclui todas as realizações, inclusive `pendente_gestor`. Para evitar renderização duplicada (bloco autônomo + dentro do gozo), o filtro de lançamentos em `_renderGsolHistoricoRH` **exclui** entradas com `l.status !== 'pendente_gestor'` ao montar a lista de lançamentos.

**Aprovação RH (`rhAprovarGozoPendente`):** PATCH em try/catch próprio com `return` em caso de erro. Re-render (`renderDrawerHistorico`, `renderMetricas`) em try/catch silencioso separado — evita falso "Erro ao salvar" quando PATCH teve sucesso.

### Gozo Real — drawer RH (visão RH)

**Seção gozo (`hist-gozo-section`):** só renderiza quando `temGozos === true`. Sem gozos → sem barra visual.

**Collapse/expand:** ícone chevron no progress row. Collapsed por padrão, exceto quando tem `pendente_gestor` (abre automaticamente). Estado gerenciado pelo Set `_gozoExpanded`.

**Funções:**
- `toggleGozoLista(sbId, lancIdx)` — mostra/esconde a lista `hist-lista-{sbId}-{lancIdx}`, atualiza chevron `hist-chev-{sbId}-{lancIdx}`
- `expandirGozoHist(sbId, lancIdx)` — abre formulário de adição + expande lista + atualiza chevron
- Ícone de calendário chama `toggleGozoLista` (não `toggleGozoSecao`) quando há gozos

**Saldo — destaque visual no header do PA:**
```
Saldo ≤ 0  → verde  #10B981  (período concluído = positivo)
Saldo ≤ 5  → âmbar  #F59E0B  (baixo, atenção)
Saldo > 5  → azul   #1570EF  (normal)
```
Número exibido em `font-size:15px; font-weight:800` para destacar à primeira vista.

**Botão "Adicionar":** não aparece quando `saldoPeriodo <= 0` (sem saldo disponível).

### Gozo Real — drawer Gestor (visão Gestor)

**Pill toggle:** botão azul-tint (`#EFF6FF` bg, `#BFDBFE` border, `#1D4ED8` text) exibindo "N gozo(s) registrado(s)". Sempre visível (não depende de hover). Collapsed por padrão.

**Funções:**
- `gsolToggleGozoLista(perId, lancIdx)` — mostra/esconde `gsol-lista-{perId}-{lancIdx}`, atualiza `gsol-chev-{perId}-{lancIdx}`

**Saldo:** mesmo padrão de cores semânticas do drawer RH.

---

## Módulo Desenvolvimento & Performance — resumo

**Escala:** 1 (Insatisfatório) a 5 (Referência)

**Competências:** 39 pré-cadastradas — 6 comportamentais + 8 áreas técnicas

**Redesign visual completo (2026-10-02):** todas as seções do módulo D&P foram redesenhadas para bater com o mockup aprovado — somente visual, sem alteração de lógica ou Supabase.

**Estado do primeiro ciclo real (2026-10-15):**
- Ciclo "Gratificação CD - Outubro/2026" — `status='rascunho'`, `elegibilidade_ids=["ORIEL"]`
- **88 participantes adicionados** via sugestão automática
- Snapshots incluem: `nome, matricula, empresa, setor, cargo, unidade, em_experiencia, data_admissao`
- Cards de participantes exibem matrícula como "Mat. 205" e data de admissão como "Admissão: dd/mm/aaaa"
- Próximo passo: abrir o ciclo de outubro e validar com perfis RH e ORIEL

**Filtro de elegibilidade por período do ciclo (commit bd7f700, 2026-10-15):**
- `dpIsElegivelPeriodo(c, ciclo)`: bloqueia admitidos após `data_fim` e desligados antes de `data_inicio`
- Colaboradores sem `data_admissao` são bloqueados quando ciclo tem `data_fim` (exigem inclusão manual explícita)
- Limites inclusivos: admitido no último dia e desligado no primeiro dia do período são elegíveis
- Aplicado em `dpIsElegivel` (picker manual) e `dpGerarPreviewParticipantes` (sugestão automática) — mesma regra nos dois caminhos
- Para ciclos retroativos (`data_fim < hoje`): `dpAbrirDrawerCiclo` mescla inativos com `data_demissao >= data_inicio` em `_colaboradores`
- `loadColaboradores` agora inclui `data_demissao` no select

**UX picker de participantes (commits 690c32c, 73e8ce8, 2026-10-15):**
- `#dpParticipantesBotoes` — container fixo acima do picker; botões permanecem visíveis quando picker está aberto
- Picker abre com estado vazio (campo busca em foco, sem lista); lista só aparece após digitar ≥1 caractere

**O que foi implementado no redesign:**
- Layout duas colunas (`.content-area` + `.list-col` + `.sidebar-col`) em todas as seções novas
- Painéis laterais (`.sidebar-panel`) com contadores em tempo real populados por JS
- Ciclo banner (`.ciclo-banner`) gradiente azul com barra de progresso
- Agrupamento por status com `.section-header` + `.section-count`
- Toggle switches CSS (`.toggle`) substituindo `<input type="checkbox">` raw
- Ícones SVG inline substituindo emojis em todas as funções `render*()`
- Botões de ação `.icon-btn` (30×30, hover suave)
- Busca em tempo real nos Modelos (`.list-search` + `modelosSearchInput`)
- Wizard de criação/edição de ciclo (RH): `.wiz-overlay wiz-overlay--center` + `.wiz-container` (modal centralizado, parent/child — commit cfb4846)
- Wizard de avaliação (Gestor): modal centralizado `.modal-aval-overlay` (commit f3de5d9)
- `--bg` ajustado para `#F8FAFC` (era `#E8EDF4`)

**Motor D&P V1 completo (2026-10-03):** Etapas 2–6 implementadas. Migrations 114, 115, 116 executadas (2026-10-14). **V1 publicada (`em_uso=true`)** — 10 critérios binários, R$40 cada, máximo R$400/mês. Commit c0c65e8.

**Correções e normalização (2026-10-14):**
- Bug raiz dos dropdowns vazios corrigido (commit ff6b380): query `_colaboradores` usava `situacao` (coluna inexistente → API 400 silencioso → array vazio). Corrigido para `ativo=eq.true` + campo `gestor` adicionado.
- **Fase 1 normalização `colaboradores.gestor` executada:** 11 registros corrigidos (EVANDRO +4, FLAVIO +2, JANDER +2, JUNINHO +3). `Robson (R)` → CAPOIA: 1 pendente (LEONAM PADOVANI VALENSOLA, mat.590).
- **Arquitetura gestor-equipe confirmada:** `auth.uid() → usuarios_perfil.colaborador_id → param_gestor.colaborador_id + apelido → colaboradores.gestor ilike apelido`. Cadeia idêntica ao Férias.

**Bugs resolvidos no fluxo de criação do primeiro ciclo (2026-10-14 a 2026-10-15):**
1. `dpGerarPreviewParticipantes` usava `situacao=eq.ativo` → corrigido para `ativo=eq.true` (commit dc9cb2b).
2. **RLS recursão infinita** entre `dp_ciclos_gestor_sel` (mig 113) e `dp_ciclo_participantes_avaliador_sel` (mig 116): migration 117 — `auth_avaliador_ciclo_ids()` SECURITY DEFINER. **Executada.**
3. **HTTP 400 "invalid input syntax for uuid: Oriel"** — dropdown avaliador. Fix: `sbRpc('fn_get_usuarios_perfil')` + `opt.value = u.user_id` (commit 0c1536b).
4. **HTTP 400 "invalid input value for enum dp_tipo_elegibilidade: por_gestor"** — migration 118: DROP + RECREATE ENUM. **Executada.**
5. **`elegibilidade_ids UUID[]`** → alterado via SQL inline para `TEXT[]`. **Executado.**
6. **Dropdown "Por gestor" armazenava `usuarios_perfil.nome`** → mismatch com `colaboradores.gestor`. Fix (commit 3125ee8): usa `param_gestor.apelido` como valor; `elegibilidade_ids[0]` atualizado no banco para `["ORIEL"]`.
7. **Colunas inválidas em `empresa` e `unidade`** causavam HTTP 400 silencioso → array vazio. Corrigido para `empresa_atuacao` em `loadColaboradores` e `dpGerarPreviewParticipantes` (commits 5a48b78, 6791ef1).
8. **`confirm()` nativo substituído por modal inline** (commit 57848b4) — usa CSS vars, estilo premium.
9. **Picker listava todos os colaboradores ativos** independente de elegibilidade. Fix (commit dd10432): `dpFiltrarPicker` aplica `dpIsElegivel(c)` como filtro rígido.
10. **`dpRenderInfoCiclo` exibia `"por_gestor"` raw** → Fix (commit a38c159): exibe "Por gestor — ORIEL LEITE RODRIGUES" usando `_dpParamGestores`.

**Melhoria entregue (2026-10-15, commit f49e176):** destaque visual `em_experiencia` — 20 colaboradores da equipe Oriel em período de experiência. Badge âmbar no picker e na lista de participantes. `em_experiencia` gravado no snapshot do participante.

**`prazo_avaliacao` implementado (2026-10-15, commits c0f3a93–737e631):**
- Coluna `prazo_avaliacao DATE NULL` adicionada a `dp_ciclos` (migration executada manualmente)
- Campo opcional no modal de criação/edição de ciclos — RH define, gestor não tem acesso
- Card sidebar: 4 estados (verde/âmbar/cinza/silêncio) baseados em prazo + pendentes
- Lista de ciclos: prazo discreto ou âmbar quando vencido
- Aba Informações: data formatada ou "Não definido" quando null
- Edição de ciclos: `dpAbrirModalCiclo(cicloId)` faz PATCH; botão "Editar ciclo" na aba Informações (RH only)

**Schema atual após correções:**
- `dp_ciclos.tipo_elegibilidade`: ENUM `dp_tipo_elegibilidade` — valores: `todos | por_setor | por_cargo | por_gestor | por_colaborador`
- `dp_ciclos.elegibilidade_ids`: `TEXT[]` (não UUID[])
- `dp_ciclos.prazo_avaliacao`: `DATE NULL` — prazo para gestores concluírem (≠ `data_fim`)
- `dp_ciclos.avaliador_id`: `UUID` (FK auth.users, nullable) — preenchido pelo dropdown que usa `fn_get_usuarios_perfil()`
- Função `auth_avaliador_ciclo_ids()` SECURITY DEFINER disponível no banco
- `dp_ciclo_participantes.snapshot`: inclui `em_experiencia` boolean desde commit f49e176

**Migrations executadas (2026-10-14):** 117 (RLS recursão), 118 (ENUM elegibilidade). Inline SQL: `elegibilidade_ids TYPE TEXT[]`.

| Etapa | Status |
|---|---|
| 1 — Ciclos | ✅ |
| 2 — Avaliação do Gestor | ✅ formulário guiado, CRUD dp_avaliacoes + dp_respostas |
| 3 — Cálculo | ✅ lógica JS por tipo_calculo → dp_resultados; Opção B (binário monetário → dp_resultados_bonus via RPC dp_salvar_resultado) |
| 4 — Camada financeira | ⏭ pulada (baixa prioridade) |
| 5 — Análise e fechamento | ✅ ajuste inline, encerramento, histórico de eventos |
| 6 — Exportação | ✅ botão Exportar Excel na aba Resultados |
| Gestor D&P — Minha Equipe | ✅ commit fbd50bb (2026-10-14) — aba exclusiva gestor, drawer 3 abas, motor RH reutilizado |
| RLS Fase 2 + avaliador_id | ✅ migration 116 (commit c0c65e8) — dp_ciclos.avaliador_id, 9 policies _avaliador_*, gestor vê próprio bônus |

**Drawer do ciclo RH centralizado (commit cfb4846, 2026-10-15):** `#drawerDpCicloOverlay` convertido de `.drawer-overlay` (right-side) para `.wiz-overlay wiz-overlay--center`; `#drawerDpCiclo` virou filho `.wiz-container`. JS: `dpAbrirDrawerCiclo` e `dpFecharDrawerCiclo` toggleam apenas o overlay pai (não mais o painel filho separado).

**Badge Em experiência + data de admissão na aba Avaliações (commit cf9351a, 2026-10-15):** `dpRenderAvaliacoes` agora exibe fundo âmbar, badge "⏱ Em experiência" e linha "Admissão: dd/mm/aaaa" lidos do snapshot — mesmo padrão visual da aba Participantes. Compartilhado entre RH, Gestor e Diretoria sem código adicional.

**`hideAvaliarWhenDone` em `dpRenderAvaliacoes` (commit 63c3a60, 2026-10-15):** novo opt booleano. Quando `true`, oculta botão "Avaliar" para participantes com `status === 'concluida'` ou `'publicada'`. Gestor passa `hideAvaliarWhenDone: true`; RH não passa (botão sempre visível). Sem duplicação de lógica de renderização.

**Funções de renderização compartilhadas RH × Gestor (commit 0a36c67):** `dpRenderParticipantes`, `dpRenderAvaliacoes`, `dpRenderResultados` — fonte única, diferenças controladas via `opts`. Gestor usa `_dpAvaliacoes = _gdpAvaliacoes` (linha 6449) para sincronizar estado antes de renderizar.

**Filtros multi-select aba Avaliações (commits 1dc4d94 + 191f100 + 432ae11, 2026-10-16):**
- Filtro por nome (input em `.gdp-aval-search-wrap` com ✕ `.gdp-aval-search-clear`) + multi-select de cargos (dropdown checkboxes) nas visões RH e Gestor
- Componente compartilhado `_dpCargoDropdownHtml(ddId, cargos, Set)` — label dinâmico, ✕ inline no botão (`stopPropagation`), "Limpar seleção" no menu, fecha ao clicar fora
- `_dpFiltrarParticipantes(lista, nome, cargosSet)` — utilitária compartilhada usada em render e navList
- Estado: `_dpAvalFiltroCargos` (Set, RH) e `_gdpAvalFiltroCargos` (Set, Gestor); resetados ao fechar drawers
- **Navegação respeita filtros**: navList construída com `_dpFiltrarParticipantes` no momento de abrir o formulário; fallback para todos os ativos se resultado vazio
- **Foco restaurado**: `dpRenderAvaliacoes` salva `activeElement.id` + `selectionStart` antes do `innerHTML` e restaura depois — cursor não some ao digitar
- CSS: `.gdp-aval-search-wrap / .gdp-aval-search-clear / .gdp-cargo-dd / .gdp-cargo-btn / .gdp-cargo-x / .gdp-cargo-menu / .gdp-cargo-item / .gdp-cargo-clear`

**Migration 125 — enum nao_participa (commit 432ae11, 2026-10-16, executada):**
- `ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'nao_participa_marcado'`
- `ALTER TYPE dp_evento_historico ADD VALUE IF NOT EXISTS 'nao_participa_revertido'`
- Corrige HTTP 400 ao marcar não participante (migration 124 usava esses valores nas RPCs mas nunca os adicionou ao ENUM)

**Melhorias no formulário de avaliação (commits bd11018 + 978483e + 85cc945, 2026-10-16):**
- **Foto do colaborador**: iniciais imediatas; foto async — busca em `_colaboradores` em memória (RH) ou fetch REST `colaboradores` (Gestor); `Number()` para evitar mismatch int/string
- **Alinhamento**: `justify-content:flex-start` + `text-align:left` explícitos no header-info
- **Navegação com setas**: `[‹]` `[›]` + contador `"N / total"`; respeitam filtros ativos; salva antes de navegar; bloqueia se save falhar
- **Info ícone corrigido**: `.aval-info-expand` como irmão do `.aval-card` elimina clipping do `overflow-y:auto`

**Redesign do formulário de avaliação (commits 3d938a7 + 851ddbd, 2026-10-15):**
- Cards compactos por critério: ícone SVG temático (`_dpIconeCriterio`), numeração discreta, nome em negrito
- Descrição e referência recolhidas por padrão; botão ℹ individual expande/recolhe via `dpToggleInfo(vcId)` (bloco `.aval-info`)
- Botões Sim/Não sem valores em reais; estado ativo via classes CSS
- Obs e botões na mesma linha (`.aval-row`); textarea compacto (32px) expande para 80px ao focar (`dpAvalObsFocus/Blur`); recolhe ao perder foco se vazio; reabre expandido quando há valor salvo; placeholder muda para "⚠ Justificativa…" ao selecionar Não
- Contador de progresso + badge de valor acumulado em tempo real no header (oculto em modelos sem valor monetário)
- `dp_respostas.observacao` lida e gravada (coluna já existia, nunca usada); zero migration
- Mobile < 480px: obs ocupa linha inteira abaixo dos botões
- Funções novas: `dpToggleInfo`, `dpAvalObsFocus`, `dpAvalObsBlur`; estrutura compartilhada RH × Gestor preservada

**Próximo passo D&P:** validar formulário de avaliação com dados reais (persistência obs, ℹ toggle, contador) → depois abrir o ciclo de outubro e validar com perfis RH e ORIEL.

**RLS D&P:**
- Migration 112: RLS habilitado nas 21 tabelas dp_*; políticas RH/admin CRUD; gestor sem acesso (fase 1). Executada.
- Migration 113: `auth_gestor_equipe_ids()` SECURITY DEFINER + 21 políticas gestor por equipe. Executada 2026-10-14.

**Melhorias D&P — sessão 2026-10-14 (commits d81f2a0 + ce33ffc + 62efde4):**
- `ce33ffc` — Fix `exibirNota`: após migration 114, `nota_final=NULL` (não `0`) para modelos monetários; lógica corrigida para `nota_final != null`
- `d81f2a0` — L1: `elegibilidade_ids` agora persistida corretamente em `dpSalvarCiclo`; `dpGerarPreviewParticipantes` lê de `ciclo.elegibilidade_ids` (não mais variáveis temporárias)
- `d81f2a0` — L2: nova opção "Por gestor / equipe" (`por_gestor`) — select populado de `_colaboradores.gestor`, filtro por igualdade exata
- `d81f2a0` — L3: `dpAbrirFormAvaliacao` carrega histórico por critério via `dp_fn_historico_criterio` (paralelo) → `_dpHistoricoCriterios`; `dpRenderFormAvaliacao` exibe bloco read-only abaixo de cada campo
- `62efde4` — P1: botão "Avaliação individual" pré-configura modal com `por_colaborador` (sem estrutura paralela)
- `62efde4` — P2: Migration 115 adiciona `resposta_texto` ao retorno de `dp_fn_historico_criterio`; frontend exibe "Sim"/"Não" para critérios binários

**Estado do banco D&P (verificado 2026-10-15):**
- `dp_escalas`: **0** — nenhuma criada (bloqueia critérios do tipo `escala`)
- `dp_tabelas_conceito`: 0
- `dp_criterios`: 49 ativos (comportamentais + técnicos)
- `dp_modelos`: 1 — "Avaliação Mensal Produtividade CD"
- `dp_versoes`: 1 — V1, `em_uso=true` (publicada 2026-10-14), 10 critérios binários, `valor_se_sim=40` → máx R$400
- `dp_ciclos`: **1** — "Gratificação CD - Outubro/2026", `status='rascunho'`, `elegibilidade_ids=["ORIEL"]`, `avaliador_id=UUID Oriel`
- `dp_ciclo_participantes`: **0** — 88 elegíveis identificados (20 deles `em_experiencia=true`)
- `dp_tipos_avaliador`: 4 (Gestor, RH, Auto-avaliação, Avaliador específico)

**RLS D&P — estado final (2026-10-15):**
- Migration 112: base RLS 21 tabelas, RH/admin CRUD, diretoria SELECT, gestor bloqueado. Executada.
- Migration 113: `auth_gestor_equipe_ids()` + 21 políticas gestor por equipe. Executada.
- Migration 114: `dp_salvar_resultado` SECURITY DEFINER. Executada.
- Migration 115: `dp_fn_historico_criterio` com `resposta_texto`. Executada.
- Migration 116: `dp_ciclos.avaliador_id`, 9 políticas `_avaliador_*`. Executada.
- Migration 117: `auth_avaliador_ciclo_ids()` SECURITY DEFINER — quebra recursão ciclos↔participantes. Executada.
- Migration 119: SELECT em `dp_historico_eventos` para gestor (gap da 113). **Executada 2026-10-15**.

**Interface D&P — diretoria somente leitura (commit a78b661, 2026-10-15):**
- `isDiretoria` declarada em `init()` junto com `isGestor`
- `[data-rh-only]` estendido para ocultar botões de diretoria também
- Botões Abrir/Encerrar no card de ciclo: `&& _perfil !== 'diretoria'`
- Botões Editar/Abrir/Encerrar no drawer: `&& _perfil !== 'diretoria'`
- Botão Encerrar na aba Resultados: `&& _perfil !== 'diretoria'`

**Fluxo de conclusão de avaliações (commits 65ce27f + 7149edb + f72308a, 2026-10-16, migration 126 executada):**
- Drawer: só botão "Salvar"; "Concluir avaliação" removido do formulário
- **Salvar fecha o formulário** — `salvarAvaliacao('em_andamento')` chama `fecharFormAval()` ao final
- **Auto-save na navegação** — `dpNavForm(delta)` detecta mudanças, salva via `_dpSalvarParaNavegar()`, exibe toast "Salvo automaticamente ✓"
- Avaliação concluída abre em modo leitura: campos desabilitados, banner verde "✓ Concluída em DD/MM"
- Botão "Concluir" individual por linha na lista (aparece quando `status='em_andamento'`)
- Botão "Concluir equipe" (Gestor) e "Concluir todas" (RH) no cabeçalho da aba Avaliações
  - Bloqueado se houver participante sem avaliação iniciada (`nao_iniciada` ou sem registro) e sem `nao_participa=true`
  - Lista os pendentes e pede resolução; confirmação antes de concluir em lote
- Backend: `trg_bloquear_resp_aval_concluida` (dp_respostas) + `trg_bloquear_reverter_conclusao` (dp_avaliacoes)
- Helpers: `dpConfirmDialog`, `dpAvalFormSetReadonly`, `dpConcluirAvaliacaoIndividual`, `dpConcluirTodasAvaliacoes(escopo)`, `dpLimparAvaliacao()`
- **Encerrar ciclo** (RH) permanece separado, via sidebar (`dpEncerrarCicloSidebar`) — sem mudança

**Limpar avaliação (commit f72308a, 2026-10-16):**
- Botão vermelho sutil no rodapé esquerdo do formulário — só aparece quando avaliação é editável
- Confirmação obrigatória antes de apagar; depois: DELETE `dp_respostas` + PATCH `dp_avaliacoes.status → nao_iniciada`
- Formulário **permanece aberto** após limpar, pronto para repreenchimento

**Próximo passo D&P:** validar fluxo completo com Oriel (ciclo Setembro aberto) — Avaliar → salvar → Concluir individual → Concluir equipe. Outubro permanece rascunho.

**PostgREST INNER JOIN implícito — armadilha crítica (identificada e corrigida 2026-10-15):**
Quando FK é `NOT NULL` e recurso relacionado é embutido via `select=*,tabela(*)`, PostgREST usa INNER JOIN. Com RLS ativa e policies diferentes para o perfil gestor, o INNER JOIN zera toda a query silenciosamente. Fix: sempre separar em queries independentes + montar objeto em JS. Três pontos corrigidos no D&P:
- `gestorDpLoadCiclos` (commit `89effd2`) — ciclos + versoes + participantes
- `gestorDpAbrirDrawer` (commit `f3de5d9`) — ciclo + versao
- `dpAbrirFormAvaliacao` (commit `5bf1b9f`) — versao_criterios + criterios + escalas

**Bugs corrigidos no login/sessão do gestor (commit `89effd2`, 2026-10-15):**
- `initDpGestor is not defined`: `init()` estava no primeiro `<script>`, `initDpGestor` definida no segundo → TDZ. Fix: `init()` movida para fim do segundo script.
- Token expiry: `expires_at` em segundos vs `Date.now()` em milissegundos → comparação sempre falsa. Fix: `sess.expires_at * 1000 < Date.now()`.
- `sbGet` agora detecta `status===401` e chama `logout()`.

**UX gestor D&P (commit `f3de5d9`, 2026-10-15):**
- `formAvalOverlay` migrado de right-side drawer (`.wiz-overlay`, z-index 9000) para modal centralizado (`.modal-aval-overlay`, z-index 9100, `display:flex; align-items:center; justify-content:center`).
- Indicador de progresso no header ("X de Y critérios respondidos").
- Filtros na aba Avaliações: busca por nome + select cargo.
- Card de ciclo: período em linha própria "Período avaliado DD/MM a DD/MM · N participantes", 12px, `--text-sec`, alinhado à esquerda (fix `justify-content:flex-start` — `.row-meta` global tem `flex-end`).

---

## Segurança — REGRA CRÍTICA

- **NUNCA usar a secret key no browser**
- Publishable key (`eyJ...`) → JS inline dos módulos HTML
- Secret key → apenas scripts Python locais (ex: `scripts/setup_desenvolvimento.py`)

---

## Módulo Admissão — regras críticas (atualizado 2026-09-17)

**Matrícula condicional:** obrigatória somente para `tipo_vinculo === 'clt'`. Promotoras e Pró-labore não têm matrícula — validação frontend condicional, coluna `matricula` nullable no banco (migration 054).

**Fluxo obrigatório:** Aprovar Ficha → Efetivar. Botão "Efetivar direto" removido. Processo de admissão (checklist) criado em `_confirmarAprovar`.

**Campos obrigatórios na efetivação:** nome, empresa, data admissão, matrícula (se CLT). Campos com outline vermelho quando faltando.

**Validação de ano em `data_admissao` (2026-10-07):** ano deve estar entre 1950 e 2099. Inputs HTML têm `min="1950-01-01" max="2099-12-31"`. `confirmarEfetivar()` (admissão) e `salvarFicha()` (cadastro) rejeitam e exibem erro antes de enviar ao Supabase. Motivação: Phelipe Bandeira (id=2305) foi efetivado com ano `20226` → `NaN anos` no tempo de empresa + drawer inoperante.

**Ficha resumida (`tipo_ficha = 'resumida'`):** oculta seções Sinalizações, Indicação e abas Remuneração e Benefícios. Controlado por `_aplicarModoFicha(tipoVinculo)` lendo `TIPOS_VINCULO`.

---

---

## Módulo Cadastro — bugs corrigidos (2026-10-03)

### Workflow de demissão disparava ao editar colaborador já demitido

**Sintoma:** ao salvar qualquer alteração (motivo, cargo, endereço) em um colaborador já demitido, o sistema tentava criar ou atualizar o processo de demissão no Workflow, mesmo sem alterar a data.

**Causa:** condição `if (novaDem)` verificava apenas se havia uma data no campo — não se ela tinha mudado.

**Fix:** condição alterada para `if (novaDem && novaDem !== demAnterior)`. Além disso, quando a data muda (nova ou corrigida), um modal de confirmação é exibido **após** o save bem-sucedido:
- Nova data → "Deseja abrir o processo de demissão no Workflow?"
- Data corrigida → "A data foi alterada de X para Y. Deseja atualizar o Workflow?"
- Botões: "Não, só salvar" / "Sim, atualizar Workflow"

**Comportamento final por cenário:**

| Cenário | Workflow |
|---|---|
| Data preenchida pela primeira vez | Pergunta se quer abrir processo |
| Data de demissão corrigida | Pergunta se quer atualizar processo |
| Qualquer outro campo alterado | Salva normalmente, Workflow não é tocado |

**Funções envolvidas:** `salvarFicha` (condição corrigida), `_mostrarConfirmWorkflowDemissao`, `_fecharConfirmWorkflowDemissao`, `_confirmarWorkflowDemissao` (novas). HTML: `#wfDemissaoOverlay` (modal inline, mesmo padrão `.drawer-overlay`).

---

## Módulo Cadastro — bugs corrigidos (2026-09-18)

### Bug 1: Endereço não salva ao criar Promotora nova

**Sintoma:** ao incluir Promotora nova, dados de endereço (CEP, rua, número, bairro, cidade, UF) preenchidos no formulário eram perdidos — sistema exibia "Salvo ✓" mas endereço não aparecia depois.

**Causa:** função `_modoNovo` (criação de colaborador) não incluía os campos de endereço no payload do `INSERT`. O endereço só era enviado na edição (PATCH), nunca na criação.

**Fix em `modulos/cadastro/index.html`:** campos de endereço adicionados ao payload de criação:
```js
cep:        document.getElementById('df-cep').value.trim() || null,
logradouro: document.getElementById('df-rua').value.trim() || null,
numero:     document.getElementById('df-numero').value.trim() || null,
complemento:document.getElementById('df-complemento').value.trim() || null,
bairro:     document.getElementById('df-bairro').value.trim() || null,
cidade:     document.getElementById('df-cidade').value.trim() || null,
uf:         document.getElementById('df-estado').value || null,
```

### Bug 2: Campo "Quantidade de filhos" some após salvar

**Causa raiz (dupla):**

1. **Coluna errada:** código usava `tem_filhos` para mapear/salvar, mas a coluna na tabela `colaboradores` é `possui_filhos` (TEXT). Supabase ignora silenciosamente colunas inexistentes em PATCH.

2. **Coluna `qtd_filhos` não existia em `colaboradores`:** existia apenas em `admissao_fichas`. Todos os saves eram descartados silenciosamente.

**Fix:**
- `supabaseToJS`: `row.tem_filhos` → `row.possui_filhos`
- Payload PATCH: `tem_filhos` → `possui_filhos`
- Migration `058_colaboradores_qtd_filhos.sql` executada: `ALTER TABLE colaboradores ADD COLUMN IF NOT EXISTS qtd_filhos INTEGER`
- **`possui_filhos` também não existia em `colaboradores`** — criada manualmente via SQL: `ALTER TABLE colaboradores ADD COLUMN IF NOT EXISTS possui_filhos TEXT` (executado 2026-09-18, confirmado via teste)

**Armadilha:** a coluna `possui_filhos` existia em `admissao_fichas` mas **nunca foi criada em `colaboradores`**. A memória anterior dizia "existe desde migration 006" — isso estava errado. Corrigido aqui.

---

## Módulo Admissão — fix UF de nascimento no PDF (2026-10-02)

**Commit:** `50d6d50`

Campo `estado_naturalidade` (UF Nasc.) estava salvo no banco mas não aparecia na Ficha de Registro gerada pelo "Gerar PDF". O campo `f.naturalidade` (cidade) entrava na composição mas `f.estado_naturalidade` era ignorado.

**Fix em `modulos/admissao/index.html` linha ~2421:**
```js
// Antes:
[f.nacionalidade, f.naturalidade].filter(Boolean).join(' — ')

// Depois:
[f.nacionalidade, [f.naturalidade, f.estado_naturalidade].filter(Boolean).join(' / ')].filter(Boolean).join(' — ')
```

Resultado: `BRASILEIRA — PARANAVAÍ / PR`

**Atenção:** o `estado_naturalidade` precisa estar salvo no banco para aparecer no PDF. Para fichas antigas, o RH deve abrir o painel, confirmar que a UF está selecionada e clicar "Salvar alterações" antes de gerar o PDF.

---

## Módulo Admissão — bug corrigido na efetivação (2026-09-18)

**Sintoma:** `qtd_filhos` e `possui_filhos` preenchidos na admissão online não eram copiados para `colaboradores` ao efetivar.

**Causa:** payload de efetivação (`efetivarContratacao`) enviava `tem_filhos` (coluna inexistente) e não incluía `qtd_filhos`.

**Fix em `modulos/admissao/index.html`:**
```js
// Antes:
tem_filhos: f.tem_filhos ? 'Sim' : 'Não',

// Depois:
possui_filhos: f.tem_filhos ? 'Sim' : 'Não',
qtd_filhos:    f.qtd_filhos ? parseInt(f.qtd_filhos) : null,
```

**Fluxo completo agora funciona:** admissão online → efetivação copia `possui_filhos` e `qtd_filhos` para `colaboradores`. Para admitidos antes do sistema, RH preenche manualmente no Cadastro.

---

## Módulo Ficha do Colaborador — Etapa 2 (hero redesign, concluída)

**Arquivos:** `modulos/colaborador/index.html`, `modulos/colaborador/ficha.css`, `modulos/colaborador/ficha-render.js`, `modulos/colaborador/ficha-data.js`

**Status:** implementado (commit `19c7c67`). Aguardando validação visual da usuária — pendência arrastada da sessão anterior.

### Arquitetura do hero — 3 zonas (grid)

`.hero-inner` usa `display: grid; grid-template-columns: 1fr 204px 252px` — não mais flex.

| Zona | Classe | Conteúdo |
|---|---|---|
| Esquerda (~55%) | `.hero-zone-left` | foto 96px + identidade + métricas |
| Centro | `.hero-zone-actions` | Voltar (link) + "Editar cadastro" (btn azul) + "Ações ▼" (dropdown) |
| Direita | `.hero-zone-alertas` | Painel "Alertas e lembretes" |

O card flutuante: `.hero { background:transparent; padding:16px 32px 0 }` + `.hero-inner { background:#fff; border-radius:12px; border:1px solid #EAECF0; box-shadow:... }`.

### Botões e navegação (Zona 2)

- **"Editar cadastro"** → `../cadastro/index.html?id=<colab.id>` (azul primário)
- **"Ações ▼"** → dropdown `.hero-acoes-menu` com classe `.open` controlada por `_toggleAcoes(event)` + `document.addEventListener('click')` para fechar ao clicar fora
  - "Abrir no Cadastro" → mesmo link do Editar cadastro
  - "Ver Processos" → `../processos/index.html?colaborador_id=<colab.id>`
  - "Imprimir ficha" → `window.print()`
- **"Voltar"** → permanece como `.hero-back`, agora no topo da Zona 2

### Alertas e lembretes (Zona 3)

`_buildAlertas()` em `ficha-render.js` — usa dados já carregados (sem fetch extra):

| Alerta | Cor | Fonte de dados |
|---|---|---|
| Processos abertos em andamento | amber | `_processosAbertos` (novo) |
| Em período de experiência | amber | `_colab.em_experiencia` |
| Férias vencendo (dobra < 60 dias, saldo > 0) | warn (laranja) | `_ferias` |
| Férias agendadas ≤ 90 dias | info (azul) | `_ferias` |
| Aniversário ≤ 30 dias | info (azul) | `_colab.data_nascimento` |
| Tudo em dia (fallback) | ok (verde) | nenhuma condição acima ativa |

### `_processosAbertos` — novo campo global

Adicionado em `ficha-data.js`:
```js
let _processosAbertos = [];
// No Promise.all do init():
sbGet(`/rest/v1/processos_rh?colaborador_id=eq.${colabId}&status=eq.aberto&select=id,tipo,criado_em&limit=10`)
// Depois:
_processosAbertos = processos || [];
```

### Integração com Cadastro e Processos por URL (compatível com fluxo existente)

**`modulos/cadastro/index.html`** — após o bloco `?efetivar=`, adicionado:
```js
const _idParam = new URLSearchParams(window.location.search).get('id');
if (_idParam && !_efId) {
  const _idIdx = COLABORADORES.findIndex(c => String(c._sbId) === _idParam);
  if (_idIdx >= 0) { abrirFicha(_idIdx); }
  history.replaceState({}, '', window.location.pathname);
}
```
Reutiliza `abrirFicha()` existente — zero duplicação de lógica.

**`modulos/processos/index.html`** — adicionado:
```js
let _filtroColabId = new URLSearchParams(window.location.search).get('colaborador_id') || null;
```
`_filtrarAndamento()` ampliada: se `_filtroColabId` ativo, filtra `_TODOS_PROCESSOS` por `colaborador_id` antes de aplicar busca textual. Após `renderProcessos()` no `init()`, chama `_filtrarAndamento()` e limpa o URL param.

### Helper `_titleCase(str)`

Banco armazena nomes em CAPS (ex: "ADILSON VAZ"). Helper aplicado em `renderHero()` para exibir em Title Case na Ficha:
```js
function _titleCase(str) {
  if (!str) return str;
  const min = new Set(['de','da','do','dos','das','e','em','na','no']);
  return str.toLowerCase().split(' ').map((w,i) =>
    (!i || !min.has(w)) ? w.charAt(0).toUpperCase()+w.slice(1) : w
  ).join(' ');
}
```

### Etapas da Ficha

| Etapa | Status |
|---|---|
| 1 — Separação CSS/JS em arquivos próprios | ✅ concluída |
| 2 — Hero redesign (3 zonas, alertas, botões, integração URL) | ⏳ implementada (commit `19c7c67`), aguardando validação |
| 3 — Reorganização das abas | 🔒 bloqueada até Etapa 2 validada |
| 4 — Integração Uniformes, Documentos, Processos, Benefícios | 🔒 bloqueada |

---

## Controle de acesso centralizado — `guardModulo()` (implementado 2026-09-21)

**Commit:** `239ed84` — 10 arquivos alterados.

### `permissoes.js` — nova função `guardModulo(chave)`

Verifica autenticação + autorização em um único ponto. Regras:
- Sem `sb_session` → redireciona para `login.html`
- Sessão expirada → limpa localStorage + redireciona para `login.html`
- `perfil === 'admin'` → bypass total (passa sem checar `acesso_modulos`)
- `acesso_modulos` contém `chave` → passa
- Senão → redireciona para `../../index.html` (home, não login)
- **`acesso_modulos = []` não concede mais acesso irrestrito** — qualquer perfil não-admin precisa ter a chave explícita

### Mapa RBAC em `index.html`

`relatorios: 'card-relatorios'` adicionado ao mapa. Todos os 7 módulos do grid agora filtrados pelo mesmo mecanismo.

### `MODULOS_SISTEMA` em `modulos/parametros/index.html`

`relatorios` e `desenvolvimento` incluídos — administrador pode agora conceder/revogar via tela de Permissões.

### Módulos protegidos

Todos os 7 módulos com acesso restrito receberam:
1. `<script src="../../permissoes.js"></script>` no `<head>` (onde não havia)
2. Chamada `guardModulo('chave')` no início do bloco de auth, antes de qualquer lógica

| Módulo | Guard |
|---|---|
| Férias | `guardModulo('ferias')` |
| Processos | `guardModulo('processos')` |
| Cadastro | `guardModulo('cadastro')` |
| Admissão | `guardModulo('admissao')` |
| Uniformes | `guardModulo('uniformes')` |
| Desenvolvimento | `guardModulo('desenvolvimento')` |
| Relatórios | `guardModulo('relatorios')` |

### Supabase — `acesso_modulos` de Heloisa (RH)

PATCH executado: adicionado `relatorios` à lista de Heloisa (id=3).
Lista final: `["cadastro","ferias","processos","uniformes","admissao","relatorios"]`

### Validação no ambiente (GitHub Pages)

Testado com 13 navegações reais via injeção de `localStorage` por perfil:
- Admin → todos os módulos: **passa**
- RH (Heloisa) → Relatórios: **passa**; Desenvolvimento (sem permissão): **bloqueado → home**
- Gestor → Férias: **passa**; Relatórios URL direta: **bloqueado → home**
- Logística → Uniformes: **passa**; Relatórios: **bloqueado → home**
- Colaborador → qualquer módulo: **bloqueado → autoatendimento**
- Sem sessão → qualquer módulo: **bloqueado → login**

---

## Módulo Férias — bug `initGestor()` corrigido (2026-09-21)

**Commit:** `c447857`

**Problema:** gestores sem `colaborador_id` preenchido entravam no fluxo de RH e viam todos os colaboradores. A lógica usava `!colaborador_id` como proxy para "é RH" — incorreto.

**Fix (código):** `initGestor()` agora determina perfil pelo campo `perfil`, não pela ausência de `colaborador_id`:
- `perfil === 'gestor'` + `colaborador_id` nulo → erro de configuração (nunca carrega todos)
- `perfil === 'gestor'` + `colaborador_id` preenchido → carrega só a equipe
- `perfil !== 'gestor'` (rh/admin/etc.) → fluxo irrestrito

**Fix (dados):** PATCH em `usuarios_perfil` para 3 gestores que estavam com `colaborador_id` nulo:
- Carlos de Paula (id=4) → `colaborador_id=1828`
- Rafhael (id=13) → `colaborador_id=1777`
- Prata (id=14) → `colaborador_id=1636`

---

## Código legado removido (2026-09-21)

### Módulo Férias — `parseWorkbook` removida (commit `476d796`)

Função `parseWorkbook` (~108 linhas) removida de `modulos/ferias/index.html` — código morto da versão xlsx, nunca chamada após migração para Supabase.

Filtros por texto de cargo também removidos:
- `supabaseParaModelo`: removida condição `cargo.includes('sócio') || cargo.includes('socio')`
- `_carregarEquipeGestor`: substituído `tv !== 'clt' || cargo.includes('sócio')` por `return tv === 'clt'`

### Módulo Relatórios — bug Por Gênero incluindo demitidos (commit `ecae498`)

**Causa:** relatório Por Gênero não tinha `<select id="f-situacao">` no painel, então `situacaoFiltro()` retornava `''` e o filtro de situação era ignorado — demitidos entravam no resultado.

**Fix:** adicionado select `#f-situacao` (padrão "Ativo") no `renderFiltros` do relatório `genero`.

---

## Dashboard Gestor — arquitetura (set/2026)

Aba `dashboard-gestor` na visão Gestor. Container `#gdashContent`, renderizado por `renderAnalyticsGestor()`.

**Cinco blocos:** A=Resumo executivo inline · B=Atenção (críticos sem agendamento) · C=Próximas saídas 30 dias · D=Mapa Anual · E=Sem programação (acordeão por risco)

**Bloco C — definição canônica:** "Saem nos próximos 30 dias" largura total, countdown "Faltam X dias". Sem "Retornam esta semana" (redundante com Bloco A).

**Bloco D — Mapa Anual modo duplo:**
- Modo panorâmico (SEL===null): grade Jan→Dez, cor única `#185FA5`, apenas `aprovado` + `gozado`
- Modo mensal (SEL!==null): drill-down dia-a-dia via `_ganttRenderContent` + adapter GESTOR→formato-RH. Linhas sem onclick (read-only)
- Navegação de ano: `_gdashMapaAnoNav(delta)`, máximo = ano atual
- Deduplicação por `(inicio, fim)` para evitar duplicatas quando período muda de status

**RH Atividade:** `_rhAtivAbrirModal(feriasId)` abre modal de aprovação para pendentes. `rhRecusarSolicitado` não usa `prompt()` — rota para `abrirModalAprovar`.

Ver seção completa em `.claude/agents/ferias.md`.

---

## Padrão visual global — legibilidade (set/2026)

Aplicado em todos os módulos via tokens CSS e tamanho mínimo de fonte.

**Tokens:** `--text-sec: #4B5565` (6.1:1 contraste) · `--text-ter: #6C7589` (4.6:1, passa WCAG AA)

**Escala mínima:** 11px = mínimo absoluto para texto informativo. 12px+ para dados operacionais. Abaixo de 11px: apenas decorativo/estrutural.

**Escopo:** propagado para todos os módulos (`modulos/cadastro/`, `modulos/admissao/`, `modulos/ferias/`, etc.) via replace global PowerShell. Font sizes 8px/9px/10px em texto informativo substituídos por 11px.

---

## Próximas features planejadas

1. **Validar Etapa 2 (hero da Ficha)** — usuária precisa fazer hard-refresh e confirmar visual (pendência antiga)
4. Etapa 3 da Ficha: reorganizar abas em Visão Geral, Dados Pessoais, Dados Profissionais, Férias, Uniformes, Documentos, Benefícios, Desenvolvimento, Processos, Histórico
5. Separação de perfis no módulo Desenvolvimento
6. Módulo Indicadores (turnover, headcount, absenteísmo)
7. Envio WhatsApp (PainelRH local — link wa.me por colaborador)
8. Etapa 2 frontend empresa_id: Relatórios e Férias (deferred)
9. Etapa 3: FK constraint em empresa_registro_id / empresa_atuacao_id (após validação completa)

---

## Módulo Processos — Reajuste Salarial (out/2026)

Tipo `reajuste` implementado no workflow de processos RH.

**Formulário — 7 campos:**

| ID DOM | Campo | Tipo |
|---|---|---|
| `xSalarioAtual` | Salário atual (readonly) | input — `data-raw` com valor numérico |
| `xSalarioNovo` | Novo salário | input text com máscara monetária |
| `xPercentualReajuste` | Percentual (readonly) | input calculado em tempo real |
| `xMotivoReajuste` | Motivo | select carregado de `param_motivo_reajuste` |
| `xDataVigencia` | Data de vigência | input date |
| `xNovaFuncao` | Nova função | select carregado de `param_cargo?ativo=eq.true&order=nome` |
| `xObservacaoReajuste` | Observação | textarea opcional |

**`dados_extras` salvo:** `salario_novo, data_vigencia, percentual, motivo_codigo, motivo_descricao, nova_funcao, observacao`

**Card Em andamento:** `Novo salário: R$ X.XXX,XX a partir de DD/MM/AAAA · +X,XX% · Motivo`

**Parâmetros:** seção "Movimentações" adicionada em `modulos/parametros/index.html` com CATS entry `motivo_reajuste` (order 1) e `tipo_transferencia` (order 2, commit 81e56c6).

### `param_tipo_transferencia` — padrão snapshot (out/2026)

Tabela criada na Mig 102. Valores: `unidade` ("Transferência de unidade") e `cnpj` ("Alteração de CNPJ/contrato").

**Padrão snapshot obrigatório:** `historico_eventos.dados` armazena sempre `tipo_transferencia` (código) + `tipo_transferencia_label` (label no momento do registro). Assim o histórico é imune a renomeações futuras em `param_tipo_transferencia`. Mesma regra aplicada ao tipo `alteracao_setor` com `setor_anterior_label` / `setor_novo_label`.

**Regra tipo/motivo:** `tipo_transferencia` = o que foi feito (mecanismo). Se futuramente o RH precisar de `motivo_transferencia` (por que foi feito), criar `param_motivo_transferencia` separado — não confundir com o tipo.

### `alteracao_setor` — tipo de evento (out/2026)

Criado na Mig 105-B. Representa mudança de departamento/setor sem transferência de empresa ou promoção de cargo.

Campos: `setor_anterior` (obrigatório), `setor_anterior_label` (snapshot), `setor_novo` (obrigatório), `setor_novo_label` (snapshot).
`resumo_template`: `{setor_anterior_label} → {setor_novo_label}`. `categoria`: carreira. `icone_chave`: briefcase.

**Fonte dos setores:** `param_setor` — já existe com 16 setores e interface no Parâmetros Gerais. Não criar nova tabela.

**Fluxo de processo:** futuro — a ser implementado no módulo Processos como `tipo = 'alteracao_setor'`. Por ora, apenas inserção manual via script Python.

### Colaboradores com múltiplos vínculos — padrão de IDs

5 colaboradores têm dois registros (inativo + ativo) por quebra de vínculo:

| Colaborador | ID inativo | ID ativo | Empresa |
|---|---|---|---|
| Marcilene | 1878 | 1787 | Log |
| Sabrina | 1880 | 1778 | Log |
| Ana Claudia | 1869 | 1752 | Sarandi |
| Maria Luiza | 1874 | 1629 | Matriz |
| Francisco | 1873 | 1688 | CD |

Gisele (mat=345) tem 3 vínculos: id=1871 (2018-11-20→2019-09-30, Atendente), id=1872 (2019-10-01→2022-09-30, Assistente Administrativo), id=1689 (2022-10-01, Assistente de Compras Jr., ativo). Fabricia (id=1972) tem matrícula 345 indevidamente — investigar separado.

**Regra:** evento de promoção/carreira vai no ID do vínculo **vigente na época do evento** (inativo quando a promoção ocorreu na quebra). Reajuste salarial do dissídio vai no ID **ativo**.

### Bug corrigido — `renderHistorico` timeline vazia (out/2026, commit 77ca014)

`_tiposEmEventos` e `_processosEmEventos` eram declarados na linha 559 de `ficha-render.js` mas usados na linha 545 (guard de admissão), causando `ReferenceError` silencioso que impedia toda a timeline de renderizar. Fix: mover as duas declarações para logo após `const eventos = [..._historico]`, antes de qualquer uso.

---

## Ficha do Colaborador — abas Carreira e Financeiro (out/2026)

**Ordem das abas atual:** Resumo · Carreira · Financeiro · Férias · Desenvolvimento · Histórico

**Aba Carreira** (`sec-carreira`, `carreiraContent`): admissão sintética + mudanças de função (reajustes com `dados_extras.nova_funcao`) + transferências — renderizado por `renderCarreira()` em `ficha-render.js`. Sempre tem ao menos o evento de admissão. Fonte: `_processosConcluidos`.

**Aba Financeiro** (`sec-financeiro`, `financeiroContent`): timeline de reajustes salariais com `salario_anterior → salario_novo`, percentual, motivo, data vigência, status (aplicado/pendente). Renderizado por `renderFinanceiro()` em `ficha-render.js`. **Fonte: `_historicoRemuneracao`** (não mais `_processosConcluidos`).

- Status badge `.tl-status.aplicado` (verde) quando `h.aplicado_em` ou `h.data_vigencia <= hoje`
- Status badge `.tl-status.pendente` (âmbar) quando vigência futura ainda não aplicada
- Ponto `.tl-dot.reajuste` (verde) em `ficha.css`

**Globals em `ficha-data.js`:**
- `_processosConcluidos` — carregado em `Promise.all`, usado apenas pela aba Carreira
- `_historicoRemuneracao` — carregado em `Promise.all` com query `historico_remuneracao?colaborador_id=eq.{ID}&order=data_vigencia.desc`, usado pela aba Financeiro

**`_verificarReajustesPendentes(colabId)`** — chamada no `init()` de `ficha-data.js` antes de `renderHero()`. Aplica silenciosamente reajustes com `data_vigencia <= hoje` e `aplicado_em IS NULL` que o cron ainda não processou. Chama `fn_concluir_reajuste` via RPC para cada pendente com `processo_id != null`. Falha silenciosa — cron tentará novamente.

**Proteção dupla para vigência futura:**
- Cron `verificar-workflows-diario` (07h BRT) — automação principal
- `_verificarReajustesPendentes` — lazy load ao abrir qualquer ficha de colaborador

**Arquivo CSS:** `ficha.css` — classes adicionadas:
```css
.tl-status { display:inline-flex; align-items:center; gap:3px; font-size:11px; font-weight:500; padding:1px 6px; border-radius:10px; margin-left:6px; vertical-align:middle }
.tl-status.aplicado { background:var(--green-bg); color:var(--green) }
.tl-status.pendente { background:#fef3c7; color:#92400e }
```

---

## Ficha do Colaborador — historico_eventos: arquitetura unificada (out/2026)

**Modelo:** push-based — cada conclusão de processo grava em `historico_eventos` como fonte canônica da timeline.

### Tabelas novas

**`tipos_evento`** — catálogo parametrizável de tipos de evento:
```
codigo TEXT PK, categoria TEXT, label TEXT, icone_chave TEXT, cor_hex TEXT,
dados_schema JSONB, resumo_template TEXT, detalhe_campos JSONB, ativo BOOLEAN
```
Categorias válidas: `admissao`, `carreira`, `financeiro`, `beneficio`, `cadastro`

**`historico_eventos`** — fonte única da timeline:
```
colaborador_id, tipo, titulo, resumo, dados JSONB, data_evento DATE,
registrado_por TEXT, registrado_por_id UUID, ref_tabela, ref_id, processo_id, origem
```
UNIQUE `(colaborador_id, processo_id)` e partial UNIQUE `uq_evento_ref` em `(colaborador_id, ref_tabela, ref_id) WHERE ref_id IS NOT NULL`.

**`processo_auditoria`** — audit trail interno (não exibido na timeline):
```
processo_id, acao TEXT, detalhe TEXT, usuario TEXT, usuario_id UUID, criado_em
```

### Função helper

**`_validar_dados_evento(tipo, dados)`** — valida JSONB `dados` contra `tipos_evento.dados_schema`. Levanta exceção se campo obrigatório ausente.

### Funções de conclusão implementadas (SECURITY DEFINER)

| Função | Migration | Tipo de processo | Status |
|---|---|---|---|
| `fn_concluir_admissao` | 086 | `admissao` | ✅ executada |
| `fn_concluir_demissao` | 087 | `demissao` | ✅ executada |
| `fn_concluir_reajuste` (v2, fixed) | 076 | `reajuste` | ✅ executada (fix: `salario = v_salario_novo` sem `::TEXT`) |
| `fn_concluir_prorrogacao_experiencia` | 090 | `prorrogacao_experiencia` | ✅ executada |
| `fn_concluir_efetivacao` | 091 | `avaliacao_final_experiencia` | ✅ executada |
| `fn_concluir_transferencia_cnpj` | 092 | `transferencia_cnpj` | ✅ executada |

Todas seguem o padrão: validar processo → verificar idempotência → modo recuperação → concluir normalmente → INSERT em `historico_eventos` → INSERT em `processo_auditoria`.

### Migrations de estrutura e tipos_evento

| Migration | Conteúdo | Status |
|---|---|---|
| 078 | CREATE: `historico_eventos`, `tipos_evento`, `processo_auditoria` | ✅ |
| 079 | `_validar_dados_evento()` helper function | ✅ |
| 080–083 | fn_concluir_reajuste v1 (depois substituída por 076 v2) | ✅ |
| 084 | Correções arquiteturais: constraint categoria, índice `uq_evento_ref` | ✅ |
| 085 | `tipos_evento` para admissao + demissao | ✅ |
| 089 | `tipos_evento` para prorrogacao_experiencia, efetivacao, transferencia | ✅ |
| 094 | `tipos_evento` para bonus_indicacao, vt_alteracao, devolucao_uniforme (C-2) | ✅ |
| 099 | `tipos_evento` para entrega_uniforme (Fase D) | ✅ |
| 102 | CREATE `param_tipo_transferencia` (codigo, label, descricao, ordem, ativo) — 2 valores: unidade, cnpj | ✅ |
| 103 | `fn_concluir_transferencia_cnpj` v2 — busca label de `param_tipo_transferencia` e grava snapshot `tipo_transferencia_label` em dados | ✅ |
| 104 | Documentação: 7 eventos históricos inseridos via REST API (ver 105 para estado correto pós-ajustes) | ✅ |
| 105-A | `modulos/parametros/index.html`: `tipo_transferencia` adicionado ao CATS, seção Movimentações, order 2 | ✅ (commit 81e56c6) |
| 105-B | INSERT `tipos_evento` para `alteracao_setor` — categoria carreira, icone briefcase, 4 campos com snapshot | ✅ (commit 4b9d6f8) |
| 105-C | Ajustes em `historico_eventos`: remove 90/92/94, substitui 91 (alteracao_setor Ana Claudia), cria promoção Gisele id=96 | ✅ (commit 8805919) |
| 106 | Dissídio coletivo 2026: 149 registros em `historico_remuneracao`, 141 salários atualizados, 8 somente histórico (demitidos após 01/08/2026). Inclui 30 casos de piso salarial. Felipe (CD/485) excluído — divergência salarial pendente. Convenção percentual: inteiro (6.0 = 6%). `motivo_codigo='dissidio_coletivo'`, `motivo_descricao='Dissídio coletivo'`, vigência 2026-08-01. | ✅ (commit fa15930) |
| 107 | Mérito e Promoção ago/2026: 15 registros `historico_remuneracao` (ids 422–436) + 6 eventos `promocao` (ids 105–110) para 9 colaboradores. Vigência 2026-08-01. Motivos: `'0.1'`=Mérito, `'0.2'`=Promoção, `'dissidio_coletivo'`=Dissídio (pré-existente Mig 106 para Daniele/Heloisa). Maria Clara: evento inclui `setor_anterior='2148 - CD'`, `setor_novo='148 - Compras'` em `dados` (mudança de setor parte da promoção, sem evento separado). Heloisa: planilha rotulava como Promoção mas tratada como Mérito (`0.1`) — cargo não mudou ("Mesma função"). Idempotência: PATCH em `colaboradores` só executa quando há inserções novas naquela execução. Execução em 2 fases: historico_remuneracao + PATCHs na fase 1; 6 eventos falharam por constraint `origem` ('migracao' → 'sistema'); fase 2 inseriu os eventos. | ✅ (script Python local — sem commit de SQL) |

### Scripts de recuperação (eventos históricos)

| Migration | Conteúdo | Status |
|---|---|---|
| 088 | Recovery: admissão + demissão (fixed: pula `colaborador_id IS NULL`) | ✅ |
| 093 | Recovery: prorrogacao, efetivacao, transferencia (C-1) | ✅ |
| 098 | Recovery: bonus_indicacao, vt_alteracao, devolucao_uniforme (C-2) | ✅ |
| 101 | Recovery: entrega_uniforme — 6 grupos de unif_movimentacoes (Fase D) | ✅ |
| 104 | Recovery: 7 eventos históricos de transferência e promoção (Marcilene, Sabrina, Ana Claudia, Maria Luiza, Francisco) — 3 deles corrigidos/removidos na Mig 105-C | ✅ |

### Estado atual de historico_eventos (out/2026, pós Mig 107)

~64 registros totais (após Mig 107 — +6 promocao):
- `admissao`: 9
- `alteracao_setor`: 1 (Ana Claudia, SDI Adm → Matriz Adm)
- `bonus_indicacao`: 5
- `demissao`: 17
- `devolucao_uniforme`: 1
- `efetivacao`: 2
- `entrega_uniforme`: 6
- `promocao`: 10 (ids 93/95/96 da Mig 104/105 + ids 105–110 da Mig 107: Wilson, Marcos, Felipe R., Gisele, Maria Clara, Edileusa)
- `prorrogacao_experiencia`: 8
- `reajuste_salarial`: 1
- `transferencia`: 2 (Marcilene id=89 + outros)
- `vt_alteracao`: 2

### Regras de design estabelecidas

- **`data_evento`** = data explícita de `dados_extras` quando disponível (ex: `data_transferencia`, `fim_experiencia`) — NUNCA usar `concluido_em` como primária
- **Processos cancelados** → retornam `ok=false` sem criar evento (ex: `avaliacao_final_experiencia` proc 21)
- **`colaborador_id IS NULL`** → sempre pular com contador `v_pulado` — esses são candidatos não vinculados
- **Idempotência**: todas as funções verificam `EXISTS` por `processo_id` antes de agir; retornam `ok=true + aviso` se já registrado
- **Modo recuperação**: processo já `concluido` mas sem evento → reconstruir a partir de `dados_extras`

### Frontend (ficha-data.js + ficha-render.js)

- **`_tiposEvento` global** em `ficha-data.js` — carregado no `Promise.all` do `init()`
- **`ficha-render.js`**: lookup dinâmico de ícone/cor via `_tiposEvento` (sem hardcode de tipo→ícone)
- **ICONS dict** em `ficha-render.js`: novo ícone `'clock'` adicionado (entre `'bus'` e `'circle'`) para `prorrogacao_experiencia`
- Guards de síntese: `_tiposEmEventos` Set para checagem de presença por tipo

### Fase C-2 — concluída (out/2026)

Tipos implementados: `bonus_indicacao`, `vt_alteracao`, `devolucao_uniforme`

- Migrations executadas: 094 (tipos_evento), 095 (fn_concluir_bonus_indicacao), 096 (fn_concluir_vt_alteracao), 097 (fn_concluir_devolucao_uniforme), 098 (recovery)
- `vt_alteracao`: 4 de 6 processos têm `colaborador_id IS NULL` — corretos, pulados nas funções
- Recovery 098 criou 5 eventos; 3 criados durante validação (procs 23, 38, 13); total: 8 eventos C-2

### Fase D — concluída (out/2026)

Entrega de uniformes integrada a `historico_eventos` via `unif_movimentacoes`.

**Arquitetura:**
- Unidade de evento: `(colaborador_id + data_movimentacao + motivo)` → 1 evento, itens agregados em `dados.itens[]`
- Sem `processo_id` — movimentações não passam pelo workflow de processos_rh
- Idempotência: `EXISTS` por `(colaborador_id, tipo, data_evento, dados->>'motivo')`
- Ícone `shirt` adicionado ao mapa `ICONS` em `modulos/colaborador/ficha-render.js`

**Migrations executadas:**
- 099: `tipos_evento` para `entrega_uniforme` (categoria `cadastro`, cor `#026AA2`, icone `shirt`)
- 100: `fn_registrar_entrega_uniforme(colab_id, data, motivo, usuario)` — função genérica paramétrica
- 101: Recovery — 6 grupos de `unif_movimentacoes` → 5 eventos criados, 1 pulado (já existia)

**EPI:** não existe ainda no catálogo (`unif_catalogo` tem todos `tipo='uniforme'`). Quando EPI for cadastrado (`tipo='epi'`), usar a mesma função com `p_tipo_item='epi'` e adicionar `tipos_evento 'entrega_epi'` — sem alteração de schema.

---

## Módulo Uniformes — bugs corrigidos (out/2026)

### Bug "Registrar kit" — constraint origem (08/10/2026, migration 110 + commit b16fd69)

**Sintoma:** clicar em "Registrar kit" retornava toast genérico "Erro ao salvar. Verifique os campos e tente novamente."

**Causa raiz:** `fn_registrar_movimentacao_uniforme` (migration 108-C) passava `origem = 'uniforme'` no INSERT de `historico_eventos`, violando o CHECK constraint `historico_eventos_origem_check` que aceita apenas `'sistema'`, `'legado'`, `'manual'`.

**Fixes aplicados:**
1. **Migration 110** (`migrations/110_fix_fn_registrar_movimentacao_uniforme_origem.sql`): substituiu `'uniforme'` por `'sistema'` na linha do INSERT. Nenhuma outra lógica alterada. Executada no Supabase em 08/10/2026.
2. **Commit `b16fd69`** — `modulos/uniformes/index.html`:
   - `salvarEntregaKit` linha 3290: `res.ok === false` agora usa `toast()` + `return` diretamente (antes lançava `Error` que `_erroApi` não conseguia parsear, gerando mensagem genérica)
   - `_erroApi`: adicionado `if (msg) return msg;` antes do fallback — erros com código desconhecido (`P0001`, etc.) agora exibem a mensagem real do Supabase
   - `catch` de `salvarEntregaKit`: adicionado `console.error('[salvarEntregaKit]', e)` para diagnóstico

**Impacto:** zero. `origem` é metadado de rastreabilidade; a identificação do evento como uniforme permanece pelos campos `tipo = 'entrega_uniforme'` e `ref_tabela = 'unif_movimentacoes'`, que não foram alterados.

**Validação pós-fix:** query no Supabase confirmou `origem = 'sistema'` nos eventos de `entrega_uniforme` mais recentes (ids 80, 111, 112). Eventos anteriores intactos.

---

## Módulo Uniformes — bug corrigido (out/2026, commit 10cd2cb)

**Campo Nome oculto no modal "+ Novo item" da aba EPIs.**

`abrirModalItem()` pré-define `iTipo='epi'` quando `_catalogoSecTab === 'epis'`, depois chama `toggleCampoCA()`. Essa função usava `generoToggle.parentElement` para esconder o bloco de Gênero — mas o `parentElement` era o container de **toda** a seção Identificação (Nome, Tipo, CA, Unidade), ocultando tudo.

**Fix:** `<div id="campoGenero">` envolve apenas o bloco de Gênero no HTML. `toggleCampoCA` referencia `#campoGenero` diretamente.

---

## Módulo Processos — Reajuste Salarial — automação completa (out/2026)

### Fluxo end-to-end

1. RH cria processo `reajuste` com 7 campos (salário novo, data vigência, motivo, nova função, observação)
2. Checklist: 3 itens — Aprovação do gestor · Comunicar ao colaborador · Atualizar folha
3. RH conclui checklist e clica "Concluir processo"
4. `_executarConclusao` detecta `tipo === 'reajuste'` → chama `fn_concluir_reajuste` via POST RPC
5. Função atômica: marca processo concluído + insere em `historico_remuneracao` + (se vigente) atualiza `colaboradores.salario/cargo` + 2 eventos em `colaboradores.historico`
6. Aba Financeiro da Ficha reflete imediatamente o novo registro

### Checklist — prazos removidos (out/2026)

Todos os tipos exceto `demissao` tiveram `prazo_dias` removido dos itens de checklist. Fix de bug: `prazo_dias ?? null` (era `?? 0`) ao salvar no banco.

### Migrations relacionadas

| Migration | Arquivo | Status |
|---|---|---|
| 075 | `migrations/075_historico_remuneracao.sql` | ✅ executada |
| 076 | `migrations/076_fn_concluir_reajuste.sql` | ✅ executada (com fix manual: `salario = v_salario_novo` sem `::TEXT`) |
| 077 | `migrations/077_migrar_historico_salarial.sql` | ✅ executada (0 linhas — campo estava vazio) |

### Convenção `percentual` em `historico_remuneracao` (definida out/2026)

**Inteiro percentual:** `6.0` = 6%. Nunca `0.06`. A tela (`ficha-render.js`) usa `pctNum.toFixed(2)` diretamente sem multiplicar por 100.

Se a fonte armazenar como decimal, multiplicar por 100 antes de inserir.

### Pendências abertas

- `colaboradores.salario` no Cadastro deveria ser readonly (exibir valor de `historico_remuneracao`) com mecanismo de correção admin — arquitetado, não implementado
- Edge Function `verificar-workflows` não foi atualizada para aplicar reajustes pendentes — apenas o lazy load da Ficha faz isso hoje
- Parâmetros Gerais: corrigir label `dissidio_coletivo` de "Reajuste integral" → **"Dissídio coletivo"** (pendente — fazer no sistema)
- Mig E-bis: Felipe Gonçalves (CD/485, id=1711) — sal. banco R$ 1.024,69 ≠ planilha R$ 2.163,00 — investigar origem antes de lançar dissídio
- **MIG 107 concluída (2026-10-07):** Mérito e Promoção ago/2026 — sem pendências abertas

---

## Módulo Férias — pendências arquiteturais (registradas 2026-10-09)

### Incidente resolvido: PA duplicado Victor Hugo (mat.402)

**Causa:** `processGestorFerias` sem ordenação determinística antes do dedup loop escolhia o registro 1893 (`Alteracao_Solicitada`, sem lançamentos) como survivor em vez do 1891 (`Aprovado`, com lançamentos e realizacoes).

**Correção aplicada:**
1. **Commit 3c89065** — ordenação determinística em `processGestorFerias` (prioridade: status > tem lançamentos > id menor)
2. **PATCH banco (2026-10-09)** — `ferias WHERE id=1893 SET status='Descartado'` — resolveu duplicidade visual no drawer RH

**Estado do banco:**
- 1891: Aprovado, p2: 12/10/2026, realizacoes com gozo parcial — registro ativo
- 1893: Descartado, dados preservados (obs_gestor com intenção original da solicitação)
- 1895: Aprovado, PA 2027, criado por autocriarPasFaltantes — legítimo

### Pendências abertas

1. **`_rhEhRecente` — entrada órfã (prioritária):** `ferias_historico` id=12 (ferias_id=1893, acao='alteracao_solicitada') aponta para registro Descartado. `_rhEhRecente` retorna `true` → item aparece em "Atividade recente" com botão "Analisar" quebrado. Correção: adicionar guard `_feriasExiste` em `_rhEhRecente` (ver skill ferias.md). Aprovada conceitualmente — aguardando autorização de implementação.
2. **Nova solicitação do Victor Hugo (em andamento):** Gestor deve refazer a alteração do período 2 de 12/10 para 13/10 no drawer (sobre 1891). Etapa 1 autorizada, aguardando ação do Gestor. Após confirmação, verificar banco e então autorizar Etapa 2 (aprovação RH).
3. **`lancIdx` heurístico** em `_gestorColabsComAcordoAndamento`: `l.id.endsWith('-p2') ? 1 : 0` — pode causar subdetecção de acordos em edge cases. Correção estrutural pendente (não urgente).
4. **Proteção contra PAs duplicados** em `rhCriarNovoPa` e `autocriarPasFaltantes` — avaliar guard antes de criar novo PA.
5. **Dedup em `supabaseParaModelo`** — avaliar proteção arquitetural para tornar a visão RH resiliente a duplicatas residuais no banco; avaliar impacto abrangente antes de implementar.
6. **KPI "PDI ativos" na Trajetória** — mostra `—` para todos os perfis (pré-existente, não regressão). Implementação pendente: query a `pdi_planos` com `status=ativo`, cruzada com matrículas da equipe do gestor (`_trGestorApelido`). RH vê todos os planos ativos da empresa. Tratar em escopo separado após validação dos ajustes de 28/10/2026.
