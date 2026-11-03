---
name: feedback-dp-arquitetura-generica
description: Diretriz arquitetural permanente do motor D&P — parametrizável e genérico, nunca orientado ao caso atual
metadata:
  node_type: memory
  type: feedback
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-09-30T13:37:55.064Z
---

Antes de implementar qualquer etapa do D&P, fazer internamente esta pergunta:
"Estou criando uma solução parametrizável e reutilizável para diferentes modelos, ou estou criando uma regra para fazer o caso atual funcionar?"
Se for a segunda opção, parar e ajustar a abordagem antes de implementar.

**Why:** O CD é apenas o primeiro modelo real de validação do motor. O motor deve ser genérico — suportar Sim/Não, escalas, pesos, conceitos, com ou sem conversão financeira, sem nenhuma regra espalhada no código que seja específica a um setor, cargo ou modelo.

**How to apply:**
- Nenhuma string como "CD", "Gratificação", nome de setor ou cargo deve aparecer como condição no código.
- Configurações de negócio ficam em tabelas param_* ou dp_* — nunca hardcoded.
- Reutilizar sempre o que já existe no sistema (param_setor, param_gestor, colaboradores.gestor) em vez de criar estruturas paralelas.
- Usar param_setor como fonte canônica de setores — o D&P já extrai a parte após " - " para exibição e busca.
- Não interromper cada etapa para resolver situações que já deveriam estar contempladas pela arquitetura genérica. Se surgir lacuna arquitetural real, sinalizar objetivamente com impacto + solução proposta. Se for só parametrização/cadastro, resolver com a estrutura existente.
- Não fazer análises extensas sobre decisões já tomadas.

**Requisitos arquiteturais estabelecidos:**
- RH cria e configura modelos sem alterar código
- Avaliações podem ser mensais, trimestrais ou em outros períodos
- Modelos com Sim/Não, escalas numéricas, pesos, conceitos, critérios variados
- Conversão financeira é opcional por modelo
- Gestores vinculados às equipes de forma segura e reutilizável (colaboradores.gestor)
- Snapshot/histórico dos ciclos obrigatório
- Visões RH/Gestor/Diretoria usam mesma estrutura, mudam apenas escopo e permissão
- Relatórios nascem da estrutura genérica
- Complexidade no motor, simplicidade para o RH operar
