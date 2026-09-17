-- NexoCargo: esquema inicial multiagencia para Supabase/PostgreSQL
create extension if not exists pgcrypto;

create type public.app_role as enum ('SUPER_ADMIN','ADMIN','OPERACIONES','BODEGA_MIAMI','RECEPCION','CAJA','REPARTIDOR','CLIENTE');
create type public.package_status as enum ('PRE_ALERTA','EN_MIAMI','CONSOLIDADO','EN_TRANSITO','EN_ADUANA','RECIBIDO_NICARAGUA','LISTO_RETIRO','EN_REPARTO','ENTREGADO','INCIDENCIA','CANCELADO');
create type public.transport_type as enum ('AEREO','MARITIMO');
create type public.payment_status as enum ('PENDIENTE','PARCIAL','PAGADO','VENCIDO','ANULADO');
create type public.delivery_type as enum ('RETIRO_SUCURSAL','DOMICILIO');

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  ruc text,
  phone text,
  email text,
  address text,
  logo_url text,
  currency text not null default 'USD',
  timezone text not null default 'America/Managua',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.branches (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name text not null,
  code text not null,
  branch_type text not null default 'SUCURSAL' check (branch_type in ('SUCURSAL','BODEGA_MIAMI','BODEGA_NICARAGUA')),
  phone text,
  address text,
  city text,
  country text not null default 'Nicaragua',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique(organization_id, code)
);

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  organization_id uuid references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  full_name text not null default '',
  phone text,
  role public.app_role not null default 'OPERACIONES',
  active boolean not null default true,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  auth_user_id uuid references auth.users(id) on delete set null,
  branch_id uuid references public.branches(id) on delete set null,
  locker_code text not null,
  first_name text not null,
  last_name text not null,
  identification text,
  phone text not null,
  whatsapp text,
  email text,
  address text,
  credit_limit numeric(12,2) not null default 0 check (credit_limit >= 0),
  active boolean not null default true,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id, locker_code)
);

create table public.packages (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.customers(id),
  assigned_branch_id uuid references public.branches(id) on delete set null,
  tracking_number text not null,
  internal_code text not null,
  carrier text,
  store text,
  description text,
  transport_type public.transport_type not null default 'AEREO',
  status public.package_status not null default 'PRE_ALERTA',
  weight_lb numeric(10,2) check (weight_lb is null or weight_lb >= 0),
  volume_ft3 numeric(10,3) check (volume_ft3 is null or volume_ft3 >= 0),
  declared_value numeric(12,2) not null default 0,
  rate numeric(12,2) not null default 0,
  service_amount numeric(12,2) not null default 0,
  insurance_amount numeric(12,2) not null default 0,
  tax_amount numeric(12,2) not null default 0,
  total_amount numeric(12,2) generated always as (service_amount + insurance_amount + tax_amount) stored,
  received_miami_at timestamptz,
  received_nicaragua_at timestamptz,
  delivered_at timestamptz,
  shelf_location text,
  photo_url text,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(organization_id, tracking_number),
  unique(organization_id, internal_code)
);

create table public.package_events (
  id bigint generated always as identity primary key,
  package_id uuid not null references public.packages(id) on delete cascade,
  status public.package_status not null,
  location text,
  description text not null,
  visible_to_customer boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.consolidations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  code text not null,
  transport_type public.transport_type not null,
  status text not null default 'ABIERTA' check (status in ('ABIERTA','CERRADA','DESPACHADA','RECIBIDA','CANCELADA')),
  origin text not null default 'Miami, FL',
  destination text not null default 'Managua, Nicaragua',
  total_weight_lb numeric(12,2) not null default 0,
  total_volume_ft3 numeric(12,3) not null default 0,
  departure_at timestamptz,
  estimated_arrival_at timestamptz,
  closed_at timestamptz,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(organization_id, code)
);

create table public.consolidation_packages (
  consolidation_id uuid not null references public.consolidations(id) on delete cascade,
  package_id uuid not null references public.packages(id) on delete restrict,
  added_at timestamptz not null default now(),
  primary key(consolidation_id, package_id),
  unique(package_id)
);

create table public.shipments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  consolidation_id uuid references public.consolidations(id) on delete set null,
  transport_type public.transport_type not null,
  reference text not null,
  carrier text,
  vessel_or_flight text,
  master_document text,
  origin text,
  destination text,
  departure_at timestamptz,
  estimated_arrival_at timestamptz,
  arrived_at timestamptz,
  status text not null default 'PROGRAMADO',
  created_at timestamptz not null default now(),
  unique(organization_id, reference)
);

create table public.warehouse_receptions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  shipment_id uuid references public.shipments(id) on delete set null,
  code text not null,
  packages_expected integer not null default 0,
  packages_received integer not null default 0,
  damaged_packages integer not null default 0,
  notes text,
  received_by uuid references public.profiles(id) on delete set null,
  received_at timestamptz not null default now(),
  unique(organization_id, code)
);

create table public.deliveries (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.customers(id),
  branch_id uuid references public.branches(id) on delete set null,
  code text not null,
  delivery_type public.delivery_type not null,
  status text not null default 'PENDIENTE' check (status in ('PENDIENTE','PROGRAMADA','EN_RUTA','ENTREGADA','NO_ENTREGADA','CANCELADA')),
  delivery_address text,
  scheduled_at timestamptz,
  delivered_at timestamptz,
  recipient_name text,
  proof_url text,
  assigned_to uuid references public.profiles(id) on delete set null,
  notes text,
  created_at timestamptz not null default now(),
  unique(organization_id, code)
);

create table public.delivery_packages (
  delivery_id uuid not null references public.deliveries(id) on delete cascade,
  package_id uuid not null references public.packages(id) on delete restrict,
  primary key(delivery_id, package_id),
  unique(package_id)
);

create table public.invoices (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  customer_id uuid not null references public.customers(id),
  branch_id uuid references public.branches(id) on delete set null,
  invoice_number text not null,
  status public.payment_status not null default 'PENDIENTE',
  subtotal numeric(12,2) not null default 0,
  discount numeric(12,2) not null default 0,
  tax numeric(12,2) not null default 0,
  total numeric(12,2) generated always as (subtotal - discount + tax) stored,
  paid_amount numeric(12,2) not null default 0,
  due_date date,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique(organization_id, invoice_number)
);

create table public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  package_id uuid references public.packages(id) on delete set null,
  description text not null,
  quantity numeric(10,2) not null default 1,
  unit_price numeric(12,2) not null default 0,
  total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table public.payments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  invoice_id uuid references public.invoices(id) on delete set null,
  customer_id uuid not null references public.customers(id),
  branch_id uuid references public.branches(id) on delete set null,
  receipt_number text not null,
  amount numeric(12,2) not null check (amount > 0),
  method text not null check (method in ('EFECTIVO','TRANSFERENCIA','TARJETA','MIXTO','OTRO')),
  reference text,
  received_by uuid references public.profiles(id) on delete set null,
  paid_at timestamptz not null default now(),
  notes text,
  unique(organization_id, receipt_number)
);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid references public.branches(id) on delete set null,
  category text not null,
  description text not null,
  supplier text,
  amount numeric(12,2) not null check (amount > 0),
  payment_method text,
  document_url text,
  expense_date date not null default current_date,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  branch_id uuid not null references public.branches(id),
  opened_by uuid not null references public.profiles(id),
  closed_by uuid references public.profiles(id),
  opening_amount numeric(12,2) not null default 0,
  expected_amount numeric(12,2),
  closing_amount numeric(12,2),
  difference numeric(12,2),
  status text not null default 'ABIERTA' check (status in ('ABIERTA','CERRADA')),
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  notes text
);

create table public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  cash_session_id uuid not null references public.cash_sessions(id) on delete cascade,
  payment_id uuid references public.payments(id) on delete set null,
  expense_id uuid references public.expenses(id) on delete set null,
  movement_type text not null check (movement_type in ('INGRESO','EGRESO')),
  concept text not null,
  amount numeric(12,2) not null check (amount > 0),
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table public.organization_settings (
  organization_id uuid primary key references public.organizations(id) on delete cascade,
  air_rate_per_lb numeric(12,2) not null default 7,
  sea_rate_per_lb numeric(12,2) not null default 3.5,
  insurance_percent numeric(5,2) not null default 0,
  credit_enabled boolean not null default true,
  customer_portal_enabled boolean not null default false,
  tracking_notifications_enabled boolean not null default true,
  receipt_message text,
  miami_address text,
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  organization_id uuid references public.organizations(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity text not null,
  entity_id text,
  previous_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

create index packages_org_status_idx on public.packages(organization_id, status);
create index packages_customer_idx on public.packages(customer_id);
create index package_events_package_idx on public.package_events(package_id, created_at desc);
create index invoices_org_status_idx on public.invoices(organization_id, status);
create index payments_org_date_idx on public.payments(organization_id, paid_at desc);
create index customers_org_name_idx on public.customers(organization_id, last_name, first_name);

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end; $$;

create trigger organizations_updated before update on public.organizations for each row execute function public.set_updated_at();
create trigger profiles_updated before update on public.profiles for each row execute function public.set_updated_at();
create trigger customers_updated before update on public.customers for each row execute function public.set_updated_at();
create trigger packages_updated before update on public.packages for each row execute function public.set_updated_at();

create or replace function public.current_organization_id() returns uuid
language sql stable security definer set search_path = public as $$
  select organization_id from public.profiles where id = auth.uid() and active = true
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.profiles where id = auth.uid() and active = true and role in ('SUPER_ADMIN','ADMIN'))
$$;

alter table public.organizations enable row level security;
alter table public.branches enable row level security;
alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.packages enable row level security;
alter table public.package_events enable row level security;
alter table public.consolidations enable row level security;
alter table public.consolidation_packages enable row level security;
alter table public.shipments enable row level security;
alter table public.warehouse_receptions enable row level security;
alter table public.deliveries enable row level security;
alter table public.delivery_packages enable row level security;
alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.payments enable row level security;
alter table public.expenses enable row level security;
alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;
alter table public.organization_settings enable row level security;
alter table public.audit_logs enable row level security;

create policy "organization members read organization" on public.organizations for select using (id = public.current_organization_id());
create policy "admins update organization" on public.organizations for update using (id = public.current_organization_id() and public.is_admin());
create policy "members access branches" on public.branches for all using (organization_id = public.current_organization_id()) with check (organization_id = public.current_organization_id());
create policy "members read profiles" on public.profiles for select using (organization_id = public.current_organization_id() or id = auth.uid());
create policy "admins manage profiles" on public.profiles for all using (organization_id = public.current_organization_id() and public.is_admin()) with check (organization_id = public.current_organization_id() and public.is_admin());
create policy "staff manage customers" on public.customers for all using (organization_id = public.current_organization_id()) with check (organization_id = public.current_organization_id());
create policy "customers see own record" on public.customers for select using (auth_user_id = auth.uid());
create policy "staff manage packages" on public.packages for all using (organization_id = public.current_organization_id()) with check (organization_id = public.current_organization_id());
create policy "customers track packages" on public.packages for select using (customer_id in (select id from public.customers where auth_user_id = auth.uid()));
create policy "visible tracking events" on public.package_events for select using (package_id in (select id from public.packages) and (visible_to_customer or public.current_organization_id() is not null));
create policy "staff manage tracking events" on public.package_events for insert with check (package_id in (select id from public.packages where organization_id = public.current_organization_id()));

-- Políticas multiagencia homogéneas para tablas con organization_id.
do $$
declare table_name text;
begin
  foreach table_name in array array['consolidations','shipments','warehouse_receptions','deliveries','invoices','payments','expenses','cash_sessions','organization_settings','audit_logs'] loop
    execute format('create policy "tenant access" on public.%I for all using (organization_id = public.current_organization_id()) with check (organization_id = public.current_organization_id())', table_name);
  end loop;
end $$;

create policy "tenant consolidation packages" on public.consolidation_packages for all
using (consolidation_id in (select id from public.consolidations where organization_id = public.current_organization_id()))
with check (consolidation_id in (select id from public.consolidations where organization_id = public.current_organization_id()));
create policy "tenant delivery packages" on public.delivery_packages for all
using (delivery_id in (select id from public.deliveries where organization_id = public.current_organization_id()))
with check (delivery_id in (select id from public.deliveries where organization_id = public.current_organization_id()));
create policy "tenant invoice items" on public.invoice_items for all
using (invoice_id in (select id from public.invoices where organization_id = public.current_organization_id()))
with check (invoice_id in (select id from public.invoices where organization_id = public.current_organization_id()));
create policy "tenant cash movements" on public.cash_movements for all
using (cash_session_id in (select id from public.cash_sessions where organization_id = public.current_organization_id()))
with check (cash_session_id in (select id from public.cash_sessions where organization_id = public.current_organization_id()));

-- Vista para el dashboard administrativo.
create or replace view public.dashboard_package_counts with (security_invoker = true) as
select organization_id,
  count(*) filter (where status = 'EN_MIAMI') as in_miami,
  count(*) filter (where status in ('CONSOLIDADO','EN_TRANSITO')) as in_transit,
  count(*) filter (where status = 'EN_ADUANA') as in_customs,
  count(*) filter (where status = 'LISTO_RETIRO') as ready_for_pickup
from public.packages group by organization_id;

