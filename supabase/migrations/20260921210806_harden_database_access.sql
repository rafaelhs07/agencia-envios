-- Ejecutar después de 001 y 002. Restringe la API y resuelve avisos de Supabase.
begin;

-- Todas las referencias de estas funciones ya usan su esquema explícito.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as signature
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any(array[
      'set_updated_at','enforce_tenant_links','guard_profile','prepare_package','log_package_event','audit_record','guard_organization_currency','guard_shipment_transport','current_organization_id','staff_has_role','is_admin','require_staff','save_package','save_financial_record','save_agency_settings','save_consolidation','receive_packages','save_delivery','get_agency_dashboard'
    ])
  loop
    execute format('alter function %s set search_path = %L',r.signature,'');
  end loop;
end $$;

-- Los triggers continúan ejecutándose al escribir; no son RPC de la aplicación.
revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.enforce_tenant_links() from public, anon, authenticated;
revoke all on function public.guard_profile() from public, anon, authenticated;
revoke all on function public.prepare_package() from public, anon, authenticated;
revoke all on function public.log_package_event() from public, anon, authenticated;
revoke all on function public.audit_record() from public, anon, authenticated;
revoke all on function public.guard_organization_currency() from public, anon, authenticated;
revoke all on function public.guard_shipment_transport() from public, anon, authenticated;

-- RLS autoriza las filas; estos permisos limitan las operaciones disponibles.
do $$
declare t text;
begin
  foreach t in array array[
    'audit_logs','branches','cash_movements','cash_sessions','consolidation_packages','consolidations','customers','deliveries','delivery_packages','expenses','invoice_items','invoices','organization_settings','organizations','package_events','packages','payments','profiles','shipments','warehouse_receptions'
  ] loop
    execute format('revoke all on table public.%I from public, anon, authenticated',t);
    execute format('grant select on table public.%I to authenticated',t);
  end loop;
end $$;
grant usage on schema public to authenticated;
grant update on public.organizations to authenticated;
grant insert,update on public.branches,public.profiles,public.customers,
  public.shipments,public.organization_settings to authenticated;
revoke all on public.dashboard_package_counts from public,anon,authenticated;
grant select on public.dashboard_package_counts to authenticated;
revoke all on sequence public.package_events_id_seq,public.audit_logs_id_seq
  from public,anon,authenticated;

-- Una sola política de lectura por tabla; la identidad se evalúa una vez por consulta.
drop policy own_profile on public.profiles;
alter policy staff_read on public.profiles using (
  organization_id = (select public.current_organization_id()) or id = (select auth.uid())
);
drop policy own_customer on public.customers;
alter policy staff_read on public.customers using (
  organization_id = (select public.current_organization_id()) or (
    auth_user_id = (select auth.uid()) and
    exists(select 1 from public.profiles p where p.id = (select auth.uid()) and p.active)
  )
);

-- Índices para relaciones, permisos por agencia y consultas de caja.
create index audit_logs_organization_id_idx on public.audit_logs(organization_id, created_at desc);
create index audit_logs_user_id_idx on public.audit_logs(user_id);
create index cash_movements_cash_session_id_idx on public.cash_movements(cash_session_id);
create index cash_movements_created_by_idx on public.cash_movements(created_by);
create index cash_movements_expense_id_idx on public.cash_movements(expense_id);
create index cash_movements_payment_id_idx on public.cash_movements(payment_id);
create index cash_sessions_branch_id_idx on public.cash_sessions(branch_id);
create index cash_sessions_closed_by_idx on public.cash_sessions(closed_by);
create index cash_sessions_opened_by_idx on public.cash_sessions(opened_by);
create index consolidations_created_by_idx on public.consolidations(created_by);
create index customers_auth_user_id_idx on public.customers(auth_user_id);
create index customers_branch_id_idx on public.customers(branch_id);
create index deliveries_assigned_to_idx on public.deliveries(assigned_to);
create index deliveries_branch_id_idx on public.deliveries(branch_id);
create index deliveries_customer_id_idx on public.deliveries(customer_id);
create index expenses_branch_id_idx on public.expenses(branch_id);
create index expenses_created_by_idx on public.expenses(created_by);
create index invoice_items_invoice_id_idx on public.invoice_items(invoice_id);
create index invoice_items_package_id_idx on public.invoice_items(package_id);
create index invoices_branch_id_idx on public.invoices(branch_id);
create index invoices_created_by_idx on public.invoices(created_by);
create index invoices_customer_id_idx on public.invoices(customer_id);
create index package_events_created_by_idx on public.package_events(created_by);
create index packages_assigned_branch_id_idx on public.packages(assigned_branch_id);
create index packages_created_by_idx on public.packages(created_by);
create index payments_branch_id_idx on public.payments(branch_id);
create index payments_customer_id_idx on public.payments(customer_id);
create index payments_invoice_id_idx on public.payments(invoice_id);
create index payments_received_by_idx on public.payments(received_by);
create index profiles_branch_id_idx on public.profiles(branch_id);
create index profiles_organization_id_idx on public.profiles(organization_id);
create index warehouse_receptions_branch_id_idx on public.warehouse_receptions(branch_id);
create index warehouse_receptions_received_by_idx on public.warehouse_receptions(received_by);
create index warehouse_receptions_shipment_id_idx on public.warehouse_receptions(shipment_id);
create index cash_sessions_org_opened_idx on public.cash_sessions(organization_id,opened_at desc);

notify pgrst, 'reload schema';
commit;
