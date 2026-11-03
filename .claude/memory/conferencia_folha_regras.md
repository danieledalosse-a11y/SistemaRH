---
name: conferencia-folha-regras
description: "Onde está a skill oficial de conferência mensal de folha de pagamento (regras, fontes de dados e formato de relatório)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 51652317-ceea-4334-81fb-794ecf6485fa
  modified: 2026-09-02T12:01:59.505Z
---

Toda a lógica da conferência mensal de folha de pagamento (fontes de dados por item, regras de negócio,
armadilhas de extração de PDF já descobertas, princípio de validação bidirecional e formato exato do
relatório final) está consolidada em arquivos normais (não skill instalada — ver [[feedback_skill_storage_ephemera]]
pro motivo) na pasta de trabalho da própria Dani:

```
C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\4.0-FOLHA DE PAGAMENTO\CLAUDE\conferencia-folha-pagamento\SKILL.md
C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\4.0-FOLHA DE PAGAMENTO\CLAUDE\conferencia-folha-pagamento\references\fontes-de-dados.md
```

Sempre que a Dani pedir uma conferência de folha (ou qualquer item que essas regras cobrem), ler esses dois
arquivos direto com a ferramenta Read antes de agir — eles não carregam sozinhos como uma skill normal
carregaria, precisa buscar manualmente. Não duplicar esse conteúdo aqui na memória — se surgir uma regra
nova ou uma correção durante uma conferência futura, atualizar esses dois arquivos diretamente (Edit/Write),
não criar uma memória nova em paralelo (fica desatualizado e gera confusão sobre qual é a fonte da verdade).
