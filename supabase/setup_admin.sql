-- Ejecutar en Supabase SQL Editor después de las migraciones 001 y 002.
-- Antes: Authentication > Users > Add user > Create new user.
-- Crea tu correo y contraseña con "Auto Confirm User".
-- Reemplaza los tres valores de abajo; no escribas la contraseña en este archivo.
begin;
do $$
declare
  v_email text := 'CAMBIA_ESTO_POR_TU_CORREO';
  v_agency text := 'Mi agencia de envíos';
  v_slug text := 'mi-agencia';
  v_user uuid; v_org uuid; v_branch uuid; v_existing_org uuid;
begin
  if v_email = 'CAMBIA_ESTO_POR_TU_CORREO' then raise exception 'Primero escribe el correo del usuario creado en Authentication.'; end if;
  select id into v_user from auth.users where lower(email) = lower(btrim(v_email));
  if v_user is null then raise exception 'No existe ese correo en Authentication > Users.'; end if;
  select id into v_org from public.organizations where slug = v_slug;
  select organization_id into v_existing_org from public.profiles where id = v_user;
  if v_existing_org is not null and v_existing_org is distinct from v_org then
    raise exception 'Este usuario ya pertenece a otra agencia. No se modificó su acceso.';
  end if;
  if v_org is null then
    insert into public.organizations(name,slug) values(v_agency,v_slug) returning id into v_org;
  end if;
  insert into public.branches(organization_id,name,code,branch_type,city,country)
    values(v_org,'Sucursal principal','PRINCIPAL','SUCURSAL','Managua','Nicaragua')
    on conflict(organization_id,code) do nothing;
  select id into v_branch from public.branches where organization_id = v_org and code = 'PRINCIPAL';
  insert into public.organization_settings(organization_id,credit_enabled) values(v_org,false)
    on conflict(organization_id) do nothing;
  insert into public.profiles(id,organization_id,branch_id,full_name,role,active)
    values(v_user,v_org,v_branch,'Administrador','ADMIN',true)
    on conflict(id) do update set branch_id = excluded.branch_id,role = 'ADMIN',active = true;
  raise notice 'Agencia y administrador preparados. Ya puedes iniciar sesión.';
end $$;
commit;
