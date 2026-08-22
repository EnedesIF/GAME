-- ============================================================
-- Cidade em Construção — Schema Supabase
-- Rode no SQL Editor do Supabase (cole tudo e execute).
-- Cria: perfil (sociodemográfico), sessoes (resumo do jogo), eventos (log).
-- RLS: cada participante só acessa os PRÓPRIOS dados.
-- A análise agregada é feita pela pesquisadora no Studio (SQL) ou via
-- service_role no back-end — nunca exposta ao participante.
-- ============================================================

-- ---------- PERFIL sociodemográfico ----------
create table if not exists public.perfil (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  faixa_etaria      text,
  genero            text,
  escolaridade      text,
  renda_familiar    text,
  composicao_familiar text,
  uf                text,
  situacao_moradia  text,
  finalidade        text,
  interesse_sustentabilidade text,
  consentimento_lgpd boolean default false,
  criado_em         timestamptz default now(),
  atualizado_em     timestamptz default now()
);

-- ---------- SESSÕES (um registro por partida concluída) ----------
create table if not exists public.sessoes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  resumo     jsonb not null,          -- objeto sessionSummary() do jogo
  criado_em  timestamptz default now()
);
create index if not exists sessoes_user_idx on public.sessoes(user_id);

-- ---------- EVENTOS (log de interações da partida) ----------
create table if not exists public.eventos (
  id         bigint generated always as identity primary key,
  sessao_id  uuid not null references public.sessoes(id) on delete cascade,
  user_id    uuid not null references auth.users(id) on delete cascade,
  tipo       text not null,           -- ex.: item_added, likert, peer_shown...
  payload    jsonb not null,
  criado_em  timestamptz default now()
);
create index if not exists eventos_sessao_idx on public.eventos(sessao_id);
create index if not exists eventos_tipo_idx   on public.eventos(tipo);

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.perfil  enable row level security;
alter table public.sessoes enable row level security;
alter table public.eventos enable row level security;

-- PERFIL: dono lê/escreve o próprio
create policy "perfil_select_own" on public.perfil
  for select using (auth.uid() = user_id);
create policy "perfil_insert_own" on public.perfil
  for insert with check (auth.uid() = user_id);
create policy "perfil_update_own" on public.perfil
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- SESSOES: dono insere e lê as próprias
create policy "sessoes_insert_own" on public.sessoes
  for insert with check (auth.uid() = user_id);
create policy "sessoes_select_own" on public.sessoes
  for select using (auth.uid() = user_id);

-- EVENTOS: dono insere e lê os próprios
create policy "eventos_insert_own" on public.eventos
  for insert with check (auth.uid() = user_id);
create policy "eventos_select_own" on public.eventos
  for select using (auth.uid() = user_id);

-- ============================================================
-- (Opcional) View agregada para análise da pesquisadora.
-- Consulte no SQL Editor (service_role ignora RLS). Não exponha ao front.
-- Exemplo: atributos mais escolhidos.
-- ============================================================
-- select payload->>'id' as atributo, count(*) as n
-- from public.eventos
-- where tipo = 'item_added' and payload->>'kind' = 'atributo'
-- group by 1 order by n desc;
