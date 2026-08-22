-- GAME · Turma simultânea e dashboard docente agregado
-- Execute uma única vez no projeto BUSINESSGAME.

alter table public.perfil
  add column if not exists nome_exibicao text,
  add column if not exists turma_codigo text,
  add column if not exists papel_jogo text,
  add column if not exists etapa_atual text,
  add column if not exists ultima_atividade_em timestamptz;

create index if not exists perfil_turma_idx on public.perfil(turma_codigo);
create index if not exists perfil_turma_atividade_idx on public.perfil(turma_codigo, ultima_atividade_em desc);

create table if not exists public.docentes (
  email text primary key,
  turma_codigo text not null,
  nome_exibicao text,
  criado_em timestamptz not null default now()
);

alter table public.docentes enable row level security;

drop policy if exists "docentes_select_self" on public.docentes;
create policy "docentes_select_self" on public.docentes
  for select to authenticated
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')));

create or replace function public.dashboard_turma(p_codigo_turma text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(coalesce(auth.jwt() ->> 'email', ''));
begin
  if not exists (
    select 1 from public.docentes d
    where lower(d.email) = v_email and d.turma_codigo = p_codigo_turma
  ) then
    raise exception 'Acesso docente não autorizado para esta turma';
  end if;

  return jsonb_build_object(
    'turma_codigo', p_codigo_turma,
    'participantes', (
      select count(*) from public.perfil p where p.turma_codigo = p_codigo_turma
    ),
    'ativos_15min', (
      select count(*) from public.perfil p
      where p.turma_codigo = p_codigo_turma
        and p.ultima_atividade_em >= now() - interval '15 minutes'
    ),
    'projetos_concluidos', (
      select count(*) from public.sessoes s
      join public.perfil p on p.user_id = s.user_id
      where p.turma_codigo = p_codigo_turma
    ),
    'etapas', coalesce((
      select jsonb_agg(jsonb_build_object('rotulo', etapa, 'quantidade', quantidade) order by quantidade desc, etapa)
      from (
        select coalesce(p.etapa_atual, 'Cadastro') as etapa, count(*)::int as quantidade
        from public.perfil p
        where p.turma_codigo = p_codigo_turma
        group by 1
      ) etapas_agrupadas
    ), '[]'::jsonb),
    'conceitos', coalesce((
      select jsonb_agg(jsonb_build_object('rotulo', rotulo, 'quantidade', quantidade) order by quantidade desc, rotulo)
      from (
        select coalesce(s.resumo ->> 'conceito', 'Não informado') as rotulo, count(*)::int as quantidade
        from public.sessoes s join public.perfil p on p.user_id = s.user_id
        where p.turma_codigo = p_codigo_turma
        group by 1
      ) conceitos_agrupados
    ), '[]'::jsonb),
    'terrenos', coalesce((
      select jsonb_agg(jsonb_build_object('rotulo', rotulo, 'quantidade', quantidade) order by quantidade desc, rotulo)
      from (
        select coalesce(s.resumo ->> 'terreno', 'Não informado') as rotulo, count(*)::int as quantidade
        from public.sessoes s join public.perfil p on p.user_id = s.user_id
        where p.turma_codigo = p_codigo_turma
        group by 1
      ) terrenos_agrupados
    ), '[]'::jsonb),
    'perfis', coalesce((
      select jsonb_agg(jsonb_build_object('rotulo', rotulo, 'quantidade', quantidade) order by quantidade desc, rotulo)
      from (
        select coalesce(s.resumo ->> 'papel', coalesce(p.papel_jogo, 'Não informado')) as rotulo, count(*)::int as quantidade
        from public.sessoes s join public.perfil p on p.user_id = s.user_id
        where p.turma_codigo = p_codigo_turma
        group by 1
      ) perfis_agrupados
    ), '[]'::jsonb),
    'atributos', coalesce((
      select jsonb_agg(jsonb_build_object('rotulo', atributo, 'quantidade', quantidade) order by quantidade desc, atributo)
      from (
        select atributo, count(*)::int as quantidade
        from public.sessoes s
        join public.perfil p on p.user_id = s.user_id
        cross join lateral jsonb_array_elements_text(coalesce(s.resumo -> 'atributos', '[]'::jsonb)) atributo
        where p.turma_codigo = p_codigo_turma
        group by atributo
      ) atributos_agrupados
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.dashboard_turma(text) from public;
revoke execute on function public.dashboard_turma(text) from anon;
grant execute on function public.dashboard_turma(text) to authenticated;
