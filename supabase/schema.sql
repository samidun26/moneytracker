-- Duit · Supabase schema
-- Run once in your Supabase project: Dashboard → SQL Editor → New query → paste → Run.
-- Safe to re-run.
--
-- Design: the server is a dumb, per-user replica. Every app record is one row
-- with its JSON payload. This keeps sync generic, and new app fields need no
-- migration. Row Level Security guarantees each user only sees their own rows.

create table if not exists public.records (
  user_id           uuid        not null default auth.uid() references auth.users (id) on delete cascade,
  tbl               text        not null,
  id                text        not null,
  data              jsonb       not null,
  updated_at        bigint      not null,               -- client edit time (ms), used for last-write-wins
  deleted           boolean     not null default false, -- soft delete so deletions sync
  server_updated_at timestamptz not null default clock_timestamp(), -- pull cursor (server clock)
  primary key (user_id, tbl, id)
);

create index if not exists records_user_cursor_idx on public.records (user_id, server_updated_at);

alter table public.records enable row level security;

drop policy if exists "records: select own" on public.records;
create policy "records: select own" on public.records
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "records: insert own" on public.records;
create policy "records: insert own" on public.records
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "records: update own" on public.records;
create policy "records: update own" on public.records
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

drop policy if exists "records: delete own" on public.records;
create policy "records: delete own" on public.records
  for delete to authenticated using ((select auth.uid()) = user_id);

-- Batch upsert with a server-side last-write-wins guard: an older edit
-- arriving late (e.g. from a phone that was offline) never overwrites a newer one.
create or replace function public.push_records(items jsonb)
returns integer
language plpgsql
security invoker
set search_path = ''
as $$
declare
  affected integer;
begin
  if auth.uid() is null then
    raise exception 'not authenticated';
  end if;

  insert into public.records as r (user_id, tbl, id, data, updated_at, deleted, server_updated_at)
  select auth.uid(), x.tbl, x.id, x.data, x.updated_at, coalesce(x.deleted, false), clock_timestamp()
  from jsonb_to_recordset(items) as x(tbl text, id text, data jsonb, updated_at bigint, deleted boolean)
  on conflict (user_id, tbl, id) do update
    set data              = excluded.data,
        updated_at        = excluded.updated_at,
        deleted           = excluded.deleted,
        server_updated_at = clock_timestamp()
    where r.updated_at <= excluded.updated_at;

  get diagnostics affected = row_count;
  return affected;
end;
$$;

revoke all on function public.push_records(jsonb) from public, anon;
grant execute on function public.push_records(jsonb) to authenticated;
