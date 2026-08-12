-- 029: fornecedores de uniformes + campo logo_tipo em entradas

create table if not exists unif_fornecedores (
  id         bigserial primary key,
  nome       text not null,
  cnpj       text,
  contato    text,
  obs        text,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

alter table unif_entradas
  add column if not exists logo_tipo text; -- 'sem_logo' | 'grupo_revest' | 'revest_acabamentos' | 'outra'

-- RLS: mesmo acesso que as outras tabelas unif_*
alter table unif_fornecedores enable row level security;

create policy "acesso autenticado" on unif_fornecedores
  for all using (auth.role() = 'authenticated');
