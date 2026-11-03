---
name: feedback-arquitetura-modular
description: "Regra permanente de arquitetura para o SistemaRH — separação por visão, reutilização, sem duplicação"
metadata:
  node_type: memory
  type: feedback
  modified: 2026-09-24T10:57:34.117Z
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
---

Antes de criar qualquer função, componente, cálculo ou renderer, verificar se já existe algo equivalente. Reutilizar e adaptar; nunca criar cópia paralela.

**Why:** O sistema está crescendo e cada duplicação aumenta risco de efeito colateral — corrigir em uma visão e esquecer a cópia em outra, ou regras de negócio divergentes para o mesmo conceito sem justificativa real.

**How to apply:**

1. **Código específico de visão**: quando pertence somente a RH, Gestor ou Diretoria, identificar e isolar naquele contexto.
2. **Código compartilhado**: quando mais de um perfil usa a mesma funcionalidade, uma única implementação — cada perfil define apenas escopo, permissões, filtros ou dados visíveis.
3. **Regras de negócio**: cálculos que representam o mesmo conceito ficam centralizados e são reutilizados — nunca reescritos em vários lugares.
4. **Componentes visuais**: tabela, timeline, calendário, badge, modal que muda só contexto/dados → reutilizar, não criar segunda versão.
5. **Fluxo obrigatório antes de alterar**: localizar → entender → reutilizar → alterar uma única fonte → testar os perfis afetados.
6. **Duplicações existentes**: sinalizar antes de refatorar. Prioridade é manter o que funciona e evitar novas duplicações — não sair refatorando tudo de uma vez.
7. **Alteração em componente compartilhado**: nunca corrigir criando cópia paralela. A correção vai para a fonte única.

Regra estabelecida em set/2026, aplica a todo o SistemaRH daqui em diante.
