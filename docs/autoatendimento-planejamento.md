# PROMPT — EVOLUÇÃO DO SISTEMA RH
## Implantação do Módulo de Autoatendimento do Colaborador

> **Documento original:** `Prompt_Evolucao_Autoatendimento_RH.docx`
> **Arquivo do módulo:** `modulos/autoatendimento/index.html`
> **Skill de referência:** `.claude/agents/autoatendimento.md`

---

## OBJETIVO

Evoluir o sistema de RH criando o módulo **AUTOATENDIMENTO DO COLABORADOR / MEU RH**.

Este trabalho deve ser tratado como uma **evolução do sistema existente**, e não como uma reconstrução ou criação de um novo sistema paralelo.

---

## 1. O QUE JÁ EXISTE E NÃO DEVE SER RECRIADO

- **Visão RH** — já implementada e funcionando.
- **Visão Gestor** — já implementada e funcionando.
- **Solicitação de férias pelo Gestor** — já implementada. Fluxo: Gestor → solicita → RH recebe → aprova. Deve permanecer como está.
- **Workflow** — motor central de processos e tarefas já funciona. Exemplos: contrato de experiência, demissão. O Workflow deve continuar sendo o motor central.
- **Parâmetros Gerais** — estrutura de permissões já existe. Não criar estrutura paralela.

---

## 2. O QUE ESTÁ SENDO CRIADO

**Módulo de Autoatendimento do Colaborador** — permite ao colaborador:

- Consultar suas informações
- Consultar documentos
- Consultar férias
- Solicitar benefícios (VT, uniforme, crachá)
- Solicitar alterações cadastrais
- Acompanhar suas solicitações
- Receber comunicados e documentos
- Acompanhar processos que dizem respeito a ele

Objetivo: reduzir tarefas operacionais do RH e dar mais autonomia ao colaborador.

---

## 3. CONCEITO DE ACESSO

| Perfil | Acesso |
|---|---|
| Colaborador | Somente seus próprios dados e processos |
| Gestor | Visão Gestor existente + Meu RH (se for também colaborador) |
| RH | Visão RH existente |

**GESTOR = MEU RH + GESTÃO DA EQUIPE**

---

## 4. ESTRUTURA DO MEU RH — Áreas planejadas

### 4.1 Início / Dashboard pessoal
- Próximas férias
- Saldo de férias
- Solicitações pendentes
- Documentos recentes
- Próximos compromissos
- Avisos
- Atalhos para solicitações (Solicitar VT, Solicitar uniforme, Solicitar crachá, Alterar endereço, Consultar férias)

### 4.2 Meu Perfil
**Dados profissionais:** nome, matrícula, cargo, setor, empresa, gestor, data de admissão
**Dados pessoais:** CPF, RG, data de nascimento, estado civil, telefone, e-mail, endereço
**Dependentes:** consulta (quando aplicável)
**Documentos:** documentos disponibilizados pelo RH

### 4.3 Alteração de Dados
Colaborador não altera diretamente — cria solicitação. Exemplo (endereço):
```
Colaborador → preenche novo dado + anexo → envia
→ sistema cria solicitação → Workflow cria tarefa
→ RH analisa → aprova/devolve → cadastro atualizado
```
Registrar: quem solicitou, quando, quem analisou, quando, dado anterior, dado novo, status, obs, anexos.

### 4.4 Minhas Férias *(leitura — sem solicitação por enquanto)*
> O processo atual (Gestor solicita → RH aprova) deve continuar. Não criar solicitação de férias pelo colaborador neste momento.

Exibir:
- **Períodos aquisitivos:** período, início, fim, vencimento, saldo, dias utilizados, situação
- **Férias já realizadas:** período, dias, início, fim, situação
- **Férias programadas:** período, dias, início, fim, situação

Usar as mesmas regras e cálculos já existentes. Não criar segunda lógica de saldo.

### 4.5 Vale-Transporte
- Solicitar VT
- Cancelar VT
- Solicitar alteração
- Consultar situação atual

**Fluxo:** Colaborador solicita → sistema registra → Workflow cria tarefa para RH → RH analisa → conclui.

### 4.6 Uniforme
**Motivos:** primeiro uniforme, não serve mais, desgaste, dano, outro.

**Campos:** peça, tamanho, quantidade, motivo, observação, foto (quando aplicável).

**Fluxo:** solicitação → processo para o responsável. Avaliar integração com controle de estoque existente. Se peça anterior for reutilizável, avaliar tarefa de recebimento/conferência/retorno ao estoque (igual ao processo de desligamento).

### 4.7 Crachá
**Motivos:** perda, roubo, danificado, desgastado, alteração de informação, primeiro crachá, outro.

**Registrar:** data da solicitação, motivo, responsável, data de entrega, status, número/id do crachá, histórico.

**Fluxo:** Colaborador solicita → Workflow → responsável → providencia → conclui.

### 4.8 Exame Periódico
Sistema identifica proximidade do exame → cria tarefa para RH → RH agenda → informa data/local/horário + anexa guia → colaborador recebe notificação.

**No Meu RH:** "Seu exame está agendado. Data: XX/XX Horário: XX:XX Local: XXXXX [Ver guia]"

Avaliar confirmação de ciência pelo colaborador. Não presumir que resultado do exame deve ser disponibilizado (respeitar privacidade).

### 4.9 Minhas Solicitações (Central de Solicitações)
Lista: VT — Em análise / Uniforme — Aprovada / Crachá — Concluída

Ao abrir: histórico da solicitação com datas de cada etapa.

---

## 5. INTEGRAÇÃO COM O WORKFLOW EXISTENTE

**Não criar Workflow novo.** O Autoatendimento usa o Workflow existente como motor.

```
Autoatendimento → colaborador solicita → cria solicitação
→ Workflow existente → cria tarefa
→ RH/responsável → analisa/executa → conclui
→ colaborador é notificado
```

**Origem das tarefas (a adicionar no Workflow):**
- Automático | RH | Gestor | **Colaborador** ← nova origem

**Tipos de processo (novos):**
- Vale-Transporte, Uniforme, Crachá, Exame Periódico, Alteração Cadastral

**Filtros no Workflow (avaliar):** Todos | Minhas tarefas | Automáticos | RH | Gestores | Colaboradores

---

## 6. PARAMETRIZAÇÃO

### Parâmetros Gerais (integrar, não criar nova tela)

Novos parâmetros de acesso do colaborador:
- visualizar Meu Perfil
- visualizar Férias
- visualizar Documentos
- solicitar Vale-Transporte
- solicitar Uniforme
- solicitar Crachá
- solicitar Alteração de Dados
- consultar Solicitações
- visualizar Exame Periódico

### Responsáveis por tipo de solicitação (parametrizável)
- Uniforme → responsável definido
- Crachá → responsável definido
- Vale-Transporte → RH/DP
- Alteração cadastral → RH
- Exame periódico → RH

Não fixar nomes de usuários/responsáveis no código.

---

## 7. STATUS PADRONIZADOS

Reutilizar os existentes. Novos se necessário:
`pendente` | `em análise` | `aguardando informação` | `aprovado` | `recusado` | `em execução` | `concluído` | `cancelado`

---

## 8. NOTIFICAÇÕES

**Para o colaborador:** solicitação aprovada, exame agendado, alteração concluída, solicitação concluída.
**Para o RH:** nova solicitação de VT, crachá, uniforme.
**Para responsável:** nova solicitação aguardando atendimento.

Priorizar notificações dentro do próprio sistema inicialmente.

---

## 9. DOCUMENTOS

Consulta de: holerites, informes, documentos admissionais, guias, encaminhamentos, documentos de processos. Não duplicar armazenamento — reutilizar estrutura existente.

---

## 10. AUDITORIA

Toda solicitação deve responder: Quem solicitou? Quando? Quem recebeu? Quem aprovou? O que foi feito? Quando foi concluído?

Registrar: solicitante, data, hora, responsável, alteração, aprovação, conclusão, observação, anexos, histórico.

---

## 11. RESPONSIVIDADE

O Autoatendimento deve ser pensado principalmente para **celular**:
- layout mobile first
- botões adequados ao toque
- upload de fotos/docs pelo celular
- formulários simples
- confirmação quando necessária

---

## 12. ARQUITETURA — ECOSSISTEMA ÚNICO

```
SISTEMA RH
├── MEU RH
│   └── Colaborador
├── GESTOR
│   └── Minha Equipe
├── RH
│   └── Administração
└── WORKFLOW CENTRAL
    ├── Processos Automáticos
    ├── Processos RH
    ├── Processos Gestor
    └── Solicitações Colaborador
```

---

## 13. ANÁLISE OBRIGATÓRIA ANTES DO CÓDIGO

Antes de implementar qualquer nova fase, apresentar:

1. O que já existe
2. O que pode ser reutilizado
3. O que precisa ser adaptado
4. O que realmente precisa ser criado
5. O que não deve ser criado porque já existe
6. Como o Autoatendimento se conecta ao Workflow
7. Quais novos parâmetros serão necessários em Parâmetros Gerais
8. Quais novas tabelas/campos são realmente necessários
9. Quais APIs/serviços existentes podem ser reutilizados
10. Qual será o fluxo completo de cada nova solicitação

---

## 14. NÃO ALTERAR SEM NECESSIDADE

Especialmente: férias, saldo de férias, períodos aquisitivos, Workflow, tarefas automáticas, checklist de desligamento, experiência, permissões, visão RH, visão Gestor.

Se alguma alteração for necessária para integração, explicar primeiro: por que, o que, e qual o impacto.

---

## PRINCÍPIO FINAL

> NÃO RECONSTRUIR. NÃO DUPLICAR. NÃO SUBSTITUIR REGRAS QUE JÁ FUNCIONAM. **EVOLUIR E INTEGRAR.**

---

## STATUS POR FASE

| Fase | Escopo | Status |
|---|---|---|
| 1 | RLS + autenticação + Hero + Meu Perfil (Resumo) + Minhas Férias (leitura) | ✅ Concluída |
| 1 — Validação | Teste com JWT real do colaborador (ANA) antes de liberar em produção | ⏳ Pendente |
| 2 | Vale-Transporte (solicitar/cancelar/alterar) integrado ao Workflow | 🔲 Próxima |
| 3 | Uniforme (solicitação + integração estoque) | 🔲 Planejada |
| 4 | Crachá | 🔲 Planejada |
| 5 | Alteração de Dados cadastrais | 🔲 Planejada |
| 6 | Central de Solicitações (Minhas Solicitações) | 🔲 Planejada |
| 7 | Exame Periódico | 🔲 Planejada |
| 8 | Dashboard pessoal completo | 🔲 Planejada |
| 9 | Documentos (holerites, informes) | 🔲 Planejada |
| 10 | Notificações in-app | 🔲 Planejada |
| 11 | Responsividade mobile completa | 🔲 Planejada |

---

## PONTOS REFINADOS NA IMPLEMENTAÇÃO

> Decisões tomadas durante as sessões de desenvolvimento — complementam o documento original.

### Fase 1 — O que foi implementado

- RLS com whitelist de perfis (`auth_perfil() IN ('admin','rh','gestor','diretoria','logistica')`)
- Funções `auth_perfil()` e `auth_colaborador_id()` como SECURITY DEFINER no Supabase
- `usuarios_perfil.user_id` é UUID — nunca usar `auth.uid()::text`
- Policy `anon_all` mantida (sistema RH usa chave publicável em outros fluxos — não remover)
- Hero com foto/avatar, chips de empresa, matrícula, situação ativo/inativo
- Aba Resumo: KPIs (tempo de casa + saldo de férias) + info-grids (dados pessoais e profissionais)
- Aba Minhas Férias: todos os PAs com lançamentos, saldo, status (passado/futuro/em andamento)
- Migration: `migrations/048_rls_autoatendimento_fase1.sql`

### Fase 1 — Validação pendente antes de liberar para usuários reais

1. Login como **ANA** → confirmar redirecionamento automático para `/modulos/autoatendimento/`
2. Verificar via DevTools (Network) que `/rest/v1/colaboradores` e `/rest/v1/ferias` retornam **apenas os registros dela**
3. Confirmar que o RH não foi afetado (regressão nos demais módulos)

### Minhas Férias — decisão de escopo (refinamento do item 7 do documento)

O documento diz "não criar solicitação de férias pelo colaborador neste momento". Confirmado — a aba Minhas Férias na Fase 1 é **somente leitura**. Os cálculos de saldo reutilizam exatamente a mesma lógica do módulo Férias (sem duplicação).

### Vale-Transporte — Fase 2 (próxima)

Antes de iniciar: realizar a validação completa da Fase 1. O fluxo VT usará o Workflow existente como origem `colaborador`, sem criar motor de aprovação novo.
