import { NextResponse } from "next/server";
import { createClient } from "@supabase/supabase-js";

export const dynamic = "force-dynamic";
const headers = { "Cache-Control": "no-store" };
const fail = (message:string,status:number) => NextResponse.json({error:message},{status,headers});

export async function POST(request:Request) {
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY||process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  const serviceKey=process.env.SUPABASE_SERVICE_ROLE_KEY;
  if(!url||!key)return fail("Falta configurar Supabase.",503);
  const authorization=request.headers.get("authorization");
  if(!authorization?.startsWith("Bearer "))return fail("Debes iniciar sesión.",401);
  const token=authorization.slice(7);
  const db=createClient(url,key,{global:{headers:{Authorization:"Bearer "+token}},auth:{persistSession:false,autoRefreshToken:false}});
  const {data:{user},error:authError}=await db.auth.getUser(token);
  if(authError||!user)return fail("La sesión no es válida.",401);
  const {data:actor,error:profileError}=await db.from("profiles").select("id,organization_id,role,active").eq("id",user.id).single();
  if(profileError||!actor?.active||!["ADMIN","SUPER_ADMIN"].includes(actor.role))return fail("Solo un administrador puede crear usuarios.",403);
  const {data:organization}=await db.from("organizations").select("id,active").eq("id",actor.organization_id).single();
  if(!organization?.active)return fail("La agencia está desactivada.",403);
  if(!serviceKey)return fail("El administrador del servidor debe configurar SUPABASE_SERVICE_ROLE_KEY para crear usuarios.",503);
  let body:Record<string,unknown>;
  try { body=await request.json();if(!body||Array.isArray(body)||typeof body!=="object")throw new Error(); }
  catch {return fail("Solicitud no válida.",400);}
  const email=typeof body.email==="string"?body.email.trim().toLowerCase():"";
  const password=typeof body.password==="string"?body.password:"";
  const fullName=typeof body.full_name==="string"?body.full_name.trim():"";
  const role=typeof body.role==="string"?body.role:"";
  const allowed=["ADMIN","OPERACIONES","BODEGA_MIAMI","RECEPCION","CAJA","REPARTIDOR"];
  if(!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)||email.length>254||password.length<12||password.length>128||!fullName||fullName.length>200||!allowed.includes(role))
    return fail("Revisa nombre, correo, rol y contraseña (mínimo 12 caracteres).",400);
  const branchId=typeof body.branch_id==="string"&&body.branch_id?body.branch_id:null;
  if(branchId) {
    const {data:branch,error}=await db.from("branches").select("id").eq("id",branchId).eq("organization_id",actor.organization_id).eq("active",true).maybeSingle();
    if(error||!branch)return fail("La sucursal no pertenece a tu agencia o está desactivada.",400);
  }
  const admin=createClient(url,serviceKey,{auth:{autoRefreshToken:false,persistSession:false}});
  const {data:created,error:createError}=await admin.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{full_name:fullName}});
  if(createError||!created.user)return fail("No se pudo crear el acceso. Comprueba si el correo ya está registrado y la configuración de Auth.",400);
  // La inserción conserva la sesión del administrador y vuelve a comprobar RLS.
  const {error:insertError}=await db.from("profiles").insert({
    id:created.user.id,organization_id:actor.organization_id,branch_id:branchId,
    full_name:fullName,role,active:body.active!==false,phone:typeof body.phone==="string"?body.phone.trim().slice(0,100):null
  });
  if(insertError) {
    const {error:cleanupError}=await admin.auth.admin.deleteUser(created.user.id);
    return fail(cleanupError?"No se creó el perfil. Revisa el acceso pendiente en Supabase Auth antes de reintentar.":"No se pudo crear el perfil; el acceso fue revertido.",500);
  }
  return NextResponse.json({id:created.user.id},{status:201,headers});
}
