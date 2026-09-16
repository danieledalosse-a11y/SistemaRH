# Módulo Autoatendimento (Meu RH) — Planejamento

> **Arquivo:** `modulos/autoatendimento/index.html`
> **Skill de referência:** `.claude/agents/autoatendimento.md`
> **Migration de RLS:** `migrations/048_rls_autoatendimento_fase1.sql`

---

## O que é

Portal de autoatendimento para o próprio colaborador — acesso direto às suas informações de RH sem depender do RH para consultas básicas. O colaborador faz login pelo mesmo `login.html` do sistema e é redirecionado automaticamente para este módulo (perfil `colaborador`).

---

## Fase 1 — Concluída ✅

**Entregues:**

- [x] Redirecionamento automático pelo perfil no `index.html`
- [x] Autenticação via JWT (Supabase Auth) + `sb_perfil` no localStorage
- [x] RLS nas tabelas `colaboradores` e `ferias` — colaborador vê apenas os próprios dados
- [x] Funções helper no banco: `auth_perfil()` e `auth_colaborador_id()`
- [x] Hero com foto/avatar, nome, cargo, setor, empresa, matrícula
- [x] Aba **Resumo** — cards de tempo de casa e saldo de férias + dados pessoais e profissionais
- [x] Aba **Minhas Férias** — todos os PAs com lançamentos, status e saldo

**Validação pendente antes de liberar para usuários reais:**

- [ ] Login como ANA → confirmar redirecionamento automático para autoatendimento
- [ ] Verificar via DevTools (Network) que `/rest/v1/colaboradores` e `/rest/v1/ferias` retornam apenas os dados dela
- [ ] Confirmar que o RH não foi afetado (regressão nos demais módulos)

---

## Fase 2 — Pendente ⏳

> **Regra:** não iniciar sem validação completa da Fase 1.

**Solicitação de Férias pelo Colaborador**

- [ ] Botão "Solicitar Férias" na aba Minhas Férias
- [ ] Modal/drawer de solicitação: período desejado + observação
- [ ] Criar registro em `ferias` com status `pendente_gestor` (aguardando aprovação do RH/Gestor)
- [ ] Notificação visual para o RH no módulo Férias (badge ou lista de pendentes)
- [ ] Fluxo de aprovação: RH aprova → status vira `aprovado` → colaborador vê confirmação
- [ ] Fluxo de recusa: RH recusa com observação → colaborador vê motivo
- [ ] Auditoria: registrar em `ferias_historico` (ação `solicitado_colaborador`)

---

## Fase 3+ — Planejado 🔲

> Expandir conforme necessidade. Cada item abaixo é um candidato a aba ou seção.

- [ ] **Meus Documentos** — acesso ao holerite, recibos, declarações
- [ ] **Meu Cadastro** — visualização dos dados pessoais (leitura) com solicitação de correção
- [ ] **Meu VT** — saldo atual e histórico de vale transporte
- [ ] **Minhas Avaliações** — histórico de ciclos de desenvolvimento (leitura do módulo Desenvolvimento)
- [ ] **Comunicados** — mural de avisos do RH para o colaborador

---

## Regras técnicas permanentes

1. **Somente leitura** até a Fase 2 ser liberada — nenhum `sbPost`/`sbPatch`/`sbDelete` antes disso.
2. **Nunca acessar dados de outro colaborador** — `colaborador_id` sempre vem do `sb_perfil`, nunca da URL.
3. **RLS como segunda camada de segurança** — o frontend nunca é a única barreira; o banco bloqueia no nível do JWT.
4. **Policy `anon_all` não deve ser removida** — o sistema RH usa chave publicável em outros fluxos; removê-la quebraria esses fluxos.
5. **Whitelist de perfis** — qualquer novo perfil criado futuramente não terá acesso por padrão (nunca usar condições por exclusão nas policies).
