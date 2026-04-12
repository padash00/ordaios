-- Phase 3: APNs device tokens for Orda Control iOS (and future clients)
create table if not exists public.device_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  device_token text not null,
  platform text not null default 'ios',
  app_bundle_id text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint device_push_tokens_user_token_unique unique (user_id, device_token)
);

create index if not exists device_push_tokens_user_id_idx on public.device_push_tokens (user_id);

alter table public.device_push_tokens enable row level security;

create policy "device_push_tokens_select_own"
  on public.device_push_tokens for select
  using (auth.uid() = user_id);

create policy "device_push_tokens_insert_own"
  on public.device_push_tokens for insert
  with check (auth.uid() = user_id);

create policy "device_push_tokens_update_own"
  on public.device_push_tokens for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "device_push_tokens_delete_own"
  on public.device_push_tokens for delete
  using (auth.uid() = user_id);
