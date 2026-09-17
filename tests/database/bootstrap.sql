-- Solo para la base efímera de CI. Nunca ejecutar en un proyecto Supabase.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key,email text unique);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
alter default privileges in schema public grant select,insert,update,delete on tables to anon,authenticated;
alter default privileges in schema public grant usage,select on sequences to anon,authenticated;
