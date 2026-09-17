"use client";

import { useEffect, useRef, useState, type FormEvent } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import { Check, ChevronLeft, ChevronRight, Download, LoaderCircle, Pencil, Plus, RefreshCw, X } from "lucide-react";
import { moduleMeta, navigation } from "@/lib/navigation";
import { canWrite, displayValue, errorMessage, modules, searchPattern, type Field, type Module, type Organization, type Profile, type RecordData } from "@/lib/modules";

export type WorkspaceProps = { db: SupabaseClient; profile: Profile; organization: Organization };
const pageSize = 25;
const localDate = (input: string) => { const d = new Date(input); return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0,16); };
const today = () => localDate(new Date().toISOString()).slice(0,10);
const recordLabel = (row: RecordData) => [
  row.locker_code || row.internal_code || row.invoice_number || row.code || row.reference || "",
  row.first_name ? String(row.first_name) + " " + String(row.last_name || "") : row.full_name || row.name || row.tracking_number || "",
].filter(Boolean).join(" · ") || row.id;

function RelationPicker({ field, value, values, onChange, db, profile }: {
  field: Field; value: unknown; values: Record<string, unknown>; onChange: (value: unknown) => void;
  db: SupabaseClient; profile: Profile;
}) {
  const [query, setQuery] = useState("");
  const [rows, setRows] = useState<RecordData[]>([]);
  const [error, setError] = useState("");
  const selected = field.multiple ? (Array.isArray(value) ? value as string[] : []) : (value ? [String(value)] : []);
  const selection = selected.join(",");
  const customerId = field.table === "packages" ? String(values.customer_id || "") : "";
  const transport = ["packages", "consolidations"].includes(field.table || "") ? String(values.transport_type || "") : "";
  useEffect(() => {
    let active = true;
    const timer = window.setTimeout(async () => {
      try {
        let request = db.from(field.table!).select("*").eq("organization_id", profile.organization_id);
        if (customerId) request = request.eq("customer_id", customerId);
        if (transport) request = request.eq("transport_type", transport);
        if (["customers", "branches"].includes(field.table!)) request = request.eq("active", true);
        if (field.table === "invoices") request = request.in("status", ["PENDIENTE", "PARCIAL", "VENCIDO"]);
        const pattern = searchPattern(query);
        if (pattern) request = request.or(field.search!.map(key => key + ".ilike.%" + pattern + "%").join(","));
        const result = await request.order(field.search![0]).limit(30);
        if (result.error) throw result.error;
        let records = (result.data || []) as RecordData[];
        if (selection) {
          const chosen = await db.from(field.table!).select("*").eq("organization_id",profile.organization_id).in("id",selection.split(","));
          if (chosen.error) throw chosen.error;
          const map = new Map(records.map(row => [row.id,row]));
          (chosen.data as RecordData[] || []).forEach(row => map.set(row.id,row));
          records = [...map.values()];
        }
        if (active) { setRows(records); setError(""); }
      } catch (e) { if (active) setError(errorMessage(e)); }
    }, 250);
    return () => { active = false; window.clearTimeout(timer); };
  }, [db, field, profile.organization_id, query, selection, customerId, transport]);
  return <div className="relation-picker">
    <input aria-label={"Buscar " + field.label} value={query} onChange={e => setQuery(e.target.value)} placeholder="Escribe para buscar..." />
    {error && <p role="alert" className="error-text">{error}</p>}
    {field.multiple ? <div className="relation-options">
      <small>{selected.length} seleccionados · hasta 30 resultados por búsqueda</small>
      {rows.map(row => <label className="check-option" key={row.id}><input type="checkbox" checked={selected.includes(row.id)}
        onChange={e => onChange(e.target.checked ? [...selected,row.id] : selected.filter(id => id !== row.id))} />{recordLabel(row)}</label>)}
      {!rows.length && <p>No se encontraron registros.</p>}
    </div> : <select aria-label={field.label} required={field.required} value={String(value || "")} onChange={e => onChange(e.target.value)}>
      <option value="">Seleccionar...</option>{rows.map(row => <option key={row.id} value={row.id}>{recordLabel(row)}</option>)}
    </select>}
  </div>;
}

export function InputFields({ fields, values, setValues, db, profile }: {
  fields: Field[]; values: Record<string, unknown>; setValues: (value: Record<string, unknown>) => void;
  db: SupabaseClient; profile: Profile;
}) {
  return <div className="form-grid">{fields.map(field => {
    const value = values[field.key];
    const change = (next: unknown) => {
      const result = { ...values, [field.key]: next };
      if (["customer_id","transport_type"].includes(field.key) && "package_ids" in values) result.package_ids = [];
      setValues(result);
    };
    if (field.type === "checkbox") return <label className="check-option" key={field.key}><input type="checkbox" checked={Boolean(value)} onChange={e => change(e.target.checked)} />{field.label}</label>;
    return <div className={field.type === "textarea" || field.type === "relation" ? "field wide" : "field"} key={field.key}>
      <label htmlFor={"field-" + field.key}>{field.label}{field.required ? " *" : ""}</label>
      {field.type === "relation" ? <RelationPicker field={field} value={value} values={values} onChange={change} db={db} profile={profile} />
        : field.type === "textarea" ? <textarea id={"field-" + field.key} value={String(value || "")} maxLength={5000} onChange={e => change(e.target.value)} />
        : field.type === "select" ? <select id={"field-" + field.key} required={field.required} value={String(value ?? "")} onChange={e => change(e.target.value)}>
          {field.options?.map(option => <option key={option.value} value={option.value}>{option.label}</option>)}
        </select> : <input id={"field-" + field.key} type={field.type || "text"} required={field.required}
          min={field.min} max={field.max} step={field.step} minLength={field.type === "password" ? 12 : undefined}
          maxLength={field.type === "password" ? 128 : 500} autoComplete={field.type === "password" ? "new-password" : undefined}
          value={String(value ?? "")} onChange={e => change(e.target.value)} />}
    </div>;
  })}</div>;
}

function RecordEditor({ slug, config, record, closing, onClose, onSaved, ...context }: WorkspaceProps & {
  slug: string; config: Module; record: RecordData | null; closing?: boolean; onClose: () => void; onSaved: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  const lock = useRef(false);
  const [requestId] = useState(() => crypto.randomUUID());
  const fields = closing ? [{ key: "closing_amount", label: "Efectivo contado al cierre", type: "number", required: true, min: 0, step: "0.01" } as Field] :
    config.fields.filter(field => !(record && ["email","password"].includes(field.key)));
  const [values,setValues] = useState<Record<string,unknown>>(() => {
    const initial: Record<string,unknown> = { ...config.fixed };
    for (const field of fields) {
      let value = record?.[field.key] ?? field.default ?? (field.multiple ? [] : "");
      if (!record && field.key === "branch_id") value = context.profile.branch_id || "";
      if (field.type === "datetime-local" && value) value = localDate(String(value));
      if (field.type === "date" && !value && field.required) value = today();
      if (!record && ["locker_code","internal_code","code","reference"].includes(field.key)) value = slug.slice(0,3).toUpperCase() + "-" + requestId.slice(0,8).toUpperCase();
      initial[field.key] = value;
    }
    return initial;
  });
  const [saving,setSaving] = useState(false);
  const [error,setError] = useState("");
  useEffect(() => { dialog.current?.showModal(); }, []);
  async function submit(event: FormEvent) {
    event.preventDefault();
    if (lock.current) return;
    lock.current = true; setSaving(true); setError("");
    try {
      const payload: Record<string, unknown> = { ...config.fixed };
      for (const field of fields) {
        const value = values[field.key];
        if (field.required && (value === null || value === undefined || String(value).trim() === "" || (Array.isArray(value) && !value.length))) throw new Error("Completa: " + field.label);
        if (field.type === "number") {
          const number = Number(value);
          if (!Number.isFinite(number) || (field.min !== undefined && number < field.min) || (field.max !== undefined && number > field.max)) throw new Error("Revisa: " + field.label);
          payload[field.key] = value === "" ? null : number;
        } else if (field.type === "datetime-local") payload[field.key] = value ? new Date(String(value)).toISOString() : null;
        else payload[field.key] = typeof value === "string" ? (field.type === "password" ? value : value.trim() || null) : value;
      }
      const { db,profile } = context;
      if (slug === "usuarios" && !record) {
        const { data: { session } } = await db.auth.getSession();
        if (!session) throw new Error("La sesión venció. Ingresa nuevamente.");
        const response = await fetch("/api/users", { method: "POST", headers: { "Content-Type": "application/json", Authorization: "Bearer " + session.access_token }, body: JSON.stringify(payload) });
        const result = await response.json();
        if (!response.ok) throw new Error(result.error || "No se pudo crear el usuario.");
      } else if (config.rpc) {
        const args: Record<string,unknown> = { p_data: { ...payload,request_id: requestId },p_id: record?.id || null };
        if (config.rpc === "save_financial_record") args.p_module = slug;
        const { error } = await db.rpc(config.rpc,args);
        if (error) throw error;
      } else {
        const result = record
          ? await db.from(config.table).update(payload).eq("id",record.id).eq("organization_id",profile.organization_id).select("id").single()
          : await db.from(config.table).insert({ ...payload,id: requestId,organization_id: profile.organization_id }).select("id").single();
        if (result.error) throw result.error;
      }
      onSaved();
    } catch (e) { setError(errorMessage(e)); }
    finally { lock.current = false; setSaving(false); }
  }
  return <dialog ref={dialog} className="record-dialog" onCancel={e => { e.preventDefault(); if (!saving) onClose(); }}>
    <form className="modal" onSubmit={submit}><div className="modal-head"><h2>{closing ? "Cerrar caja" : record ? "Editar registro" : moduleMeta[slug]?.action}</h2>
      <button type="button" disabled={saving} onClick={onClose} aria-label="Cerrar"><X size={20}/></button></div>
      <div className="modal-body"><InputFields fields={fields} values={values} setValues={setValues} db={context.db} profile={context.profile} />
        {slug === "paquetes" && <p className="form-hint">El total se calcula con el peso, la tarifa de transporte y el seguro configurados.</p>}
        {error && <p className="error-box" role="alert">{error}</p>}</div>
      <div className="modal-actions"><button type="button" className="secondary-button" disabled={saving} onClick={onClose}>Cancelar</button>
        <button className="primary-button" disabled={saving}>{saving ? <LoaderCircle size={17} className="spin"/> : <Check size={17}/>} {saving ? "Guardando..." : "Guardar"}</button></div>
    </form>
  </dialog>;
}

function buildQuery(db: SupabaseClient, config: Module, org: string, query: string, from: string, to: string) {
  let request = db.from(config.table).select("*",{ count: "exact" }).eq("organization_id",org);
  if (config.fixed) request = request.match(config.fixed);
  const pattern = searchPattern(query);
  if (pattern) request = request.or(config.search.map(key => key + ".ilike.%" + pattern + "%").join(","));
  const dateColumn = config.dateColumn || "created_at";
  if (from) request = request.gte(dateColumn, dateColumn === "expense_date" ? from : new Date(from + "T00:00:00").toISOString());
  if (to) {
    if (dateColumn === "expense_date") request = request.lte(dateColumn,to);
    else { const end = new Date(to + "T00:00:00"); end.setDate(end.getDate()+1); request = request.lt(dateColumn,end.toISOString()); }
  }
  return request.order(config.order || "created_at",{ ascending: false }).order("id",{ ascending: false });
}
const withBalance = (record: RecordData): RecordData => record.total !== undefined && record.paid_amount !== undefined
  ? { ...record,balance: Number(record.total)-Number(record.paid_amount),status: record.status !== "ANULADO" && Number(record.total)>Number(record.paid_amount) && record.due_date && String(record.due_date)<today() ? "VENCIDO" : record.status } : record;

export function DataWorkspace({ slug, readOnly = false, ...context }: WorkspaceProps & { slug: string; readOnly?: boolean }) {
  const config = modules[slug];
  const [query,setQuery] = useState("");
  const [from,setFrom] = useState("");
  const [to,setTo] = useState("");
  const [page,setPage] = useState(0);
  const [rows,setRows] = useState<RecordData[]>([]);
  const [count,setCount] = useState(0);
  const [loading,setLoading] = useState(true);
  const [error,setError] = useState("");
  const [notice,setNotice] = useState("");
  const [version,setVersion] = useState(0);
  const [editor,setEditor] = useState<{ record: RecordData | null; closing?: boolean } | null>(null);
  const [exporting,setExporting] = useState(false);
  const write = !readOnly && canWrite(config,context.profile);
  useEffect(() => {
    let active = true;
    setLoading(true); setError("");
    const timer = window.setTimeout(async () => {
      try {
        if (from && to && from > to) throw new Error("La fecha inicial debe ser anterior a la final.");
        const result = await buildQuery(context.db,config,context.profile.organization_id,query,from,to).range(page*pageSize,(page+1)*pageSize-1);
        if (result.error) throw result.error;
        if (active) {
          setRows((result.data as RecordData[] || []).map(withBalance)); setCount(result.count || 0);
          if (page && !result.data?.length) setPage(Math.max(0,page-1));
        }
      } catch(e) { if(active){setRows([]);setError(errorMessage(e));} }
      finally { if(active)setLoading(false); }
    },250);
    return () => { active = false; window.clearTimeout(timer); };
  },[context.db,config,context.profile.organization_id,query,from,to,page,version]);
  async function edit(record: RecordData, closing = false) {
    setError("");
    try {
      let data = { ...record };
      if (["consolidaciones","entregas"].includes(slug)) {
        const isConsolidation = slug === "consolidaciones";
        const result = await context.db.from(isConsolidation ? "consolidation_packages" : "delivery_packages").select("package_id").eq(isConsolidation ? "consolidation_id" : "delivery_id",record.id);
        if(result.error)throw result.error;
        data = {...data,package_ids:(result.data || []).map(row => row.package_id)};
      }
      setEditor({record:data,closing});
    } catch(e){setError(errorMessage(e));}
  }
  async function exportCSV() {
    if(exporting)return;
    setExporting(true);setError("");
    try {
      const records: RecordData[] = [];
      for(let offset=0;offset<10000;offset+=500) {
        const result = await buildQuery(context.db,config,context.profile.organization_id,query,from,to).range(offset,offset+499);
        if(result.error)throw result.error;
        if((result.count || 0)>10000)throw new Error("Filtra por fechas para exportar hasta 10,000 registros.");
        records.push(...(result.data as RecordData[] || []).map(withBalance));
        if((result.data?.length || 0)<500)break;
      }
      const cell = (v:unknown) => {
        let text = v === null || v === undefined ? "" : String(v);
        if(typeof v === "string" && /^[=+@\-\t\r]/.test(text))text="'"+text;
        return '"' + text.replaceAll('"','""') + '"';
      };
      const csv = "\uFEFF" + [config.columns.map(c => cell(c.label)).join(","),...records.map(row=>config.columns.map(c=>cell(row[c.key])).join(","))].join("\r\n");
      const url=URL.createObjectURL(new Blob([csv],{type:"text/csv;charset=utf-8;"}));
      const link=document.createElement("a");link.href=url;link.download=slug+"-"+today()+".csv";link.click();
      window.setTimeout(()=>URL.revokeObjectURL(url),1000);
      setNotice("Exportados "+records.length+" registros.");
    } catch(e){setError(errorMessage(e));} finally {setExporting(false);}
  }
  const money = new Intl.NumberFormat("es-NI",{style:"currency",currency:context.organization.currency});
  function cell(row:RecordData,column:Module["columns"][number]) {
    const value=row[column.key];
    if(column.money)return value===null||value===undefined?"—":money.format(Number(value));
    if(typeof value==="string" && column.key.endsWith("_at"))return new Date(value).toLocaleString("es-NI",{timeZone:context.organization.timezone});
    if(column.key==="status")return <span className="status slate">{displayValue(value)}</span>;
    return displayValue(value);
  }
  return <>
    <section className="page-heading module-heading"><div><span className="eyebrow">{readOnly?"REPORTE":"GESTIÓN"}</span><h1>{navigation.find(item=>item.slug===slug)?.label}</h1><p>{moduleMeta[slug]?.description}</p></div>
      {write&&<button className="primary-button" onClick={()=>setEditor({record:null})}><Plus size={18}/>{moduleMeta[slug]?.action}</button>}</section>
    {error&&<p className="error-box" role="alert">{error}</p>}{notice&&<p className="success-box" role="status">{notice}</p>}
    <section className="panel module-panel"><div className="module-toolbar">
      <div className="input-search"><input aria-label="Buscar registros" placeholder="Buscar por nombre, código o referencia..." value={query} onChange={e=>{setQuery(e.target.value);setPage(0);}}/></div>
      <label className="date-filter">Desde<input type="date" value={from} onChange={e=>{setFrom(e.target.value);setPage(0);}}/></label>
      <label className="date-filter">Hasta<input type="date" value={to} onChange={e=>{setTo(e.target.value);setPage(0);}}/></label>
      <button className="secondary-button" onClick={()=>setVersion(v=>v+1)} aria-label="Actualizar"><RefreshCw size={16}/></button>
      <button className="secondary-button" disabled={exporting||loading||Boolean(error)} onClick={exportCSV}><Download size={16}/>{exporting?"Exportando...":"Exportar CSV"}</button>
    </div>
      <div className="table-summary"><span>{loading?"Consultando...":count+" registros encontrados"}</span><span>{context.organization.name}</span></div>
      {loading?<div className="empty" role="status"><LoaderCircle className="spin"/> Cargando registros...</div>:<div className="table-wrap"><table><thead><tr>
        {config.columns.map(column=><th key={column.key}>{column.label}</th>)}{write&&<th>Acciones</th>}
      </tr></thead><tbody>{rows.map(row=><tr key={row.id}>{config.columns.map(column=><td key={column.key}>{cell(row,column)}</td>)}
        {write&&<td>{(!config.noEdit||slug==="caja"&&row.status==="ABIERTA")&&<button className="secondary-button" onClick={()=>edit(row,slug==="caja")}><Pencil size={13}/>{slug==="caja"?"Cerrar caja":"Editar"}</button>}</td>}
      </tr>)}</tbody></table>{!rows.length&&!error&&<div className="empty"><h3>No hay registros</h3><p>{query||from||to?"Prueba con otros filtros.":"Crea el primer registro para comenzar."}</p></div>}</div>}
      <div className="pagination"><span>{count?("Mostrando "+(page*pageSize+1)+"–"+Math.min((page+1)*pageSize,count)+" de "+count):"0 registros"}</span>
        <div><button aria-label="Página anterior" disabled={page===0||loading} onClick={()=>setPage(p=>p-1)}><ChevronLeft size={16}/></button><button className="current">{page+1}</button>
          <button aria-label="Página siguiente" disabled={(page+1)*pageSize>=count||loading} onClick={()=>setPage(p=>p+1)}><ChevronRight size={16}/></button></div></div>
    </section>
    {editor&&<RecordEditor key={editor.record?.id || "new"} {...context} slug={slug} config={config} record={editor.record} closing={editor.closing}
      onClose={()=>setEditor(null)} onSaved={()=>{setEditor(null);setNotice("Registro guardado correctamente.");setVersion(v=>v+1);}}/>}
  </>;
}

export function Reports(context:WorkspaceProps) {
  const [slug,setSlug]=useState("paquetes");
  return <><div className="report-selector"><label>Reporte<select value={slug} onChange={e=>setSlug(e.target.value)}>
    {["paquetes","clientes","consolidaciones","entregas","cobros","cuentas-por-cobrar","gastos","caja"].map(key=><option key={key} value={key}>{navigation.find(n=>n.slug===key)?.label}</option>)}
  </select></label><span>Selecciona el período y exporta los resultados a CSV para abrirlos en Excel.</span></div><DataWorkspace key={slug} {...context} slug={slug} readOnly/></>;
}
