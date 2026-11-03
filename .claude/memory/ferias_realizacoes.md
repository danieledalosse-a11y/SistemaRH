---
name: ferias-realizacoes
description: "Aba \"Acordos\" no drawer do módulo Férias (era Realizações) — controla gozo real vs. período oficial"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-07-30T20:07:02.963Z
---

## Feature: Realizações de Férias (gozo real vs. período oficial)

**Por que:** acordos informais entre gestor e colaborador fazem o período real sair diferente do homologado. Hoje isso fica perdido em observações sem controle de saldo.

**Fluxo aprovado:**

1. **Gestor** agenda o período oficial (o que vai para o papel). Ex: 16 dias.
2. **Gestor** registra no campo Observações o acordo real. Ex: "Colaborador sairá 14 dias. 2 dias para uso posterior."
3. **RH** registra as realizações efetivas — uma lista de utilizações parciais.

### Estrutura de dados a adicionar (tabela `ferias` no Supabase)

```
realizacoes: [
  { data_saida: '2025-08-01', data_retorno: '2025-08-14', dias: 14, criado_em: ... },
  { data_saida: '2025-10-10', data_retorno: '2025-10-11', dias:  2, criado_em: ... },
]
```

Ou como coluna JSONB `realizacoes` na tabela `ferias`.

### UI no drawer de RH

- Seção "Realizações" abaixo do período oficial
- Lista de linhas: data saída | data retorno | dias | [remover]
- Botão "+ Adicionar utilização" → campos inline
- Cálculo automático: saldo = dias_oficiais − soma(dias realizações)
- Badge de saldo: verde (zerado), âmbar (parcial), vermelho (excedido)

### Cálculo

```
saldo_restante = reg.lancamentos[0].dias − sum(realizacoes.map(r => r.dias))
```

### Como implementar

**Why:** manter separação clara entre documento legal e realidade operacional  
**How to apply:** adicionar no drawer existente (`abrirDrawer` em `modulos/ferias/index.html`), uma seção após os lançamentos aprovados. Persistir via `sbPatch('ferias', 'id=eq.'+reg._sbId, { realizacoes: [...] })`.
