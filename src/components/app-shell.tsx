"use client";

import Link from "next/link";
import { useEffect, useState, type FormEvent } from "react";
import { Box, ChevronRight, LoaderCircle, LogOut, Menu, PackageCheck, PackageOpen, Plane, RefreshCw, Ship, X } from "lucide-react";
import { createClient } from "@/lib/supabase";
import { navigation } from "@/lib/navigation";
import { adminRoles, canRead, displayValue, errorMessage, type Field, type Organization, type Profile, type RecordData } from "@/lib/modules";
import { DataWorkspace, InputFields, Reports, type WorkspaceProps } from "@/components/data-workspace";

function Login({ db }: { db: NonNullable<ReturnType<typeof createClient>> }) {
  const [email,setEmail]=useState("");
  const [password,setPassword]=useState("");
  const [busy,setBusy]=useState(false);
  const [error,setError]=useState("");
  async function submit(event:FormEvent) {
    event.preventDefault();if(busy)return;setBusy(true);setError("");
    try {
      const result=await db.auth.signInWithPassword({email:email.trim(),password});
      if(result.error)throw new Error("No se pudo iniciar sesión. Revisa tu correo y contraseña.");
    }catch(e){setError(errorMessage(e));}finally{setBusy(false);}
  }
  return <div className="auth-screen"><form className="auth-card" onSubmit={submit}><div className="auth-brand"><Box size={26}/><strong>NexoCargo</strong></div>
    <h1>Ingresa a tu agencia</h1><p>Administra tus paquetes, clientes y operaciones.</p>
    <label>Correo<input required type="email" autoComplete="username" value={email} onChange={e=>setEmail(e.target.value)} /></label>
    <label>Contraseña<input required type="password" autoComplete="current-password" value={password} onChange={e=>setPassword(e.target.value)} /></label>
    {error&&<p className="error-box" role="alert">{error}</p>}
    <button className="primary-button" disabled={busy}>{busy?"Ingresando...":"Iniciar sesión"}</button>
    <small>Si aún no tienes acceso, solicita una cuenta al administrador de tu agencia.</small>
  </form></div>;
}

function Dashboard(context:WorkspaceProps) {
  const [data,setData]=useState<Record<string,unknown>|null>(null);
  const [error,setError]=useState("");
  const [version,setVersion]=useState(0);
  useEffect(()=>{
    let active=true;setData(null);setError("");
    context.db.rpc("get_agency_dashboard").then(({data,error})=>{
      if(!active)return;
      if(error)setError(errorMessage(error));else setData(data as Record<string,unknown>);
    });
    return ()=>{active=false;};
  },[context.db,context.profile.organization_id,version]);
  const name=context.profile.full_name.split(" ")[0]||"";
  const money=new Intl.NumberFormat("es-NI",{style:"currency",currency:context.organization.currency});
  const stats=[
    {key:"in_miami",label:"Paquetes en Miami",icon:PackageOpen,color:"violet"},
    {key:"in_transit",label:"En tránsito",icon:Plane,color:"blue"},
    {key:"in_customs",label:"En aduana",icon:Ship,color:"amber"},
    {key:"ready_for_pickup",label:"Listos para retirar",icon:PackageCheck,color:"green"},
  ];
  const flow=(data?.flow||[]) as {day:string;total:number}[];
  const recent=(data?.recent||[]) as RecordData[];
  const max=Math.max(1,...flow.map(item=>item.total));
  return <>
    <section className="page-heading"><div><span className="eyebrow">{new Date().toLocaleDateString("es-NI",{weekday:"long",day:"numeric",month:"long",timeZone:context.organization.timezone}).toUpperCase()}</span>
      <h1>Hola, {name}</h1><p>Resumen de la operación de {context.organization.name}.</p></div>
      <button className="secondary-button" onClick={()=>setVersion(v=>v+1)}><RefreshCw size={17}/>Actualizar</button></section>
    {error?<p className="error-box" role="alert">{error}</p>:!data?<div className="empty" role="status"><LoaderCircle className="spin"/> Cargando resumen...</div>:<>
      <section className="stat-grid">{stats.map(({key,label,icon:Icon,color})=><article className="stat-card" key={key}><div className={"stat-icon "+color}><Icon size={21}/></div><div className="stat-top">{label}</div><strong>{Number(data[key]||0)}</strong><span className="muted">Paquetes registrados</span></article>)}</section>
      <section className="mini-grid live-totals"><div><span>Clientes activos</span><strong>{Number(data.active_customers||0)}</strong></div><div><span>Paquetes entregados</span><strong>{Number(data.delivered||0)}</strong></div>
        {data.income_month!==null&&<><div><span>Cobros del mes</span><strong>{money.format(Number(data.income_month||0))}</strong></div><div><span>Saldo por cobrar</span><strong>{money.format(Number(data.pending_balance||0))}</strong></div><div><span>Gastos del mes</span><strong>{money.format(Number(data.expenses_month||0))}</strong></div></>}</section>
      <section className="panel chart-panel"><div className="panel-title"><div><h2>Flujo de paquetes</h2><p>Registros de los últimos 12 días</p></div></div>
        {flow.length?<div className="bar-chart live-chart">{flow.map(item=><div className="bar-col" key={item.day}><strong>{item.total}</strong><div className="bar-stack" title={item.day+": "+item.total+" paquetes"}><span style={{height:(item.total/max*100)+"%"}}/></div><small>{item.day.slice(5)}</small></div>)}</div>:<div className="empty">No hay paquetes registrados en este período.</div>}</section>
      <section className="panel recent-panel live-recent"><div className="panel-title"><h2>Paquetes recientes</h2><Link className="text-button" href="/paquetes">Ver todos <ChevronRight size={16}/></Link></div>
        <div className="table-wrap"><table><thead><tr><th>Código</th><th>Tracking</th><th>Descripción</th><th>Estado</th><th>Total</th></tr></thead><tbody>{recent.map(row=><tr key={row.id}><td>{displayValue(row.internal_code)}</td><td>{displayValue(row.tracking_number)}</td><td>{displayValue(row.description)}</td><td><span className="status slate">{displayValue(row.status)}</span></td><td>{money.format(Number(row.total_amount||0))}</td></tr>)}</tbody></table>{!recent.length&&<div className="empty">Registra el primer paquete para comenzar.</div>}</div></section>
    </>}
  </>;
}

const settingsFields:Field[]=[
  {key:"name",label:"Nombre de la agencia",required:true},{key:"ruc",label:"RUC"},{key:"phone",label:"Teléfono"},{key:"email",label:"Correo",type:"email"},{key:"address",label:"Dirección"},
  {key:"currency",label:"Moneda",type:"select",options:[{value:"USD",label:"Dólares (USD)"},{value:"NIO",label:"Córdobas (NIO)"}],required:true},
  {key:"air_rate_per_lb",label:"Tarifa aérea por libra",type:"number",min:0,step:"0.01",required:true},
  {key:"sea_rate_per_lb",label:"Tarifa marítima por libra",type:"number",min:0,step:"0.01",required:true},
  {key:"insurance_percent",label:"Seguro (%)",type:"number",min:0,max:100,step:"0.01",required:true},
  {key:"credit_enabled",label:"Permitir entregas a crédito",type:"checkbox"},
  {key:"miami_address",label:"Dirección de Miami",type:"textarea"},{key:"receipt_message",label:"Mensaje para recibos",type:"textarea"}
];

function AgencySettings({onSaved,...context}:WorkspaceProps&{onSaved:()=>void}) {
  const [values,setValues]=useState<Record<string,unknown>|null>(null);
  const [error,setError]=useState("");
  const [notice,setNotice]=useState("");
  const [busy,setBusy]=useState(false);
  useEffect(()=>{
    let active=true;
    context.db.from("organization_settings").select("*").eq("organization_id",context.profile.organization_id).single().then(result=>{
      if(!active)return;
      if(result.error)setError(errorMessage(result.error));else setValues({...context.organization,...result.data});
    });
    return ()=>{active=false;};
  },[context.db,context.organization,context.profile.organization_id]);
  async function submit(event:FormEvent) {
    event.preventDefault();if(busy||!values)return;setBusy(true);setError("");setNotice("");
    try {
      const result=await context.db.rpc("save_agency_settings",{p_data:values});
      if(result.error)throw result.error;
      setNotice("Configuración guardada.");onSaved();
    }catch(e){setError(errorMessage(e));}finally{setBusy(false);}
  }
  return <><section className="page-heading"><div><h1>Configuración</h1><p>Datos y tarifas de tu agencia.</p></div></section>
    {error&&<p className="error-box" role="alert">{error}</p>}{notice&&<p className="success-box" role="status">{notice}</p>}
    {values&&<form className="settings-card" onSubmit={submit}><InputFields fields={settingsFields} values={values} setValues={setValues} db={context.db} profile={context.profile}/>
      <p className="form-hint">Las tarifas se aplican a nuevos paquetes. La moneda solo puede cambiar antes de registrar operaciones.</p><button className="primary-button" disabled={busy}>{busy?"Guardando...":"Guardar cambios"}</button></form>}</>;
}

export function AppShell({activeSlug}:{activeSlug:string}) {
  const [db]=useState(()=>createClient());
  const [userId,setUserId]=useState<string|null>(null);
  const [authReady,setAuthReady]=useState(false);
  const [profile,setProfile]=useState<Profile|null>(null);
  const [organization,setOrganization]=useState<Organization|null>(null);
  const [accessError,setAccessError]=useState("");
  const [version,setVersion]=useState(0);
  const [open,setOpen]=useState(false);
  useEffect(()=>{
    if(!db)return;
    const {data:{subscription}}=db.auth.onAuthStateChange((_event,session)=>{setUserId(session?.user.id||null);setAuthReady(true);});
    return ()=>subscription.unsubscribe();
  },[db]);
  useEffect(()=>{
    if(!db||!userId){setProfile(null);setOrganization(null);return;}
    let active=true;setProfile(null);setOrganization(null);setAccessError("");
    async function load() {
      try {
        const {data:{user},error}=await db!.auth.getUser();
        if(error||!user||user.id!==userId)throw new Error("La sesión venció. Ingresa nuevamente.");
        const result=await db!.from("profiles").select("*").eq("id",user.id).maybeSingle();
        if(result.error)throw result.error;
        if(!result.data)throw new Error("Tu usuario aún no está asociado a una agencia. Solicita al administrador que complete tu perfil.");
        const next=result.data as Profile;
        if(!next.active)throw new Error("Tu acceso está desactivado. Contacta al administrador.");
        if(next.role==="CLIENTE")throw new Error("Esta cuenta es de cliente y no tiene acceso al panel de la agencia.");
        const org=await db!.from("organizations").select("*").eq("id",next.organization_id).maybeSingle();
        if(org.error)throw org.error;
        if(!org.data?.active)throw new Error("La agencia no está disponible o está desactivada.");
        if(active){setProfile(next);setOrganization(org.data as Organization);}
      }catch(e){if(active)setAccessError(errorMessage(e));}
    }
    void load();return ()=>{active=false;};
  },[db,userId,version]);
  async function signOut() {
    if(!db)return;
    const {error}=await db.auth.signOut({scope:"local"});
    if(error)setAccessError(errorMessage(error));else{setUserId(null);setProfile(null);setOrganization(null);setAccessError("");}
  }
  if(!db)return <div className="auth-screen"><div className="auth-card"><div className="auth-brand"><Box/><strong>NexoCargo</strong></div><h1>Configura la conexión</h1><p>Agrega la URL y la clave pública de Supabase en tu archivo .env.local y reinicia el sistema.</p>
    <a className="primary-button" href="https://github.com/rafaelhs07/agencia-envios#instalacion" target="_blank" rel="noreferrer">Ver instrucciones de instalación</a></div></div>;
  if(!authReady)return <div className="auth-screen" role="status"><LoaderCircle className="spin"/> Cargando...</div>;
  if(!userId)return <Login db={db}/>;
  if(!profile||!organization)return <div className="auth-screen"><div className="auth-card">{accessError?<><h1>No se pudo abrir la agencia</h1><p className="error-box" role="alert">{accessError}</p>
    <button className="primary-button" onClick={()=>setVersion(v=>v+1)}>Reintentar</button><button className="secondary-button" onClick={signOut}>Cerrar sesión</button></>:<p role="status"><LoaderCircle className="spin"/> Cargando tu agencia...</p>}</div></div>;
  const visible=navigation.filter(item=>canRead(item.slug,profile));
  const context={db,profile,organization};
  const initials=profile.full_name.split(" ").slice(0,2).map(part=>part[0]||"").join("");
  return <div className="app">
    {open&&<button className="sidebar-backdrop" onClick={()=>setOpen(false)} aria-label="Cerrar menú"/>}
    <aside className={"sidebar "+(open?"open":"")}><div className="brand"><div className="brand-mark"><Box size={23}/></div><div><strong>NexoCargo</strong><span>{organization.name}</span></div><button className="mobile-close" onClick={()=>setOpen(false)} aria-label="Cerrar menú"><X size={20}/></button></div>
      <nav>{[...new Set(visible.map(item=>item.group))].map(group=><div className="nav-group" key={group}><p>{group}</p>{visible.filter(item=>item.group===group).map(item=>{const Icon=item.icon;return <Link className={activeSlug===item.slug?"active":""} key={item.slug} href={item.slug==="dashboard"?"/":"/"+item.slug} onClick={()=>setOpen(false)}><Icon size={18}/><span>{item.label}</span></Link>;})}</div>)}</nav>
      <div className="user-card"><div className="avatar">{initials}</div><div><strong>{profile.full_name}</strong><span>{displayValue(profile.role)}</span></div><button className="logout-button" title="Cerrar sesión" aria-label="Cerrar sesión" onClick={signOut}><LogOut size={18}/></button></div></aside>
    <div className="content-shell"><header className="topbar"><button className="menu-button" onClick={()=>setOpen(true)} aria-label="Abrir menú"><Menu size={21}/></button><div className="breadcrumb"><span>{organization.name}</span><ChevronRight size={15}/><strong>{navigation.find(item=>item.slug===activeSlug)?.label||"Dashboard"}</strong></div></header>
      <main>{!canRead(activeSlug,profile)?<p className="error-box">Tu rol no tiene acceso a este módulo.</p>:activeSlug==="dashboard"?<Dashboard {...context}/>:activeSlug==="configuracion"&&adminRoles.includes(profile.role)?<AgencySettings {...context} onSaved={()=>setVersion(v=>v+1)}/>:activeSlug==="reportes"?<Reports {...context}/>:<DataWorkspace key={activeSlug} {...context} slug={activeSlug}/>}</main></div>
  </div>;
}
