-- Aloric Store Marketing v2 — execute no SQL Editor do Supabase.
-- Após criar o único usuário administrador, mantenha o cadastro público desativado no Auth.
create extension if not exists pgcrypto;

create table if not exists public.contacts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text check (char_length(name) <= 120),
  email text,
  phone_e164 text check (phone_e164 is null or phone_e164 ~ '^[+][1-9][0-9]{7,14}$'),
  source text not null default 'manual',
  interests text[] not null default '{}',
  email_marketing_allowed boolean not null default false,
  whatsapp_marketing_allowed boolean not null default false,
  consent_email_at timestamptz,
  consent_whatsapp_at timestamptz,
  consent_evidence text,
  unsubscribed_email_at timestamptz,
  unsubscribed_whatsapp_at timestamptz,
  suppressed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (email is not null or phone_e164 is not null),
  check (not email_marketing_allowed or (email is not null and consent_email_at is not null and consent_evidence is not null)),
  check (not whatsapp_marketing_allowed or (phone_e164 is not null and consent_whatsapp_at is not null and consent_evidence is not null))
);
create unique index if not exists contacts_email_per_owner on public.contacts(owner_id, lower(email)) where email is not null and email <> '';
create unique index if not exists contacts_phone_per_owner on public.contacts(owner_id, phone_e164) where phone_e164 is not null and phone_e164 <> '';
create index if not exists contacts_source_idx on public.contacts(owner_id, source);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check(char_length(name)<=200), category text, price numeric(12,2), promotional_price numeric(12,2),
  product_url text, image_url text, sales_channel text not null check(sales_channel in ('amazon','mercado_livre','loja_propria')),
  active boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null check(char_length(name)<=140), product_id uuid references public.products(id) on delete set null,
  channel text not null check(channel in ('email','whatsapp')), subject text, body text not null,
  status text not null default 'draft' check(status in ('draft','pending_review','scheduled','sending','sent','paused','failed','cancelled')),
  scheduled_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.campaign_events (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  campaign_id uuid not null references public.campaigns(id) on delete cascade,
  contact_id uuid references public.contacts(id) on delete set null,
  channel text not null check(channel in ('email','whatsapp')), event_type text not null,
  provider_message_id text, error_code text, created_at timestamptz not null default now()
);
create table if not exists public.suppression_list (
  id uuid primary key default gen_random_uuid(), owner_id uuid not null references auth.users(id) on delete cascade,
  channel text not null check(channel in ('email','whatsapp')), destination_hash text not null,
  reason text not null default 'unsubscribe', created_at timestamptz not null default now(), unique(owner_id,channel,destination_hash)
);

alter table public.contacts enable row level security;
alter table public.products enable row level security;
alter table public.campaigns enable row level security;
alter table public.campaign_events enable row level security;
alter table public.suppression_list enable row level security;

-- Cria cada política apenas se ainda não existir; não remove políticas existentes.
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'contacts' and policyname = 'contacts_owner_all') then
    create policy contacts_owner_all on public.contacts for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'products' and policyname = 'products_owner_all') then
    create policy products_owner_all on public.products for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'campaigns' and policyname = 'campaigns_owner_all') then
    create policy campaigns_owner_all on public.campaigns for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'campaign_events' and policyname = 'campaign_events_owner_all') then
    create policy campaign_events_owner_all on public.campaign_events for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'suppression_list' and policyname = 'suppression_owner_all') then
    create policy suppression_owner_all on public.suppression_list for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
  end if;
end
$$;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at = now(); return new; end; $$;
drop trigger if exists contacts_updated_at on public.contacts;
create trigger contacts_updated_at before update on public.contacts for each row execute function public.set_updated_at();
drop trigger if exists campaigns_updated_at on public.campaigns;
create trigger campaigns_updated_at before update on public.campaigns for each row execute function public.set_updated_at();

-- NÃO criar policies anon. Nunca colocar service_role key em NEXT_PUBLIC_*.
-- Envios exigem worker server-side separado, validação de consentimento/supressão,
-- rate limits, idempotência, opt-out e confirmação explícita de campanha pelo admin.
