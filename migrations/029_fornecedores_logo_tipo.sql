-- 029: fornecedores de uniformes (com migração dos existentes) + logo_tipo em entradas

-- 1. Cria tabela de fornecedores
create table if not exists unif_fornecedores (
  id         bigserial primary key,
  nome       text not null unique,
  cnpj       text,
  contato    text,
  obs        text,
  ativo      boolean not null default true,
  criado_em  timestamptz not null default now()
);

-- 2. Migra fornecedores únicos já existentes em unif_entradas
insert into unif_fornecedores (nome)
select distinct trim(fornecedor)
from unif_entradas
where fornecedor is not null and trim(fornecedor) <> ''
on conflict (nome) do nothing;

-- 3. Adiciona colunas em unif_entradas
alter table unif_entradas
  add column if not exists fornecedor_id bigint references unif_fornecedores(id),
  add column if not exists logo_tipo text; -- 'sem_logo' | 'grupo_revest' | 'revest_acabamentos' | 'outra'

-- 4. Popula fornecedor_id nas entradas existentes
update unif_entradas e
set fornecedor_id = f.id
from unif_fornecedores f
where trim(e.fornecedor) = f.nome
  and e.fornecedor_id is null;

-- 5. RLS
alter table unif_fornecedores enable row level security;

create policy "acesso autenticado" on unif_fornecedores
  for all using (auth.role() = 'authenticated');
