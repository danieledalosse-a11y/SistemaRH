---
name: ferias-dashboard-visual
description: "Design visual aprovado do Dashboard de Férias: dois cards lado a lado, calendário com bolinhas por setor, painel Ausentes por Setor com ícones circulares"
metadata:
  node_type: memory
  type: project
  originSessionId: 8172e317-1917-45cd-9732-a1d412d45df8
  modified: 2026-09-16T13:05:16.521Z
---

## Dashboard Férias — Design Visual (sessão 2026-09-15)

### Layout aprovado: dois cards lado a lado (50/50)

```html
<div style="display:flex;gap:16px;margin-bottom:10px;align-items:stretch">
  <div class="an-card" style="flex:0 0 calc(50% - 8px);width:calc(50% - 8px);overflow:hidden">
    <!-- Calendário de férias -->
  </div>
  <div class="an-card" style="flex:0 0 calc(50% - 8px);width:calc(50% - 8px);overflow:hidden">
    <!-- Ausentes por setor -->
  </div>
</div>
```

**Por que `calc(50% - 8px)`:** `flex:1` não funcionou porque o grid do calendário (7 colunas) tem largura intrínseca mínima maior que o painel de setores. Solução: largura explícita com metade do container menos metade do gap.

**`align-items:stretch`** no container para os dois cards terem a mesma altura.

### Calendário — células com intensidade de azul + bolinhas por setor

- Fundo da célula: escala muito clara de azul proporcional ao número de ausentes
  - `n >= 10` → `#DBEAFE`
  - `n >= 6`  → `#EFF6FF`
  - `n >= 3`  → `#F5FAFF`
  - `n >= 1`  → `#FAFCFF` (quase branco — para os dots permanecerem visíveis)
- Uma bolinha por setor único presente naquele dia (cor: `corDoSetor(s).borda`)
- Máximo 4 bolinhas + "+N" para excedente
- **Sem legenda de categorias** — removida porque não há como distinguir coletivas de normais pelo campo `status`

### Ausentes por setor — ícones circulares com iniciais

Cada linha do painel usa:
- Ícone circular 32×32px com iniciais do setor (máx 2 letras), fundo e borda de `corDoSetor(s)`
- Barra horizontal com cor do setor
- Contagem de colaboradores únicos ausentes
- Percentual sobre total do mês

### `SETOR_COR_FIXA` — 19 entradas (5 adicionadas nesta sessão)

Novos setores adicionados: `CD` (atenção: chave deve ser maiúscula — corrigido 2026-09-16), `Ecommerce`, `Sarandi`, `Paranavaí`, `Matriz`.
Tabela completa documentada na skill `ferias.md` (seção "Dashboard — Design Visual").

**Why:** setores que apareciam no painel sem cor mapeada recebiam cores do ciclo genérico, quebrando o padrão visual.

**How to apply:** ao adicionar novos setores que apareçam sem cor, adicionar entrada em `SETOR_COR_FIXA` antes de `SETOR_CORES_CICLO`. Ver tabela completa na skill.
