---
name: prompt-master-state
description: "Estado do app Prompt Master: stack, deploy Vercel, funcionalidades, pendencias, correcoes recentes"
metadata:
  node_type: memory
  type: project
  originSessionId: c2c9fa93-bdd1-47fe-bae3-0fef52960cf6
  modified: 2026-09-05T14:32:51.887Z
---

## Prompt Master — Estado atual (2026-09-05)

App PWA (Next.js 16.3.3 + Tailwind v4 + Supabase + HuggingFace) para vendedores e clientes da Revest simularem ambientes com IA.

### Funcionalidades implementadas
- Login (Supabase Auth)
- Simulacao: foto via camera, galeria do dispositivo, ou galeria pre-cadastrada (27 fotos, 6 categorias)
- Selecao de superficie (piso/parede/ambos)
- Selecao de produtos unificada (quando "Ambos", mostra dois slots: Piso + Parede com indicadores visuais)
- **ProductSearchModal** — modal full-screen com titulo dinamico, busca web em 5.500+ produtos
- **Tela de resultado com edicao inline (2026-09-05):**
  - Imagem gerada no topo com badge DEMO/Simulacao
  - Card "Produtos utilizados" com miniatura, nome, marca, dimensoes e botao "Trocar" por produto
  - Secao Complementos com chips removiveis e botao "Adicionar"
  - "Gerar com alteracoes" aparece so quando algo foi trocado (compara estado atual vs snapshot da geracao)
  - "Compartilhar" (Web Share API com arquivo) e "Nova simulacao" na base
  - Botoes "Gerar novamente" e "Complementar ambiente" foram REMOVIDOS (funcoes integradas na edicao inline)
- **Paginacao tecnica** — canvas profissional com textura do produto, cotas dimensionais, hachura
- Planta baixa (upload croqui + visualizacao)
- Historico de simulacoes
- Cor primaria: **amarelo Revest #FFD100** (texto escuro sobre fundo amarelo)

### Correcoes aplicadas nesta sessao (2026-09-01 a 2026-09-05)
- **Vercel deploy bloqueado**: commit author nao correspondia ao owner do projeto Hobby. Corrigido via git filter-branch reescrevendo todos os commits com email `308502737+danieledalosse-a11y@users.noreply.github.com`
- **"Erro ao criar simulacao"**: 3 causas corrigidas:
  - `product_id` era UUID com FK mas codigo passava string "catalog" → FK removida, coluna text nullable, codigo passa null
  - Enum `surface_type` faltava valor `BOTH` → adicionado via ALTER TYPE
  - AI provider falha (mask vazia, HuggingFace free tier) → fallback para modo DEMO (salva foto original como resultado)
- **Layout busca desktop**: ProductSearchModal era full-width → adicionado `max-w-lg mx-auto` container
- **Sem opcao galeria no celular**: `capture="environment"` forcava camera → separado em 3 botoes (camera, galeria dispositivo, galeria app)
- **Produto parede auto-selecionado**: `handleModalSelect` copiava piso para parede → removido `setWallProduct(product)` do path de floor
- **Botao Voltar ausente**: removida condicao `step !== "result"` do header
- **Compartilhar**: agora envia arquivo de imagem real via Web Share API (mobile) ou download (desktop)

### Deploy
- **Producao:** https://prompt-master-delta.vercel.app
- **Deploy automatico** via push no GitHub (master → Vercel)
- Repo: github.com/danieledalosse-a11y/prompt-master
- Git author configurado: `308502737+danieledalosse-a11y@users.noreply.github.com` (obrigatorio para Hobby plan)
- Env vars na Vercel: NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_ANON_KEY, HUGGINGFACE_API_TOKEN

### Navegacao
- 4 tabs: Simular, Planta, Calcular, Historico (Catalogo removido)

### Estado da IA
- HuggingFace: QUEBRADO (mask vazia, free tier instavel) — mantido como fallback
- App opera em **modo DEMO** ate integracao do novo provider
- **Plano aprovado (2026-09-05):** migrar para Gemini 2.0 Flash (gratis, desenvolvimento) → GPT Image 2 (pago, producao)
- Documentacao completa em `docs/PLANO-INTEGRACAO-IA.md`
- Branch de backup: `backup-v1.0-pre-ia` (commit 9a6c4f9)
- Snapshot do estado atual em `docs/VERSAO-1.0-SNAPSHOT.md`
- **Proximo passo:** usuaria vai criar conta no Google AI Studio e gerar chave (GOOGLE_AI_KEY)
- Arquitetura multi-provider: factory `getAIProvider()` escolhe por env var (OpenAI > Gemini > HuggingFace)

### Pendencias
- **Integracao IA Gemini/OpenAI** (aguardando chave da usuaria)
- Migrar middleware → proxy (Next.js 16 deprecation)
- Remover rota /catalogo (pagina existe mas nao aparece na nav)
- Icones PWA (gerar amarelos)
- Dark mode: sincronizar tokens com amarelo
- Planta baixa: renderizacao IA (precisa API paga)

### Diretorio do projeto
`C:\Users\reves\REVEST DO BRASIL ACABAMENTOS LTDA\RH - Documentos\AMBIENTES VENDAS\prompt-master`

**Why:** App estrategico para equipe de vendas — demonstra produtos aplicados no ambiente real do cliente.
**How to apply:** Consultar CLAUDE.md do projeto. Credenciais em [[ambientes-ia-supabase]]. Sempre abrir sessoes Claude direto neste diretorio. Git author DEVE ser o email noreply do GitHub para deploy funcionar.
