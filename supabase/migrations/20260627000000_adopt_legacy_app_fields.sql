begin;

create schema if not exists private;

create table if not exists private.app_fields_legacy_backup_20260627 as
select *
from public.app_fields;

revoke all on schema private from anon, authenticated;
revoke all on all tables in schema private from anon, authenticated;

alter table public.app_fields
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.app_fields
  alter column user_id set default auth.uid();

alter table public.app_fields
  add column if not exists updated_at timestamptz not null default now();

do $$
begin
  if exists (
    select 1
    from pg_constraint
    where conrelid = 'public.app_fields'::regclass
      and conname = 'app_fields_pkey'
  ) then
    alter table public.app_fields drop constraint app_fields_pkey;
  end if;
end $$;

create unique index if not exists app_fields_user_id_key_idx
on public.app_fields (user_id, key);

with latest_legacy_fields as (
  select distinct on (key)
    key,
    value,
    updated_at
  from public.app_fields
  where user_id is null
  order by key, updated_at desc nulls last
),
target_users as (
  select id
  from auth.users
)
insert into public.app_fields (user_id, key, value, updated_at)
select
  target_users.id,
  latest_legacy_fields.key,
  latest_legacy_fields.value,
  coalesce(latest_legacy_fields.updated_at, now())
from latest_legacy_fields
cross join target_users
on conflict (user_id, key) do nothing;

delete from public.app_fields
where user_id is null
  and exists (select 1 from auth.users);

alter table public.app_fields enable row level security;

revoke all on public.app_fields from anon;
grant select, insert, update, delete on public.app_fields to authenticated;

drop policy if exists "Allow read app_fields" on public.app_fields;
drop policy if exists "Allow insert app_fields" on public.app_fields;
drop policy if exists "Allow update app_fields" on public.app_fields;
drop policy if exists "Allow delete app_fields" on public.app_fields;

drop policy if exists "Users can read their cash fields" on public.app_fields;
create policy "Users can read their cash fields"
on public.app_fields
for select
to authenticated
using (auth.uid() = user_id);

drop policy if exists "Users can insert their cash fields" on public.app_fields;
create policy "Users can insert their cash fields"
on public.app_fields
for insert
to authenticated
with check (auth.uid() = user_id);

drop policy if exists "Users can update their cash fields" on public.app_fields;
create policy "Users can update their cash fields"
on public.app_fields
for update
to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

drop policy if exists "Users can delete their cash fields" on public.app_fields;
create policy "Users can delete their cash fields"
on public.app_fields
for delete
to authenticated
using (auth.uid() = user_id);

commit;
