"use client";

import Link from "next/link";
import { useEffect, useMemo, useState } from "react";
import {
  ArrowDownRight, ArrowUpRight, Bell, Box, CalendarDays, Check, ChevronDown,
  ChevronLeft, ChevronRight, CircleDollarSign, Clock3, Download, Menu, MoreHorizontal,
  PackageCheck, PackageOpen, Plane, Plus, Search, Ship, SlidersHorizontal, Sparkles,
  TrendingUp, Truck, UserRound, Users, WalletCards, X,
} from "lucide-react";
import { moduleMeta, navigation } from "@/lib/navigation";
import { seedRows, statusOptions, type Row } from "@/lib/demo-data";

const money = new Intl.NumberFormat("es-NI", { style: "currency", currency: "USD" });

function StatusPill({ status }: { status: string }) {
  const normalized = status.toLowerCase();
  const tone = normalized.includes("tránsito") ? "blue" : normalized.includes("aduana") || normalized.includes("pendiente") || normalized.includes("vencido") ? "amber" : normalized.includes("listo") || normalized.includes("activo") || normalized.includes("pagado") || normalized.includes("entregado") || normalized.includes("abierta") ? "green" : "slate";
  return <span className={`status ${tone}`}><span />{status}</span>;
}

function Sidebar({ activeSlug, open, onClose }: { activeSlug: string; open: boolean; onClose: () => void }) {
  const groups = [...new Set(navigation.map((item) => item.group))];
  return (
    <>
      {open && <button className="sidebar-backdrop" onClick={onClose} aria-label="Cerrar menú" />}
      <aside className={`sidebar ${open ? "open" : ""}`}>
        <div className="brand"><div className="brand-mark"><Box size={23} /></div><div><strong>NexoCargo</strong><span>Logística inteligente</span></div><button className="mobile-close" onClick={onClose}><X size={20} /></button></div>
        <nav>
          {groups.map((group) => (
            <div className="nav-group" key={group}>
              <p>{group}</p>
              {navigation.filter((item) => item.group === group).map((item) => {
                const Icon = item.icon;
                return <Link className={activeSlug === item.slug ? "active" : ""} href={item.slug === "dashboard" ? "/" : `/${item.slug}`} key={item.slug} onClick={onClose}><Icon size={18} /><span>{item.label}</span>{item.slug === "cuentas-por-cobrar" && <em>3</em>}</Link>;
              })}
            </div>
          ))}
        </nav>
        <div className="sidebar-help"><Sparkles size={18} /><div><strong>Centro de ayuda</strong><span>Guías y soporte</span></div><ChevronRight size={17} /></div>
        <div className="user-card"><div className="avatar">AC</div><div><strong>Andrea Castillo</strong><span>Administradora</span></div><MoreHorizontal size={18} /></div>
      </aside>
    </>
  );
}

function Topbar({ title, onMenu }: { title: string; onMenu: () => void }) {
  return <header className="topbar"><button className="menu-button" onClick={onMenu}><Menu size={21} /></button><div className="breadcrumb"><span>Agencia</span><ChevronRight size={15} /><strong>{title}</strong></div><div className="top-actions"><button className="search-trigger"><Search size={17} /><span>Buscar en todo...</span><kbd>⌘ K</kbd></button><button className="icon-button has-dot"><Bell size={19} /></button><button className="office"><span className="office-icon">MN</span><span><small>Sucursal</small>Managua Central</span><ChevronDown size={15} /></button></div></header>;
}

const activity = [
  { icon: PackageOpen, color: "violet", title: "Nuevo paquete recibido", text: "PKG-92841 · María Fernanda López", time: "Hace 8 min" },
  { icon: Plane, color: "blue", title: "Consolidación despachada", text: "CON-A184 · 38 paquetes", time: "Hace 42 min" },
  { icon: CircleDollarSign, color: "green", title: "Pago recibido", text: "Carlos Mendoza · $49.70", time: "Hace 1 h" },
  { icon: PackageCheck, color: "amber", title: "Carga liberada de aduana", text: "Lote REC-0916-03 · 24 paquetes", time: "Hace 3 h" },
];

function Dashboard({ rows }: { rows: Record<string, Row[]> }) {
  const stats = [
    { label: "Paquetes en Miami", value: 148, change: "+12.5%", icon: PackageOpen, color: "violet", up: true },
    { label: "En tránsito", value: 83, change: "+8.2%", icon: Plane, color: "blue", up: true },
    { label: "En aduana", value: 62, change: "-4.1%", icon: Ship, color: "amber", up: false },
    { label: "Listos para retirar", value: 91, change: "+16.8%", icon: PackageCheck, color: "green", up: true },
  ];
  const max = 180;
  const chart = [86, 112, 98, 131, 118, 154, 139, 171, 148, 164, 176, 151];
  return <>
    <section className="page-heading"><div><span className="eyebrow">JUEVES, 17 DE SEPTIEMBRE</span><h1>Buenos días, Andrea <span>👋</span></h1><p>Aquí tienes el resumen de la operación de tu agencia.</p></div><div className="heading-actions"><button className="secondary-button"><Download size={17} />Exportar</button><Link href="/paquetes" className="primary-button"><Plus size={18} />Registrar paquete</Link></div></section>
    <section className="stat-grid">{stats.map(({ label, value, change, icon: Icon, color, up }) => <article className="stat-card" key={label}><div className={`stat-icon ${color}`}><Icon size={21} /></div><div className="stat-top"><span>{label}</span><MoreHorizontal size={18} /></div><strong>{value}</strong><div className="stat-foot">{up ? <ArrowUpRight size={15} /> : <ArrowDownRight size={15} />}<b className={up ? "positive" : "negative"}>{change}</b><span>vs. mes anterior</span></div></article>)}</section>
    <section className="dashboard-grid">
      <article className="panel chart-panel"><div className="panel-title"><div><h2>Flujo de paquetes</h2><p>Paquetes recibidos durante los últimos 12 días</p></div><button className="select-button"><CalendarDays size={16} />Últimos 12 días<ChevronDown size={15} /></button></div><div className="chart-summary"><div><strong>1,648</strong><span>Paquetes totales</span></div><div className="legend"><span><i className="purple-dot" />Aéreo 1,172</span><span><i className="blue-dot" />Marítimo 476</span></div></div><div className="bar-chart">{chart.map((value, index) => <div className="bar-col" key={index}><div className="bar-stack" title={`${value} paquetes`}><span style={{ height: `${(value / max) * 72}%` }} /><i style={{ height: `${(value / max) * 28}%` }} /></div><small>{index + 6}</small></div>)}</div>
      </article>
      <article className="panel activity-panel"><div className="panel-title"><div><h2>Actividad reciente</h2><p>Últimos movimientos del sistema</p></div><button className="text-button">Ver todo</button></div><div className="activity-list">{activity.map(({ icon: Icon, color, title, text, time }) => <div className="activity" key={title}><div className={`activity-icon ${color}`}><Icon size={17} /></div><div><strong>{title}</strong><span>{text}</span></div><time>{time}</time></div>)}</div></article>
    </section>
    <section className="panel recent-panel"><div className="panel-title"><div><h2>Paquetes recientes</h2><p>Últimos paquetes registrados en Miami</p></div><Link className="text-button" href="/paquetes">Ver todos <ChevronRight size={16} /></Link></div><DataTable rows={rows.paquetes || []} compact /></section>
    <section className="mini-grid"><div><div className="mini-icon green"><CircleDollarSign size={19} /></div><span>Ingresos del mes</span><strong>$12,840.60</strong><small className="positive">↑ 14.2% este mes</small></div><div><div className="mini-icon violet"><Users size={19} /></div><span>Clientes activos</span><strong>1,284</strong><small className="positive">↑ 38 nuevos</small></div><div><div className="mini-icon blue"><TrendingUp size={19} /></div><span>Tasa de entregas</span><strong>96.8%</strong><small className="positive">↑ 2.4% este mes</small></div><div><div className="mini-icon amber"><Clock3 size={19} /></div><span>Tiempo promedio</span><strong>5.2 días</strong><small>Meta: 5 días</small></div></section>
  </>;
}

function DataTable({ rows, compact = false, onStatus, onDelete }: { rows: Row[]; compact?: boolean; onStatus?: (id: string, status: string) => void; onDelete?: (id: string) => void }) {
  if (!rows.length) return <div className="empty"><PackageOpen size={32} /><h3>No hay registros</h3><p>Crea el primer registro para comenzar.</p></div>;
  return <div className="table-wrap"><table><thead><tr><th>Detalle</th><th>Referencia</th><th>{compact ? "Ruta" : "Fecha / información"}</th><th>Estado</th><th className="right">Monto</th>{!compact && <th />}</tr></thead><tbody>{rows.map((row) => <tr key={row.id}><td><div className="package-cell"><span className="package-box"><Box size={18} /></span><div><strong>{row.primary}</strong><small>{row.secondary}</small></div></div></td><td><button className="reference">{row.reference}</button></td><td><span className="muted">{compact ? row.route || row.date : row.date}</span></td><td>{onStatus ? <select className="status-select" value={row.status} onChange={(e) => onStatus(row.id, e.target.value)}>{[...new Set([...statusOptions, row.status, "Pagado", "Vencido", "Abierta"])].map((s) => <option key={s}>{s}</option>)}</select> : <StatusPill status={row.status} />}</td><td className="right amount">{row.amount !== undefined ? money.format(row.amount) : "—"}</td>{!compact && <td className="right"><button className="row-menu" onClick={() => onDelete?.(row.id)} title="Eliminar"><MoreHorizontal size={18} /></button></td>}</tr>)}</tbody></table></div>;
}

function EmptySpecial({ slug }: { slug: string }) {
  if (slug === "reportes") return <div className="report-grid">{["Operación de paquetes", "Ingresos y cobros", "Cuentas por cobrar", "Rentabilidad por ruta", "Clientes frecuentes", "Gastos por categoría"].map((name, index) => <article className="report-card" key={name}><div className={`report-icon c${index}`}><TrendingUp size={21} /></div><div><h3>{name}</h3><p>Resumen actualizado y exportable por período.</p></div><button><Download size={17} /></button></article>)}</div>;
  if (slug === "configuracion") return <div className="settings-grid"><section className="settings-card"><h3>Datos de la agencia</h3><div className="form-grid"><label>Nombre comercial<input defaultValue="NexoCargo Nicaragua" /></label><label>RUC<input defaultValue="J0310000421987" /></label><label>Teléfono<input defaultValue="+505 2222-4800" /></label><label>Correo<input defaultValue="operaciones@nexocargo.com" /></label><label className="wide">Dirección<input defaultValue="Managua, Nicaragua" /></label></div></section><section className="settings-card"><h3>Tarifas predeterminadas</h3><div className="form-grid"><label>Aéreo por libra<input type="number" defaultValue="7.00" /></label><label>Marítimo por libra<input type="number" defaultValue="3.50" /></label><label>Seguro (%)<input type="number" defaultValue="2" /></label><label>Moneda<select defaultValue="USD"><option>USD</option><option>NIO</option></select></label></div></section><section className="settings-card wide-card"><h3>Tracking del cliente</h3><div className="toggle-row"><div><strong>Portal de clientes</strong><span>Base preparada para habilitar casillero y tracking en una siguiente etapa.</span></div><button className="toggle on"><span /></button></div><div className="toggle-row"><div><strong>Notificaciones automáticas</strong><span>Avisos cuando un paquete cambia de estado.</span></div><button className="toggle on"><span /></button></div></section></div>;
  return null;
}

function ModuleView({ slug, rows, onAdd, onStatus, onDelete }: { slug: string; rows: Row[]; onAdd: () => void; onStatus: (id: string, status: string) => void; onDelete: (id: string) => void }) {
  const meta = moduleMeta[slug];
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState("Todos");
  const filtered = rows.filter((row) => (`${row.primary} ${row.secondary} ${row.reference}`).toLowerCase().includes(query.toLowerCase()) && (filter === "Todos" || row.status === filter));
  const special = slug === "reportes" || slug === "configuracion";
  return <><section className="page-heading module-heading"><div><span className="eyebrow">GESTIÓN</span><h1>{navigation.find((n) => n.slug === slug)?.label}</h1><p>{meta.description}</p></div><button className="primary-button" onClick={onAdd}>{slug === "reportes" ? <Download size={18} /> : slug === "configuracion" ? <Check size={18} /> : <Plus size={18} />}{meta.action}</button></section>{special ? <EmptySpecial slug={slug} /> : <section className="panel module-panel"><div className="module-toolbar"><div className="input-search"><Search size={17} /><input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Buscar por nombre, referencia o detalle..." /></div><select value={filter} onChange={(e) => setFilter(e.target.value)}><option>Todos</option>{[...new Set(rows.map((r) => r.status))].map((s) => <option key={s}>{s}</option>)}</select><button className="filter-button"><SlidersHorizontal size={17} />Filtros</button><button className="secondary-button"><Download size={17} />Exportar</button></div><div className="table-summary"><span><strong>{filtered.length}</strong> registros encontrados</span><span>Información actualizada ahora</span></div><DataTable rows={filtered} onStatus={onStatus} onDelete={onDelete} /><div className="pagination"><span>Mostrando 1–{filtered.length} de {filtered.length}</span><div><button disabled><ChevronLeft size={16} /></button><button className="current">1</button><button disabled><ChevronRight size={16} /></button></div></div></section>}</>;
}

function CreateModal({ slug, onClose, onSave }: { slug: string; onClose: () => void; onSave: (row: Row) => void }) {
  const label = navigation.find((n) => n.slug === slug)?.label || "registro";
  const [form, setForm] = useState({ primary: "", secondary: "", reference: "", status: slug === "clientes" ? "Activo" : "Pendiente", amount: "" });
  const submit = (event: React.FormEvent) => { event.preventDefault(); onSave({ id: crypto.randomUUID(), primary: form.primary, secondary: form.secondary || "Sin información adicional", reference: form.reference || `${slug.slice(0, 3).toUpperCase()}-${Date.now().toString().slice(-6)}`, date: new Date().toLocaleDateString("es-NI", { day: "2-digit", month: "short", year: "numeric" }), status: form.status, amount: form.amount ? Number(form.amount) : undefined }); };
  return <div className="modal-layer" onMouseDown={(e) => e.target === e.currentTarget && onClose()}><form className="modal" onSubmit={submit}><div className="modal-head"><div><span className="eyebrow">NUEVO REGISTRO</span><h2>Agregar en {label}</h2></div><button type="button" onClick={onClose}><X size={20} /></button></div><div className="modal-body"><label>Nombre o detalle principal<input required autoFocus value={form.primary} onChange={(e) => setForm({ ...form, primary: e.target.value })} placeholder="Ej. María López / Paquete Amazon" /></label><label>Información adicional<input value={form.secondary} onChange={(e) => setForm({ ...form, secondary: e.target.value })} placeholder="Teléfono, peso, método..." /></label><div className="form-row"><label>Referencia<input value={form.reference} onChange={(e) => setForm({ ...form, reference: e.target.value })} placeholder="Se genera automáticamente" /></label><label>Estado<select value={form.status} onChange={(e) => setForm({ ...form, status: e.target.value })}>{statusOptions.map((s) => <option key={s}>{s}</option>)}</select></label></div><label>Monto (USD)<input type="number" min="0" step="0.01" value={form.amount} onChange={(e) => setForm({ ...form, amount: e.target.value })} placeholder="0.00" /></label></div><div className="modal-actions"><button type="button" className="secondary-button" onClick={onClose}>Cancelar</button><button className="primary-button"><Check size={17} />Guardar registro</button></div></form></div>;
}

export function AppShell({ activeSlug }: { activeSlug: string }) {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [modalOpen, setModalOpen] = useState(false);
  const [toast, setToast] = useState("");
  const [rows, setRows] = useState<Record<string, Row[]>>(seedRows);
  useEffect(() => { const saved = localStorage.getItem("nexocargo-data"); if (saved) { try { setRows(JSON.parse(saved)); } catch {} } }, []);
  const saveRows = (next: Record<string, Row[]>) => { setRows(next); localStorage.setItem("nexocargo-data", JSON.stringify(next)); };
  const notify = (message: string) => { setToast(message); window.setTimeout(() => setToast(""), 2800); };
  const title = useMemo(() => navigation.find((n) => n.slug === activeSlug)?.label || "Dashboard", [activeSlug]);
  const addRow = (row: Row) => { saveRows({ ...rows, [activeSlug]: [row, ...(rows[activeSlug] || [])] }); setModalOpen(false); notify("Registro guardado correctamente"); };
  const changeStatus = (id: string, status: string) => { saveRows({ ...rows, [activeSlug]: (rows[activeSlug] || []).map((r) => r.id === id ? { ...r, status } : r) }); notify("Estado actualizado"); };
  const deleteRow = (id: string) => { if (!window.confirm("¿Deseas eliminar este registro?")) return; saveRows({ ...rows, [activeSlug]: (rows[activeSlug] || []).filter((r) => r.id !== id) }); notify("Registro eliminado"); };
  const handleAction = () => { if (activeSlug === "configuracion") return notify("Configuración guardada"); if (activeSlug === "reportes") return notify("Reporte preparado para exportar"); setModalOpen(true); };
  return <div className="app"><Sidebar activeSlug={activeSlug} open={sidebarOpen} onClose={() => setSidebarOpen(false)} /><div className="content-shell"><Topbar title={title} onMenu={() => setSidebarOpen(true)} /><main>{activeSlug === "dashboard" ? <Dashboard rows={rows} /> : <ModuleView slug={activeSlug} rows={rows[activeSlug] || []} onAdd={handleAction} onStatus={changeStatus} onDelete={deleteRow} />}</main></div>{modalOpen && <CreateModal slug={activeSlug} onClose={() => setModalOpen(false)} onSave={addRow} />}{toast && <div className="toast"><Check size={18} />{toast}</div>}</div>;
}
