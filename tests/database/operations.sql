begin;
create function public.test_assert(ok boolean,label text) returns void language plpgsql as $$
begin if not coalesce(ok,false) then raise exception 'Falló: %',label; end if; end $$;
create function public.test_reject(statement text,label text) returns void language plpgsql as $$
declare rejected boolean := false;
begin
  begin execute statement; exception when others then rejected := true; end;
  perform public.test_assert(rejected,label);
end $$;

insert into auth.users(id,email) values
 ('00000000-0000-4000-8000-000000000001','admin-a@example.test'),
 ('00000000-0000-4000-8000-000000000002','admin-b@example.test'),
 ('00000000-0000-4000-8000-000000000003','operations@example.test'),
 ('00000000-0000-4000-8000-000000000004','customer@example.test');
insert into public.organizations(id,name,slug) values
 ('10000000-0000-4000-8000-000000000001','Agencia A','agency-a'),
 ('10000000-0000-4000-8000-000000000002','Agencia B','agency-b');
insert into public.branches(id,organization_id,name,code) values
 ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Sucursal A','A'),
 ('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Sucursal B','B');
insert into public.profiles(id,organization_id,full_name,role,branch_id) values
 ('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','Admin A','ADMIN','20000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','Admin B','ADMIN','20000000-0000-4000-8000-000000000002'),
 ('00000000-0000-4000-8000-000000000003','10000000-0000-4000-8000-000000000001','Operations A','OPERACIONES','20000000-0000-4000-8000-000000000001'),
 ('00000000-0000-4000-8000-000000000004','10000000-0000-4000-8000-000000000001','Customer A','CLIENTE',null);
insert into public.organization_settings(organization_id,air_rate_per_lb,insurance_percent,credit_enabled) values
 ('10000000-0000-4000-8000-000000000001',7,2,false),('10000000-0000-4000-8000-000000000002',7,0,false);
insert into public.customers(id,organization_id,locker_code,first_name,last_name,phone) values
 ('30000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','MIA-A','Cliente','A','88880001'),
 ('30000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002','MIA-B','Cliente','B','88880002');

set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select public.test_assert((select count(*)=1 from public.customers),'aislamiento entre agencias');
select public.test_reject($q$update public.profiles set role='SUPER_ADMIN' where id='00000000-0000-4000-8000-000000000001'$q$,'escalada de rol');
select public.test_reject($q$update public.profiles set active=false where id='00000000-0000-4000-8000-000000000001'$q$,'autodesactivación');
select public.test_reject($q$update public.customers set branch_id='20000000-0000-4000-8000-000000000002' where id='30000000-0000-4000-8000-000000000001'$q$,'sucursal de otra agencia');
select public.save_package('{
 "request_id":"40000000-0000-4000-8000-000000000001","customer_id":"30000000-0000-4000-8000-000000000001",
 "internal_code":"PKG-A","tracking_number":"TRACK-A","description":"Prueba","transport_type":"AEREO",
 "status":"EN_MIAMI","weight_lb":10,"volume_ft3":1,"declared_value":100
}');
select public.test_assert((select total_amount=72 from public.packages where internal_code='PKG-A'),'tarifa y seguro calculados');
select public.test_assert((select count(*)=1 from public.package_events),'historial de registro');
select public.test_reject($q$select public.save_package('{"customer_id":"30000000-0000-4000-8000-000000000002","status":"EN_MIAMI","transport_type":"AEREO","weight_lb":1,"internal_code":"BAD","tracking_number":"BAD"}')$q$,'cliente de otra agencia');
select public.test_reject($q$select public.save_package('{"customer_id":"30000000-0000-4000-8000-000000000001","status":"ENTREGADO","transport_type":"AEREO","weight_lb":1,"internal_code":"BAD","tracking_number":"BAD"}')$q$,'entrega directa fuera del flujo');
select public.test_reject($q$insert into public.packages(organization_id,customer_id,internal_code,tracking_number) values('10000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','DIRECT','DIRECT')$q$,'escritura directa de paquete bloqueada');
select public.test_reject($q$update public.organizations set currency='NIO' where id='10000000-0000-4000-8000-000000000001'$q$,'moneda bloqueada tras operaciones');

select public.save_financial_record('cuentas-por-cobrar','{
 "request_id":"50000000-0000-4000-8000-000000000001","customer_id":"30000000-0000-4000-8000-000000000001",
 "branch_id":"20000000-0000-4000-8000-000000000001","package_id":"40000000-0000-4000-8000-000000000001",
 "description":"Servicio","subtotal":1,"discount":0,"tax":0
}');
select public.test_assert((select total=72 from public.invoices where id='50000000-0000-4000-8000-000000000001'),'factura usa el importe del paquete');
select public.save_financial_record('caja','{"request_id":"60000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","opening_amount":20}');
select public.test_reject($q$select public.save_financial_record('caja','{"branch_id":"20000000-0000-4000-8000-000000000001","opening_amount":1}')$q$,'una sola caja abierta');
select public.save_financial_record('cobros','{"request_id":"70000000-0000-4000-8000-000000000001","invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":25,"method":"EFECTIVO"}');
select public.save_financial_record('cobros','{"request_id":"70000000-0000-4000-8000-000000000001","invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":25,"method":"EFECTIVO"}');
select public.test_assert((select paid_amount=25 and status='PARCIAL' from public.invoices where id='50000000-0000-4000-8000-000000000001'),'abono parcial e idempotencia');
select public.test_assert((select count(*)=1 from public.payments),'reintento no duplica cobro');
select public.test_reject($q$select public.save_financial_record('cobros','{"invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":100,"method":"TRANSFERENCIA"}')$q$,'sobrepago rechazado');
select public.save_financial_record('gastos','{"request_id":"71000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":5,"payment_method":"EFECTIVO","category":"Transporte","description":"Entrega"}');
select public.save_financial_record('caja','{"closing_amount":39}','60000000-0000-4000-8000-000000000001');
select public.test_assert((select expected_amount=40 and closing_amount=39 and difference=-1 and status='CERRADA' from public.cash_sessions where id='60000000-0000-4000-8000-000000000001'),'cierre con saldo y diferencia');
select public.test_reject($q$select public.save_financial_record('cobros','{"invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":1,"method":"EFECTIVO"}')$q$,'efectivo sin caja abierta');
select public.test_assert((select paid_amount=25 from public.invoices where id='50000000-0000-4000-8000-000000000001'),'fallo de caja revierte abono');

select public.test_assert((select count(*)=2 from public.cash_movements),'solo efectivo en movimientos de caja');

select public.save_consolidation('{"request_id":"80000000-0000-4000-8000-000000000001","code":"CON-A","transport_type":"AEREO","status":"ABIERTA","origin":"Miami","destination":"Managua","package_ids":["40000000-0000-4000-8000-000000000001"]}');
select public.test_assert((select status='CONSOLIDADO' from public.packages where internal_code='PKG-A'),'paquete consolidado');
select public.save_consolidation('{"code":"CON-A","transport_type":"AEREO","status":"DESPACHADA","origin":"Miami","destination":"Managua","package_ids":["40000000-0000-4000-8000-000000000001"]}','80000000-0000-4000-8000-000000000001');
select public.test_assert((select status='EN_TRANSITO' from public.packages where internal_code='PKG-A'),'despacho actualiza paquetes');
select public.test_reject($q$insert into public.shipments(organization_id,consolidation_id,transport_type,reference) values('10000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000001','MARITIMO','BAD-SHIPMENT')$q$,'transporte coherente');
insert into public.shipments(id,organization_id,consolidation_id,transport_type,reference) values
 ('81000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','80000000-0000-4000-8000-000000000001','AEREO','SHIP-A');
select public.receive_packages('{"request_id":"82000000-0000-4000-8000-000000000001","code":"RECEP-A","branch_id":"20000000-0000-4000-8000-000000000001","shipment_id":"81000000-0000-4000-8000-000000000001","package_ids":["40000000-0000-4000-8000-000000000001"],"shelf_location":"A-01","damaged_packages":0}');
select public.test_assert((select status='RECIBIDO_NICARAGUA' and shelf_location='A-01' from public.packages where internal_code='PKG-A'),'recepción actualiza ubicación');
select public.save_package('{"customer_id":"30000000-0000-4000-8000-000000000001","internal_code":"PKG-A","tracking_number":"TRACK-A","description":"Prueba","transport_type":"AEREO","status":"LISTO_RETIRO","weight_lb":10,"volume_ft3":1,"declared_value":100,"assigned_branch_id":"20000000-0000-4000-8000-000000000001","shelf_location":"A-01"}','40000000-0000-4000-8000-000000000001');
select public.test_reject($q$select public.save_delivery('{"customer_id":"30000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","code":"DEL-A","delivery_type":"RETIRO_SUCURSAL","status":"ENTREGADA","recipient_name":"Cliente A","package_ids":["40000000-0000-4000-8000-000000000001"]}')$q$,'no entregar deuda sin crédito');
update public.organization_settings set credit_enabled=true where organization_id='10000000-0000-4000-8000-000000000001';
update public.customers set credit_limit=30 where id='30000000-0000-4000-8000-000000000001';
select public.test_reject($q$select public.save_delivery('{"customer_id":"30000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","code":"DEL-A","delivery_type":"RETIRO_SUCURSAL","status":"ENTREGADA","recipient_name":"Cliente A","package_ids":["40000000-0000-4000-8000-000000000001"]}')$q$,'respetar límite de crédito');
update public.customers set credit_limit=100 where id='30000000-0000-4000-8000-000000000001';
select public.save_delivery('{"request_id":"83000000-0000-4000-8000-000000000001","customer_id":"30000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","code":"DEL-A","delivery_type":"RETIRO_SUCURSAL","status":"EN_RUTA","recipient_name":"Cliente A","package_ids":["40000000-0000-4000-8000-000000000001"]}');
select public.test_assert((select status='EN_REPARTO' from public.packages where internal_code='PKG-A'),'crédito autorizado permite reparto');
select public.save_financial_record('cobros','{"request_id":"70000000-0000-4000-8000-000000000002","invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","amount":47,"method":"TRANSFERENCIA"}');
select public.test_assert((select paid_amount=72 and status='PAGADO' from public.invoices where id='50000000-0000-4000-8000-000000000001'),'pago completo');
select public.save_delivery('{"customer_id":"30000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000001","code":"DEL-A","delivery_type":"RETIRO_SUCURSAL","status":"ENTREGADA","recipient_name":"Cliente A","package_ids":["40000000-0000-4000-8000-000000000001"]}','83000000-0000-4000-8000-000000000001');
select public.test_assert((select status='ENTREGADO' and delivered_at is not null from public.packages where internal_code='PKG-A'),'entrega actualiza estado y fecha');
select public.test_assert((public.get_agency_dashboard()->>'delivered')::integer=1,'dashboard usa datos reales');
select public.test_assert((select count(*)>=6 from public.package_events),'historial de estados preservado');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000002',true);
select public.test_assert((select count(*)=0 from public.packages),'paquetes invisibles en otra agencia');
select public.test_reject($q$select public.save_financial_record('cobros','{"invoice_id":"50000000-0000-4000-8000-000000000001","branch_id":"20000000-0000-4000-8000-000000000002","amount":1,"method":"TRANSFERENCIA"}')$q$,'cobro entre agencias rechazado');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000003',true);
select public.test_assert((select count(*)=0 from public.payments),'operaciones no accede a cobros');
select public.test_reject($q$select public.save_financial_record('caja','{"branch_id":"20000000-0000-4000-8000-000000000001","opening_amount":1}')$q$,'rol operativo no abre caja');
select public.test_assert(public.get_agency_dashboard()->>'income_month' is null,'dashboard oculta importes a operaciones');

select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000004',true);
select public.test_assert(public.current_organization_id() is null,'cliente sin acceso de personal');
select public.test_reject($q$insert into public.customers(organization_id,locker_code,first_name,last_name,phone) values('10000000-0000-4000-8000-000000000001','BAD','A','B','1')$q$,'cliente no administra registros');

reset role;
select set_config('request.jwt.claim.sub','',true);
update public.organizations set active=false where id='10000000-0000-4000-8000-000000000001';
set local role authenticated;
select set_config('request.jwt.claim.sub','00000000-0000-4000-8000-000000000001',true);
select public.test_assert((select count(*)=0 from public.packages),'agencia suspendida sin acceso');
select public.test_reject($q$select public.get_agency_dashboard()$q$,'dashboard bloqueado al suspender agencia');

reset role;
set local role anon;
select public.test_reject($q$select public.get_agency_dashboard()$q$,'anónimo sin acceso a RPC');
rollback;
