create table if not exists public.app_fields (
  user_id uuid references auth.users(id) on delete cascade default auth.uid(),
  key text not null,
  value jsonb,
  updated_at timestamptz not null default now()
);

alter table public.app_fields
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

alter table public.app_fields
  alter column user_id set default auth.uid();

alter table public.app_fields
  add column if not exists updated_at timestamptz not null default now();

create unique index if not exists app_fields_user_id_key_idx
on public.app_fields (user_id, key);

alter table public.app_fields enable row level security;

revoke all on public.app_fields from anon;
grant select, insert, update, delete on public.app_fields to authenticated;

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

-- One-time legacy adoption:
-- If this project already has rows that were written before user_id existed,
-- run the update below in the Supabase SQL editor after replacing the UUID
-- with your auth.users.id. Leave rows unassigned until you are sure of the owner.
--
-- update public.app_fields
-- set user_id = '00000000-0000-0000-0000-000000000000'::uuid
-- where user_id is null;
