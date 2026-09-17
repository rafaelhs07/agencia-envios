-- Ejecutar una vez después de 001_initial_schema.sql.
begin;

create or replace function public.current_organization_id() returns uuid
language sql stable security definer set search_path = public as $$
  select p.organization_id from public.profiles p
  join public.organizations o on o.id = p.organization_id
  where p.id = auth.uid() and p.active and o.active and p.role <> 'CLIENTE'
$$;

create or replace function public.staff_has_role(allowed text[]) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.profiles p join public.organizations o on o.id = p.organization_id
    where p.id = auth.uid() and p.active and o.active and p.role::text = any(allowed)
  )
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select public.staff_has_role(array['SUPER_ADMIN','ADMIN'])
$$;

create or replace function public.require_staff(allowed text[]) returns uuid
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.staff_has_role(allowed) then
    raise exception 'No tienes permisos para realizar esta operación.' using errcode = '42501';
  end if;
  return public.current_organization_id();
end $$;

-- Sustituye las políticas permisivas del esquema inicial por permisos de operación.
do $$
declare r record; t text; allowed text[];
begin
  for r in select tablename, policyname from pg_policies where schemaname = 'public'
    and tablename = any(array['organizations','branches','profiles','customers','packages','package_events',
      'consolidations','consolidation_packages','shipments','warehouse_receptions','deliveries','delivery_packages',
      'invoices','invoice_items','payments','expenses','cash_sessions','cash_movements','organization_settings','audit_logs'])
  loop execute format('drop policy %I on public.%I', r.policyname, r.tablename); end loop;

  foreach t in array array['branches','profiles','customers','packages','consolidations','shipments',
      'warehouse_receptions','deliveries','organization_settings'] loop
    execute format('create policy staff_read on public.%I for select to authenticated using (organization_id = public.current_organization_id())',t);
  end loop;
  foreach t in array array['invoices','payments','expenses','cash_sessions'] loop
    execute format('create policy finance_read on public.%I for select to authenticated using (organization_id = public.current_organization_id() and public.staff_has_role(array[''SUPER_ADMIN'',''ADMIN'',''CAJA'']))', t);
  end loop;
  foreach t in array array['branches','profiles','customers','shipments','organization_settings'] loop
    allowed := case
      when t in ('branches','profiles','organization_settings') then array['SUPER_ADMIN','ADMIN']
      when t = 'customers' then array['SUPER_ADMIN','ADMIN','OPERACIONES','RECEPCION','CAJA']
      else array['SUPER_ADMIN','ADMIN','OPERACIONES','BODEGA_MIAMI','RECEPCION'] end;
    execute format('create policy staff_insert on public.%I for insert to authenticated with check (organization_id = public.current_organization_id() and public.staff_has_role(%L::text[]))',t,allowed);
    execute format('create policy staff_update on public.%I for update to authenticated using (organization_id = public.current_organization_id() and public.staff_has_role(%L::text[])) with check (organization_id = public.current_organization_id() and public.staff_has_role(%L::text[]))',t,allowed,allowed);
  end loop;
end $$;
create policy organization_read on public.organizations for select to authenticated using (id = public.current_organization_id());
create policy organization_update on public.organizations for update to authenticated
  using (id = public.current_organization_id() and public.is_admin()) with check (id = public.current_organization_id() and public.is_admin());
create policy own_profile on public.profiles for select to authenticated using (id = auth.uid());
create policy own_customer on public.customers for select to authenticated using (
  auth_user_id = auth.uid() and exists (select 1 from public.profiles p where p.id = auth.uid() and p.active));
create policy tracking_read on public.package_events for select to authenticated using (
  exists(select 1 from public.packages p where p.id = package_id and p.organization_id = public.current_organization_id()));
create policy consolidation_links_read on public.consolidation_packages for select to authenticated using (
  exists(select 1 from public.consolidations c where c.id = consolidation_id and c.organization_id = public.current_organization_id()));
create policy delivery_links_read on public.delivery_packages for select to authenticated using (
  exists(select 1 from public.deliveries d where d.id = delivery_id and d.organization_id = public.current_organization_id()));
create policy invoice_items_read on public.invoice_items for select to authenticated using (
  exists(select 1 from public.invoices i where i.id = invoice_id and i.organization_id = public.current_organization_id()));
create policy cash_movements_read on public.cash_movements for select to authenticated using (
  exists(select 1 from public.cash_sessions c where c.id = cash_session_id and c.organization_id = public.current_organization_id()));
create policy audit_read on public.audit_logs for select to authenticated using (
  organization_id = public.current_organization_id() and public.is_admin());

-- Cada referencia debe pertenecer a la misma agencia.
create or replace function public.enforce_tenant_links() returns trigger
language plpgsql security definer set search_path = public as $$
declare i integer; target uuid; tenant uuid; j jsonb := to_jsonb(new);
begin
  if tg_op = 'UPDATE' and new.organization_id is distinct from old.organization_id then
    raise exception 'No se puede trasladar un registro a otra agencia.';
  end if;
  for i in 0..tg_nargs - 1 by 2 loop
    target := nullif(j ->> tg_argv[i], '')::uuid;
    if target is not null then
      execute format('select organization_id from public.%I where id = $1', tg_argv[i+1]) into tenant using target;
      if tenant is null or tenant is distinct from new.organization_id then
        raise exception 'La referencia % no pertenece a esta agencia.', tg_argv[i];
      end if;
    end if;
  end loop;
  return new;
end $$;

create trigger profiles_tenant before insert or update on public.profiles for each row execute function public.enforce_tenant_links('branch_id','branches');
create trigger customers_tenant before insert or update on public.customers for each row execute function public.enforce_tenant_links('branch_id','branches');
create trigger packages_tenant before insert or update on public.packages for each row execute function public.enforce_tenant_links('customer_id','customers','assigned_branch_id','branches');
create trigger shipments_tenant before insert or update on public.shipments for each row execute function public.enforce_tenant_links('consolidation_id','consolidations');
create trigger receptions_tenant before insert or update on public.warehouse_receptions for each row execute function public.enforce_tenant_links('branch_id','branches','shipment_id','shipments');
create trigger deliveries_tenant before insert or update on public.deliveries for each row execute function public.enforce_tenant_links('customer_id','customers','branch_id','branches','assigned_to','profiles');
create trigger invoices_tenant before insert or update on public.invoices for each row execute function public.enforce_tenant_links('customer_id','customers','branch_id','branches');
create trigger payments_tenant before insert or update on public.payments for each row execute function public.enforce_tenant_links('invoice_id','invoices','customer_id','customers','branch_id','branches');
create trigger expenses_tenant before insert or update on public.expenses for each row execute function public.enforce_tenant_links('branch_id','branches');
create trigger cash_tenant before insert or update on public.cash_sessions for each row execute function public.enforce_tenant_links('branch_id','branches','opened_by','profiles','closed_by','profiles');

create or replace function public.guard_profile() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is not null then
    if new.role = 'SUPER_ADMIN' and not public.staff_has_role(array['SUPER_ADMIN']) then
      raise exception 'No puedes asignar el rol SUPER_ADMIN.' using errcode = '42501';
    end if;
    if tg_op = 'UPDATE' then
      if old.role = 'SUPER_ADMIN' and not public.staff_has_role(array['SUPER_ADMIN']) then
        raise exception 'No puedes modificar este usuario.' using errcode = '42501';
      end if;
      if old.id = auth.uid() and (new.active is distinct from old.active or new.role is distinct from old.role) then
        raise exception 'No puedes desactivar ni cambiar el rol de tu propio acceso.';
      end if;
    end if;
  end if;
  return new;
end $$;
create trigger profiles_guard before insert or update on public.profiles for each row execute function public.guard_profile();

alter table public.organization_settings add constraint settings_positive check (
  air_rate_per_lb >= 0 and sea_rate_per_lb >= 0 and insurance_percent between 0 and 100);
alter table public.invoices add constraint invoice_amounts_valid check (
  subtotal >= 0 and tax >= 0 and discount >= 0 and discount <= subtotal and paid_amount >= 0 and paid_amount <= total);
create unique index one_open_cash_per_branch on public.cash_sessions(organization_id,branch_id) where status = 'ABIERTA';
create index packages_org_created_idx on public.packages(organization_id,created_at desc);
create index deliveries_org_created_idx on public.deliveries(organization_id,created_at desc);
create index expenses_org_date_idx on public.expenses(organization_id,expense_date desc);

create or replace function public.prepare_package() returns trigger
language plpgsql security definer set search_path = public as $$
declare settings public.organization_settings%rowtype;
begin
  if tg_op = 'INSERT' or new.weight_lb is distinct from old.weight_lb
      or new.transport_type is distinct from old.transport_type
      or new.declared_value is distinct from old.declared_value then
    if tg_op = 'UPDATE' and exists (
      select 1 from public.invoice_items it join public.invoices i on i.id = it.invoice_id
      where it.package_id = old.id and i.status <> 'ANULADO'
    ) then raise exception 'El paquete ya está facturado; no se puede cambiar su tarifa o peso.'; end if;
    select * into settings from public.organization_settings where organization_id = new.organization_id;
    if not found then raise exception 'Configura las tarifas de la agencia antes de registrar paquetes.'; end if;
    if coalesce(new.weight_lb,0) < 0 or new.declared_value < 0 then raise exception 'Peso y valor declarado deben ser positivos.'; end if;
    new.rate := case when new.transport_type = 'AEREO' then settings.air_rate_per_lb else settings.sea_rate_per_lb end;
    new.service_amount := round(coalesce(new.weight_lb,0) * new.rate,2);
    new.insurance_amount := round(new.declared_value * settings.insurance_percent / 100,2);
    new.tax_amount := 0;
  else
    new.rate := old.rate;
    new.service_amount := old.service_amount;
    new.insurance_amount := old.insurance_amount;
    new.tax_amount := old.tax_amount;
  end if;
  if tg_op = 'UPDATE' and new.customer_id <> old.customer_id and (
    exists(select 1 from public.invoice_items where package_id = old.id) or
    exists(select 1 from public.delivery_packages where package_id = old.id)
  ) then raise exception 'Este paquete ya tiene una cuenta o entrega asociada.'; end if;
  if new.status = 'EN_MIAMI' then new.received_miami_at := coalesce(new.received_miami_at,now()); end if;
  if new.status = 'RECIBIDO_NICARAGUA' then new.received_nicaragua_at := coalesce(new.received_nicaragua_at,now()); end if;
  if new.status = 'ENTREGADO' then new.delivered_at := coalesce(new.delivered_at,now()); end if;
  if tg_op = 'INSERT' then new.created_by := auth.uid(); end if;
  return new;
end $$;
create trigger packages_prepare before insert or update on public.packages for each row execute function public.prepare_package();

create or replace function public.log_package_event() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
    insert into public.package_events(package_id,status,location,description,created_by)
      values(new.id,new.status,new.shelf_location,
        case when tg_op = 'INSERT' then 'Paquete registrado' else 'Estado actualizado a ' || new.status::text end,auth.uid());
  end if;
  return new;
end $$;
create trigger package_event after insert or update on public.packages for each row execute function public.log_package_event();

create or replace function public.audit_record() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.audit_logs(organization_id,user_id,action,entity,entity_id,previous_data,new_data)
  values(new.organization_id,auth.uid(),tg_op,tg_table_name,new.id::text,
    case when tg_op = 'UPDATE' then to_jsonb(old) else null end,to_jsonb(new));
  return new;
end $$;
do $$
declare t text;
begin
  foreach t in array array['customers','packages','profiles','invoices','payments','expenses','cash_sessions','deliveries','consolidations'] loop
    execute format('create trigger audit_change after insert or update on public.%I for each row execute function public.audit_record()',t);
  end loop;
end $$;

-- Las operaciones financieras se guardan completas dentro de una transacción.
create or replace function public.save_financial_record(p_module text,p_data jsonb,p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','CAJA']);
  v_actor uuid := auth.uid();
  v_record_id uuid := coalesce(nullif(p_data->>'request_id','')::uuid,gen_random_uuid());
  v_branch uuid := nullif(p_data->>'branch_id','')::uuid;
  v_customer uuid := nullif(p_data->>'customer_id','')::uuid;
  v_package public.packages%rowtype;
  v_invoice public.invoices%rowtype;
  v_cash public.cash_sessions%rowtype;
  v_amount numeric(12,2);
  v_subtotal numeric(12,2);
  v_discount numeric(12,2) := coalesce(nullif(p_data->>'discount','')::numeric,0);
  v_tax numeric(12,2) := coalesce(nullif(p_data->>'tax','')::numeric,0);
  v_method text := coalesce(p_data->>'method',p_data->>'payment_method');
  v_expected numeric(12,2);
  v_description text := nullif(btrim(p_data->>'description'),'');
begin
  if p_module = 'caja' and p_id is not null then
    select * into v_cash from public.cash_sessions where id = p_id and organization_id = v_org for update;
    if not found then raise exception 'Caja no encontrada.'; end if;
    v_amount := nullif(p_data->>'closing_amount','')::numeric;
    if v_amount is null or v_amount < 0 then raise exception 'Indica el efectivo contado al cerrar.'; end if;
    if v_cash.status = 'CERRADA' then
      if v_cash.closing_amount = v_amount then return v_cash.id; end if;
      raise exception 'Esta caja ya fue cerrada.';
    end if;
    select v_cash.opening_amount + coalesce(sum(case when movement_type = 'INGRESO' then m.amount else -m.amount end),0)
      into v_expected from public.cash_movements m where cash_session_id = v_cash.id;
    update public.cash_sessions set status = 'CERRADA',closed_by = v_actor,closed_at = now(),
      expected_amount = v_expected,closing_amount = v_amount,difference = v_amount - v_expected where id = v_cash.id;
    return v_cash.id;
  end if;
  if p_id is not null then raise exception 'Esta operación no admite edición.'; end if;
  if v_branch is null or not exists(select 1 from public.branches where id = v_branch and organization_id = v_org and active) then
    raise exception 'Selecciona una sucursal activa de tu agencia.';
  end if;

  -- Serializa reintentos de la misma solicitud para evitar duplicar abonos.
  perform pg_advisory_xact_lock(hashtextextended(v_record_id::text,0));
  if p_module = 'cobros' then
    if exists(select 1 from public.payments where id = v_record_id and organization_id = v_org
      and invoice_id = (p_data->>'invoice_id')::uuid and payments.amount = (p_data->>'amount')::numeric
      and payments.method = p_data->>'method' and branch_id = v_branch) then return v_record_id; end if;
    select * into v_invoice from public.invoices where id = nullif(p_data->>'invoice_id','')::uuid
      and organization_id = v_org for update;
    if not found or v_invoice.status = 'ANULADO' then raise exception 'Selecciona una cuenta válida.'; end if;
    v_amount := nullif(p_data->>'amount','')::numeric;
    if v_amount is null or v_amount <= 0 or v_amount > v_invoice.total - v_invoice.paid_amount then
      raise exception 'El abono debe ser mayor que cero y no superar el saldo pendiente.';
    end if;
    if v_method is null or v_method not in ('EFECTIVO','TRANSFERENCIA','TARJETA','OTRO') then raise exception 'Método de pago no válido.'; end if;
    if v_method = 'EFECTIVO' then
      select * into v_cash from public.cash_sessions where organization_id = v_org and branch_id = v_branch and status = 'ABIERTA' for update;
      if not found then raise exception 'Abre la caja de la sucursal para recibir efectivo.'; end if;
    end if;
    insert into public.payments(id,organization_id,invoice_id,customer_id,branch_id,receipt_number,amount,method,reference,received_by,notes)
      values(v_record_id,v_org,v_invoice.id,v_invoice.customer_id,v_branch,'REC-'||upper(substr(v_record_id::text,1,8)),v_amount,v_method,nullif(p_data->>'reference',''),v_actor,p_data->>'notes');
    update public.invoices set paid_amount = paid_amount + v_amount,
      status = case when paid_amount + v_amount >= total then 'PAGADO'::public.payment_status else 'PARCIAL'::public.payment_status end
      where id = v_invoice.id;
    if v_method = 'EFECTIVO' then
      insert into public.cash_movements(cash_session_id,payment_id,movement_type,concept,amount,created_by)
        values(v_cash.id,v_record_id,'INGRESO','Abono a '||v_invoice.invoice_number,v_amount,v_actor);
    end if;

  elsif p_module = 'cuentas-por-cobrar' then
    if exists(select 1 from public.invoices where id = v_record_id and organization_id = v_org and customer_id = v_customer) then return v_record_id; end if;
    if v_customer is null or not exists(select 1 from public.customers where id = v_customer and organization_id = v_org and active) then
      raise exception 'Selecciona un cliente activo.';
    end if;
    if nullif(p_data->>'package_id','') is not null then
      select * into v_package from public.packages where id = (p_data->>'package_id')::uuid and organization_id = v_org for update;
      if not found or v_package.customer_id <> v_customer or v_package.status = 'CANCELADO' then raise exception 'El paquete no corresponde al cliente o está cancelado.'; end if;
      if exists(select 1 from public.invoice_items it join public.invoices i on i.id = it.invoice_id where it.package_id = v_package.id and i.status <> 'ANULADO') then
        raise exception 'Este paquete ya fue facturado.';
      end if;
      v_subtotal := v_package.total_amount;
    else v_subtotal := nullif(p_data->>'subtotal','')::numeric;
    end if;
    if v_description is null or v_subtotal is null or v_subtotal < 0 or v_discount < 0 or v_discount > v_subtotal or v_tax < 0 or v_subtotal - v_discount + v_tax <= 0 then
      raise exception 'Revisa el concepto, subtotal, descuento y cargos de la cuenta.';
    end if;
    insert into public.invoices(id,organization_id,customer_id,branch_id,invoice_number,subtotal,discount,tax,due_date,notes,created_by)
      values(v_record_id,v_org,v_customer,v_branch,'FAC-'||upper(substr(v_record_id::text,1,8)),v_subtotal,v_discount,v_tax,nullif(p_data->>'due_date','')::date,p_data->>'notes',v_actor);
    insert into public.invoice_items(invoice_id,package_id,description,quantity,unit_price)
      values(v_record_id,v_package.id,v_description,1,v_subtotal);

  elsif p_module = 'gastos' then
    v_amount := nullif(p_data->>'amount','')::numeric;
    if exists(select 1 from public.expenses where id = v_record_id and organization_id = v_org and expenses.amount = v_amount and branch_id = v_branch) then return v_record_id; end if;
    if v_amount is null or v_amount <= 0 or v_description is null or nullif(btrim(p_data->>'category'),'') is null then
      raise exception 'Indica categoría, descripción y un monto mayor que cero.';
    end if;
    if v_method is null or v_method not in ('EFECTIVO','TRANSFERENCIA','TARJETA','OTRO') then raise exception 'Método de pago no válido.'; end if;
    if v_method = 'EFECTIVO' then
      select * into v_cash from public.cash_sessions where organization_id = v_org and branch_id = v_branch and status = 'ABIERTA' for update;
      if not found then raise exception 'Abre la caja de la sucursal para registrar gastos en efectivo.'; end if;
    end if;
    insert into public.expenses(id,organization_id,branch_id,category,description,supplier,amount,payment_method,expense_date,created_by)
      values(v_record_id,v_org,v_branch,p_data->>'category',v_description,nullif(p_data->>'supplier',''),v_amount,v_method,
        coalesce(nullif(p_data->>'expense_date','')::date,current_date),v_actor);
    if v_method = 'EFECTIVO' then
      insert into public.cash_movements(cash_session_id,expense_id,movement_type,concept,amount,created_by)
        values(v_cash.id,v_record_id,'EGRESO',v_description,v_amount,v_actor);
    end if;

  elsif p_module = 'caja' then
    if exists(select 1 from public.cash_sessions where id = v_record_id and organization_id = v_org and branch_id = v_branch) then return v_record_id; end if;
    v_amount := nullif(p_data->>'opening_amount','')::numeric;
    if v_amount is null or v_amount < 0 then raise exception 'El fondo inicial debe ser cero o mayor.'; end if;
    insert into public.cash_sessions(id,organization_id,branch_id,opened_by,opening_amount,notes)
      values(v_record_id,v_org,v_branch,v_actor,v_amount,p_data->>'notes');
  else raise exception 'Operación no admitida.';
  end if;
  return v_record_id;
end $$;

create or replace function public.save_agency_settings(p_data jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare tenant uuid := public.require_staff(array['SUPER_ADMIN','ADMIN']);
begin
  if nullif(btrim(p_data->>'name'),'') is null then raise exception 'El nombre de la agencia es obligatorio.'; end if;
  if p_data->>'currency' not in ('USD','NIO') then raise exception 'Moneda no válida.'; end if;
  update public.organizations set name = btrim(p_data->>'name'),ruc = p_data->>'ruc',phone = p_data->>'phone',
    email = p_data->>'email',address = p_data->>'address',currency = p_data->>'currency' where id = tenant;
  update public.organization_settings set
    air_rate_per_lb = (p_data->>'air_rate_per_lb')::numeric,sea_rate_per_lb = (p_data->>'sea_rate_per_lb')::numeric,
    insurance_percent = (p_data->>'insurance_percent')::numeric,credit_enabled = (p_data->>'credit_enabled')::boolean,
    receipt_message = p_data->>'receipt_message',miami_address = p_data->>'miami_address',updated_at = now()
    where organization_id = tenant;
  if not found then raise exception 'Falta inicializar la configuración de la agencia.'; end if;
end $$;

create or replace function public.save_consolidation(p_data jsonb,p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','OPERACIONES','BODEGA_MIAMI','RECEPCION']);
  v_id uuid := coalesce(p_id,nullif(p_data->>'request_id','')::uuid,gen_random_uuid());
  v_ids uuid[]; v_old_ids uuid[]; v_old public.consolidations%rowtype;
  v_status text := p_data->>'status'; v_type public.transport_type := (p_data->>'transport_type')::public.transport_type;
begin
  select array_agg(distinct value::uuid order by value::uuid) into v_ids from jsonb_array_elements_text(p_data->'package_ids');
  if coalesce(cardinality(v_ids),0) = 0 then raise exception 'Selecciona al menos un paquete.'; end if;
  select * into v_old from public.consolidations where id = v_id and organization_id = v_org for update;
  if p_id is not null and not found then raise exception 'Consolidación no encontrada.'; end if;
  if p_id is null and found then return v_id; end if;
  if v_old.status in ('RECIBIDA','CANCELADA') then raise exception 'La consolidación ya está finalizada.'; end if;
  perform 1 from public.packages where id = any(v_ids) and organization_id = v_org order by id for update;
  if (select count(*) from public.packages where id = any(v_ids) and organization_id = v_org and transport_type = v_type) <> cardinality(v_ids) then
    raise exception 'Todos los paquetes deben pertenecer a esta agencia y usar el mismo transporte.';
  end if;
  select array_agg(package_id order by package_id) into v_old_ids from public.consolidation_packages where consolidation_id = v_id;
  if v_old.status = 'DESPACHADA' and (v_old_ids is distinct from v_ids or v_status not in ('DESPACHADA','RECIBIDA')) then
    raise exception 'Una consolidación despachada no admite cambios de paquetes ni cancelación.';
  end if;
  if exists(select 1 from public.packages p where p.id = any(v_ids)
    and not exists(select 1 from public.consolidation_packages cp where cp.package_id = p.id and cp.consolidation_id = v_id)
    and (p.status <> 'EN_MIAMI' or exists(select 1 from public.consolidation_packages cp where cp.package_id = p.id))) then
    raise exception 'Selecciona paquetes en Miami que no pertenezcan a otra consolidación.';
  end if;
  if v_status = 'RECIBIDA' and exists(select 1 from public.packages where id = any(v_ids) and status not in ('RECIBIDO_NICARAGUA','LISTO_RETIRO','EN_REPARTO','ENTREGADO')) then
    raise exception 'Primero registra la recepción de todos los paquetes.';
  end if;
  if nullif(btrim(p_data->>'code'),'') is null then raise exception 'El código es obligatorio.'; end if;
  if p_id is null then
    insert into public.consolidations(id,organization_id,code,transport_type,created_by)
      values(v_id,v_org,btrim(p_data->>'code'),v_type,auth.uid());
  end if;
  update public.consolidations set code = btrim(p_data->>'code'),transport_type = v_type,status = v_status,
    origin = p_data->>'origin',destination = p_data->>'destination',notes = p_data->>'notes',
    departure_at = nullif(p_data->>'departure_at','')::timestamptz,
    estimated_arrival_at = nullif(p_data->>'estimated_arrival_at','')::timestamptz,
    total_weight_lb = (select coalesce(sum(weight_lb),0) from public.packages where id = any(v_ids)),
    total_volume_ft3 = (select coalesce(sum(volume_ft3),0) from public.packages where id = any(v_ids)),
    closed_at = case when v_status <> 'ABIERTA' then coalesce(closed_at,now()) else null end where id = v_id;
  update public.packages set status = 'EN_MIAMI' where id = any(coalesce(v_old_ids,'{}'::uuid[]))
    and (not id = any(v_ids) or v_status = 'CANCELADA') and status = 'CONSOLIDADO';
  delete from public.consolidation_packages where consolidation_id = v_id;
  if v_status <> 'CANCELADA' then
    insert into public.consolidation_packages(consolidation_id,package_id) select v_id,unnest(v_ids);
    update public.packages set status = case when v_status = 'DESPACHADA' then 'EN_TRANSITO'::public.package_status else 'CONSOLIDADO'::public.package_status end
      where id = any(v_ids) and status in ('EN_MIAMI','CONSOLIDADO');
  end if;
  return v_id;
end $$;

create or replace function public.receive_packages(p_data jsonb,p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','OPERACIONES','RECEPCION']);
  v_id uuid := coalesce(nullif(p_data->>'request_id','')::uuid,gen_random_uuid());
  v_ids uuid[]; v_shipment public.shipments%rowtype;
  v_branch uuid := nullif(p_data->>'branch_id','')::uuid;
  v_damaged integer := coalesce(nullif(p_data->>'damaged_packages','')::integer,0);
begin
  if p_id is not null then raise exception 'Una recepción registrada no admite edición.'; end if;
  if exists(select 1 from public.warehouse_receptions where id = v_id and organization_id = v_org) then return v_id; end if;
  select * into v_shipment from public.shipments where id = nullif(p_data->>'shipment_id','')::uuid and organization_id = v_org for update;
  if not found or v_shipment.consolidation_id is null then raise exception 'Selecciona un embarque asociado a una consolidación.'; end if;
  if not exists(select 1 from public.branches where id = v_branch and organization_id = v_org and active) then raise exception 'Sucursal no válida.'; end if;
  select array_agg(distinct value::uuid order by value::uuid) into v_ids from jsonb_array_elements_text(p_data->'package_ids');
  if coalesce(cardinality(v_ids),0) = 0 or v_damaged < 0 or v_damaged > cardinality(v_ids) then raise exception 'Revisa los paquetes recibidos y dañados.'; end if;
  perform 1 from public.packages where id = any(v_ids) and organization_id = v_org order by id for update;
  if (select count(*) from public.packages p join public.consolidation_packages cp on cp.package_id = p.id
      where p.id = any(v_ids) and p.organization_id = v_org and cp.consolidation_id = v_shipment.consolidation_id
        and p.status in ('EN_TRANSITO','EN_ADUANA')) <> cardinality(v_ids) then
    raise exception 'Los paquetes deben pertenecer al embarque y estar en tránsito o aduana.';
  end if;
  insert into public.warehouse_receptions(id,organization_id,branch_id,shipment_id,code,packages_expected,packages_received,damaged_packages,notes,received_by)
    values(v_id,v_org,v_branch,v_shipment.id,p_data->>'code',
      (select count(*) from public.consolidation_packages where consolidation_id = v_shipment.consolidation_id),
      cardinality(v_ids),v_damaged,p_data->>'notes',auth.uid());
  update public.packages set status = 'RECIBIDO_NICARAGUA',assigned_branch_id = v_branch,shelf_location = p_data->>'shelf_location'
    where id = any(v_ids);
  if not exists(select 1 from public.packages p join public.consolidation_packages cp on cp.package_id = p.id
    where cp.consolidation_id = v_shipment.consolidation_id and p.status not in ('RECIBIDO_NICARAGUA','LISTO_RETIRO','EN_REPARTO','ENTREGADO')) then
    update public.shipments set status = 'RECIBIDO',arrived_at = now() where id = v_shipment.id;
    update public.consolidations set status = 'RECIBIDA' where id = v_shipment.consolidation_id;
  end if;
  return v_id;
end $$;

create or replace function public.save_delivery(p_data jsonb,p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','OPERACIONES','RECEPCION']);
  v_id uuid := coalesce(p_id,nullif(p_data->>'request_id','')::uuid,gen_random_uuid());
  v_ids uuid[]; v_old_ids uuid[]; v_old public.deliveries%rowtype;
  v_customer uuid := nullif(p_data->>'customer_id','')::uuid;
  v_status text := p_data->>'status';
begin
  select * into v_old from public.deliveries where id = v_id and organization_id = v_org for update;
  if p_id is not null and not found then raise exception 'Entrega no encontrada.'; end if;
  if p_id is null and found then return v_id; end if;
  if v_old.status in ('ENTREGADA','CANCELADA') then raise exception 'La entrega ya está finalizada.'; end if;
  if p_data->>'delivery_type' = 'DOMICILIO' and nullif(btrim(p_data->>'delivery_address'),'') is null then raise exception 'Indica la dirección de entrega.'; end if;
  if nullif(btrim(p_data->>'recipient_name'),'') is null then raise exception 'Indica el nombre de quien recibe.'; end if;
  select array_agg(distinct value::uuid order by value::uuid) into v_ids from jsonb_array_elements_text(p_data->'package_ids');
  if coalesce(cardinality(v_ids),0) = 0 then raise exception 'Selecciona los paquetes de la entrega.'; end if;
  perform 1 from public.packages where id = any(v_ids) and organization_id = v_org order by id for update;
  if (select count(*) from public.packages where id = any(v_ids) and organization_id = v_org and customer_id = v_customer and status in ('LISTO_RETIRO','EN_REPARTO')) <> cardinality(v_ids) then
    raise exception 'Selecciona paquetes del cliente listos para retirar o en reparto.';
  end if;
  if exists(select 1 from public.delivery_packages where package_id = any(v_ids) and delivery_id <> v_id) then raise exception 'Un paquete ya pertenece a otra entrega.'; end if;
  if v_status in ('EN_RUTA','ENTREGADA') and not coalesce((select credit_enabled from public.organization_settings where organization_id = v_org),false)
    and exists(select 1 from unnest(v_ids) pkg(id) where not exists (
      select 1 from public.invoice_items it join public.invoices i on i.id = it.invoice_id
      where it.package_id = pkg.id and i.status = 'PAGADO'
    )) then raise exception 'El crédito está desactivado: cobra los paquetes antes de entregarlos.'; end if;
  select array_agg(package_id) into v_old_ids from public.delivery_packages where delivery_id = v_id;
  if p_id is null then
    insert into public.deliveries(id,organization_id,customer_id,code,delivery_type)
      values(v_id,v_org,v_customer,p_data->>'code',(p_data->>'delivery_type')::public.delivery_type);
  end if;
  update public.deliveries set customer_id = v_customer,code = p_data->>'code',
    branch_id = nullif(p_data->>'branch_id','')::uuid,delivery_type = (p_data->>'delivery_type')::public.delivery_type,
    status = v_status,delivery_address = p_data->>'delivery_address',recipient_name = p_data->>'recipient_name',
    scheduled_at = nullif(p_data->>'scheduled_at','')::timestamptz,assigned_to = nullif(p_data->>'assigned_to','')::uuid,notes = p_data->>'notes',
    delivered_at = case when v_status = 'ENTREGADA' then now() else null end where id = v_id;
  update public.packages set status = 'LISTO_RETIRO' where id = any(coalesce(v_old_ids,'{}'::uuid[]))
    and (not id = any(v_ids) or v_status in ('CANCELADA','NO_ENTREGADA')) and status = 'EN_REPARTO';
  delete from public.delivery_packages where delivery_id = v_id;
  if v_status <> 'CANCELADA' then
    insert into public.delivery_packages(delivery_id,package_id) select v_id,unnest(v_ids);
    if v_status in ('EN_RUTA','ENTREGADA') then
      update public.packages set status = case when v_status = 'ENTREGADA' then 'ENTREGADO'::public.package_status else 'EN_REPARTO'::public.package_status end where id = any(v_ids);
    end if;
  end if;
  return v_id;
end $$;

create or replace function public.get_agency_dashboard() returns jsonb
language plpgsql stable security invoker set search_path = public as $$
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','OPERACIONES','BODEGA_MIAMI','RECEPCION','CAJA','REPARTIDOR']);
  v_zone text := (select timezone from public.organizations where id = v_org);
  v_today date; v_month timestamptz; v_result jsonb;
begin
  v_today := (now() at time zone v_zone)::date;
  v_month := date_trunc('month',now() at time zone v_zone) at time zone v_zone;
  select jsonb_build_object(
    'in_miami',count(*) filter(where status = 'EN_MIAMI'),
    'in_transit',count(*) filter(where status in ('CONSOLIDADO','EN_TRANSITO')),
    'in_customs',count(*) filter(where status = 'EN_ADUANA'),
    'ready_for_pickup',count(*) filter(where status = 'LISTO_RETIRO'),
    'total_packages',count(*),'delivered',count(*) filter(where status = 'ENTREGADO')
  ) into v_result from public.packages where organization_id = v_org;
  return v_result || jsonb_build_object(
    'active_customers',(select count(*) from public.customers where organization_id = v_org and active),
    'income_month',case when public.staff_has_role(array['SUPER_ADMIN','ADMIN','CAJA']) then (select coalesce(sum(amount),0) from public.payments where organization_id = v_org and paid_at >= v_month) else null end,
    'expenses_month',case when public.staff_has_role(array['SUPER_ADMIN','ADMIN','CAJA']) then (select coalesce(sum(amount),0) from public.expenses where organization_id = v_org and expense_date >= (v_month at time zone v_zone)::date) else null end,
    'pending_balance',case when public.staff_has_role(array['SUPER_ADMIN','ADMIN','CAJA']) then (select coalesce(sum(total - paid_amount),0) from public.invoices where organization_id = v_org and status <> 'ANULADO') else null end,
    'flow',(select coalesce(jsonb_agg(d order by day),'[]'::jsonb) from (
      select (created_at at time zone v_zone)::date as day,count(*) as total
      from public.packages where organization_id = v_org and created_at >= ((v_today - 11)::timestamp at time zone v_zone)
      group by 1
    ) d),
    'recent',(select coalesce(jsonb_agg(p order by created_at desc),'[]'::jsonb) from (
      select id,internal_code,tracking_number,description,status,total_amount,created_at
      from public.packages where organization_id = v_org order by created_at desc limit 5
    ) p)
  );
end $$;


create or replace function public.save_package(p_data jsonb,p_id uuid default null) returns uuid
language plpgsql security definer set search_path = public as $
declare
  v_org uuid := public.require_staff(array['SUPER_ADMIN','ADMIN','OPERACIONES','BODEGA_MIAMI','RECEPCION']);
  v_id uuid := coalesce(p_id,nullif(p_data->>'request_id','')::uuid,gen_random_uuid());
  v_old public.packages%rowtype;
  v_status public.package_status := (p_data->>'status')::public.package_status;
  v_customer uuid := nullif(p_data->>'customer_id','')::uuid;
begin
  select * into v_old from public.packages where id = v_id and organization_id = v_org for update;
  if p_id is not null and not found then raise exception 'Paquete no encontrado.'; end if;
  if p_id is null and found then return v_id; end if;
  if v_status in ('CONSOLIDADO','EN_TRANSITO','RECIBIDO_NICARAGUA','EN_REPARTO','ENTREGADO') and v_status is distinct from v_old.status then
    raise exception 'Este estado se asigna desde Consolidaciones, Recepción o Entregas.';
  end if;
  if v_old.status in ('ENTREGADO','CANCELADO') and v_status is distinct from v_old.status then
    raise exception 'Un paquete finalizado no puede reabrirse.';
  end if;
  if v_status = 'LISTO_RETIRO' and (p_id is null or v_old.status not in ('RECIBIDO_NICARAGUA','LISTO_RETIRO','INCIDENCIA') or v_old.received_nicaragua_at is null) then
    raise exception 'Primero registra la recepción del paquete en Nicaragua.';
  end if;
  if v_status = 'EN_ADUANA' and (p_id is null or v_old.status not in ('EN_TRANSITO','EN_ADUANA','INCIDENCIA')) then
    raise exception 'Solo un paquete en tránsito puede pasar a aduana.';
  end if;
  if v_status in ('PRE_ALERTA','EN_MIAMI','CANCELADO') and (
    exists(select 1 from public.consolidation_packages where package_id = v_id) or
    exists(select 1 from public.delivery_packages where package_id = v_id)
  ) then raise exception 'Gestiona primero la consolidación o entrega asociada a este paquete.'; end if;
  if not exists(select 1 from public.customers where id = v_customer and organization_id = v_org and active) then raise exception 'Selecciona un cliente activo de tu agencia.'; end if;
  if nullif(btrim(p_data->>'tracking_number'),'') is null or nullif(btrim(p_data->>'internal_code'),'') is null then raise exception 'Tracking y código interno son obligatorios.'; end if;
  if p_id is null then
    insert into public.packages(id,organization_id,customer_id,tracking_number,internal_code,description,transport_type,status,
      weight_lb,volume_ft3,declared_value,assigned_branch_id,carrier,store,shelf_location,notes)
    values(v_id,v_org,v_customer,btrim(p_data->>'tracking_number'),btrim(p_data->>'internal_code'),p_data->>'description',
      (p_data->>'transport_type')::public.transport_type,v_status,(p_data->>'weight_lb')::numeric,
      (p_data->>'volume_ft3')::numeric,(p_data->>'declared_value')::numeric,nullif(p_data->>'assigned_branch_id','')::uuid,
      p_data->>'carrier',p_data->>'store',p_data->>'shelf_location',p_data->>'notes');
  else
    if (v_old.transport_type::text <> p_data->>'transport_type' or v_old.weight_lb is distinct from (p_data->>'weight_lb')::numeric)
      and exists(select 1 from public.consolidation_packages where package_id = v_id) then
      raise exception 'Retira el paquete de su consolidación antes de cambiar peso o transporte.';
    end if;
    update public.packages set customer_id = v_customer,tracking_number = btrim(p_data->>'tracking_number'),internal_code = btrim(p_data->>'internal_code'),
      description = p_data->>'description',transport_type = (p_data->>'transport_type')::public.transport_type,status = v_status,
      weight_lb = (p_data->>'weight_lb')::numeric,volume_ft3 = (p_data->>'volume_ft3')::numeric,declared_value = (p_data->>'declared_value')::numeric,
      assigned_branch_id = nullif(p_data->>'assigned_branch_id','')::uuid,carrier = p_data->>'carrier',store = p_data->>'store',
      shelf_location = p_data->>'shelf_location',notes = p_data->>'notes' where id = v_id;
  end if;
  return v_id;
end $;

create or replace function public.guard_organization_currency() returns trigger
language plpgsql security definer set search_path = public as $
begin
  if new.currency is distinct from old.currency and (
    exists(select 1 from public.packages where organization_id = old.id) or
    exists(select 1 from public.invoices where organization_id = old.id) or
    exists(select 1 from public.payments where organization_id = old.id) or
    exists(select 1 from public.expenses where organization_id = old.id) or
    exists(select 1 from public.cash_sessions where organization_id = old.id)
  ) then raise exception 'La moneda no puede cambiar después de registrar operaciones.'; end if;
  return new;
end $;
create trigger organization_currency before update on public.organizations for each row execute function public.guard_organization_currency();

create or replace function public.guard_shipment_transport() returns trigger
language plpgsql security definer set search_path = public as $
begin
  if new.consolidation_id is not null and not exists(select 1 from public.consolidations where id = new.consolidation_id and transport_type = new.transport_type) then
    raise exception 'El embarque y la consolidación deben usar el mismo transporte.';
  end if;
  return new;
end $;
create trigger shipment_transport before insert or update on public.shipments for each row execute function public.guard_shipment_transport();
create unique index one_shipment_per_consolidation on public.shipments(consolidation_id) where consolidation_id is not null;

-- Solo los usuarios autenticados pueden ejecutar las operaciones de la aplicación.
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as signature from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = any(array['current_organization_id','is_admin','staff_has_role','require_staff',
      'save_package','save_financial_record','save_agency_settings','save_consolidation','receive_packages','save_delivery','get_agency_dashboard'])
  loop
    execute format('revoke all on function %s from public, anon',r.signature);
    execute format('grant execute on function %s to authenticated',r.signature);
  end loop;
end $$;
notify pgrst, 'reload schema';
commit;
