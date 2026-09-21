-- Verificación de permisos de la aplicación. No modifica datos ni esquema.
do $$
declare r record; signature regprocedure; table_count integer := 0;
begin
  for r in select c.oid,c.relname,c.relrowsecurity from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r'
  loop
    table_count := table_count + 1;
    if not r.relrowsecurity then raise exception 'RLS desactivado: %',r.relname; end if;
    if has_table_privilege('anon',r.oid,'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then
      raise exception 'Acceso anónimo a la tabla %',r.relname;
    end if;
    if has_table_privilege('authenticated',r.oid,'DELETE,TRUNCATE,REFERENCES,TRIGGER') then
      raise exception 'Permiso de administración de tabla expuesto: %',r.relname;
    end if;
    if not has_table_privilege('authenticated',r.oid,'SELECT') then
      raise exception 'Falta acceso de lectura con RLS: %',r.relname;
    end if;
  end loop;
  if table_count <> 20 then raise exception 'Se esperaban las 20 tablas de la aplicación.'; end if;
  foreach signature in array array[
    'public.set_updated_at()'::regprocedure,'public.enforce_tenant_links()'::regprocedure,
    'public.guard_profile()'::regprocedure,'public.prepare_package()'::regprocedure,
    'public.log_package_event()'::regprocedure,'public.audit_record()'::regprocedure,
    'public.guard_organization_currency()'::regprocedure,'public.guard_shipment_transport()'::regprocedure
  ] loop
    if has_function_privilege('anon',signature,'EXECUTE') or
       has_function_privilege('authenticated',signature,'EXECUTE') then
      raise exception 'Trigger expuesto como función pública: %',signature;
    end if;
  end loop;
  foreach signature in array array[
    'public.save_package(jsonb,uuid)'::regprocedure,
    'public.save_financial_record(text,jsonb,uuid)'::regprocedure,
    'public.save_agency_settings(jsonb)'::regprocedure,
    'public.save_consolidation(jsonb,uuid)'::regprocedure,
    'public.receive_packages(jsonb,uuid)'::regprocedure,
    'public.save_delivery(jsonb,uuid)'::regprocedure,
    'public.get_agency_dashboard()'::regprocedure
  ] loop
    if has_function_privilege('anon',signature,'EXECUTE') or
       not has_function_privilege('authenticated',signature,'EXECUTE') then
      raise exception 'Permisos de RPC incorrectos: %',signature;
    end if;
  end loop;
  for r in select unnest(array['packages','consolidations','warehouse_receptions','deliveries',
    'invoices','invoice_items','payments','expenses','cash_sessions','cash_movements','audit_logs']) as name
  loop
    if has_table_privilege('authenticated',format('public.%I',r.name),'INSERT,UPDATE') then
      raise exception 'Escritura directa permitida fuera de las RPC: %',r.name;
    end if;
  end loop;
end $$;
select 'Permisos verificados' as result;
