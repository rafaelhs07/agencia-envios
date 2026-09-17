export type RecordData = { id: string; [key: string]: unknown };
export type Profile = { id: string; organization_id: string; branch_id: string | null; full_name: string; role: string; active: boolean };
export type Organization = { id: string; name: string; currency: string; timezone: string; active: boolean; [key: string]: unknown };
export type Option = { value: string; label: string };
export type Field = {
  key: string; label: string; type?: "text" | "email" | "password" | "number" | "date" | "datetime-local" | "textarea" | "select" | "checkbox" | "relation";
  required?: boolean; options?: Option[]; default?: string | number | boolean;
  table?: string; search?: string[]; multiple?: boolean; min?: number; max?: number; step?: string;
};
export type Module = {
  table: string; columns: { key: string; label: string; money?: boolean }[];
  fields: Field[]; search: string[]; order?: string; dateColumn?: string;
  roles: string[]; fixed?: Record<string, unknown>; rpc?: string; readOnly?: boolean; noEdit?: boolean;
};
export const adminRoles = ["SUPER_ADMIN", "ADMIN"];
export const operationRoles = [...adminRoles, "OPERACIONES", "BODEGA_MIAMI", "RECEPCION"];
export const financeRoles = [...adminRoles, "CAJA"];
export const roles = [...operationRoles, "CAJA", "REPARTIDOR"];
export const choices = (values: string[]): Option[] => values.map(value => ({ value, label: value.replaceAll("_", " ") }));
const select = (key: string, label: string, values: string[], value?: string): Field => ({ key, label, type: "select", options: choices(values), default: value || values[0], required: true });
const text = (key: string, label: string, required = false): Field => ({ key, label, required });
const number = (key: string, label: string, value = 0): Field => ({ key, label, type: "number", min: 0, step: "0.01", default: value, required: true });
const relation = (key: string, label: string, table: string, search: string[], required = true, multiple = false): Field => ({ key, label, type: "relation", table, search, required, multiple });
const customer = relation("customer_id", "Cliente", "customers", ["locker_code", "first_name", "last_name"]);
const branch = relation("branch_id", "Sucursal", "branches", ["name", "code"]);
const packageList = relation("package_ids", "Paquetes", "packages", ["internal_code", "tracking_number"], true, true);
const date = (key: string, label: string): Field => ({ key, label, type: "datetime-local" });
const active: Field = { key: "active", label: "Activo", type: "checkbox", default: true };
const col = (key: string, label: string, money = false) => ({ key, label, money });
const note: Field = { key: "notes", label: "Observaciones", type: "textarea" };
export const packageStatuses = ["PRE_ALERTA", "EN_MIAMI", "CONSOLIDADO", "EN_TRANSITO", "EN_ADUANA", "RECIBIDO_NICARAGUA", "LISTO_RETIRO", "EN_REPARTO", "ENTREGADO", "INCIDENCIA", "CANCELADO"];

const shipment: Module = {
  table: "shipments", roles: operationRoles, search: ["reference", "carrier", "vessel_or_flight"],
  columns: [col("reference", "Referencia"), col("carrier", "Transportista"), col("vessel_or_flight", "Vuelo / buque"), col("status", "Estado"), col("estimated_arrival_at", "Llegada estimada")],
  fields: [text("reference", "Referencia", true), relation("consolidation_id", "Consolidación", "consolidations", ["code"], false), text("carrier", "Transportista"), text("vessel_or_flight", "Vuelo / buque"), text("master_document", "Documento principal"), text("origin", "Origen"), text("destination", "Destino"), date("departure_at", "Salida"), date("estimated_arrival_at", "Llegada estimada"), select("status", "Estado", ["PROGRAMADO", "EN_TRANSITO", "EN_ADUANA", "RECIBIDO", "CANCELADO"])]
};

export const modules: Record<string, Module> = {
  clientes: {
    table: "customers", roles: [...adminRoles, "OPERACIONES", "RECEPCION", "CAJA"], search: ["locker_code", "first_name", "last_name", "phone", "email"],
    columns: [col("locker_code", "Casillero"), col("first_name", "Nombres"), col("last_name", "Apellidos"), col("phone", "Teléfono"), col("email", "Correo"), col("active", "Activo")],
    fields: [text("locker_code", "Casillero", true), text("first_name", "Nombres", true), text("last_name", "Apellidos", true), text("phone", "Teléfono", true), text("whatsapp", "WhatsApp"), { key: "email", label: "Correo", type: "email" }, text("identification", "Identificación"), text("address", "Dirección"), { ...branch, required: false }, number("credit_limit", "Límite de crédito"), note, active]
  },
  paquetes: {
    table: "packages", roles: operationRoles, rpc: "save_package", search: ["tracking_number", "internal_code", "description", "store"],
    columns: [col("internal_code", "Código"), col("tracking_number", "Tracking"), col("description", "Descripción"), col("transport_type", "Transporte"), col("weight_lb", "Libras"), col("status", "Estado"), col("total_amount", "Total", true)],
    fields: [customer, text("tracking_number", "Tracking", true), text("internal_code", "Código interno", true), text("description", "Descripción", true), text("store", "Tienda"), text("carrier", "Transportista"), select("transport_type", "Transporte", ["AEREO", "MARITIMO"]), select("status", "Estado", packageStatuses, "EN_MIAMI"), number("weight_lb", "Peso (lb)"), number("volume_ft3", "Volumen (ft³)"), number("declared_value", "Valor declarado"), { ...branch, key: "assigned_branch_id", required: false }, text("shelf_location", "Ubicación en bodega"), note]
  },
  consolidaciones: {
    table: "consolidations", roles: operationRoles, search: ["code", "origin", "destination"], rpc: "save_consolidation",
    columns: [col("code", "Código"), col("transport_type", "Transporte"), col("status", "Estado"), col("total_weight_lb", "Libras"), col("departure_at", "Salida"), col("estimated_arrival_at", "Llegada")],
    fields: [text("code", "Código", true), select("transport_type", "Transporte", ["AEREO", "MARITIMO"]), { ...text("origin", "Origen", true), default: "Miami, FL" }, { ...text("destination", "Destino", true), default: "Managua, Nicaragua" }, select("status", "Estado", ["ABIERTA", "CERRADA", "DESPACHADA", "RECIBIDA", "CANCELADA"]), date("departure_at", "Salida"), date("estimated_arrival_at", "Llegada estimada"), packageList, note]
  },
  aereos: { ...shipment, fixed: { transport_type: "AEREO" } },
  maritimos: { ...shipment, fixed: { transport_type: "MARITIMO" } },
  "recepcion-nicaragua": {
    table: "warehouse_receptions", roles: [...adminRoles, "OPERACIONES", "RECEPCION"], search: ["code", "notes"], order: "received_at", dateColumn: "received_at", rpc: "receive_packages", noEdit: true,
    columns: [col("code", "Código"), col("packages_expected", "Esperados"), col("packages_received", "Recibidos"), col("damaged_packages", "Dañados"), col("received_at", "Fecha")],
    fields: [text("code", "Código", true), branch, relation("shipment_id", "Embarque", "shipments", ["reference"]), packageList, text("shelf_location", "Ubicación en bodega", true), { ...number("damaged_packages", "Paquetes dañados"), step: "1" }, note]
  },
  entregas: {
    table: "deliveries", roles: [...adminRoles, "OPERACIONES", "RECEPCION"], search: ["code", "recipient_name", "delivery_address"], rpc: "save_delivery",
    columns: [col("code", "Código"), col("delivery_type", "Tipo"), col("recipient_name", "Destinatario"), col("status", "Estado"), col("scheduled_at", "Programada"), col("delivered_at", "Entregada")],
    fields: [text("code", "Código", true), customer, branch, select("delivery_type", "Tipo", ["RETIRO_SUCURSAL", "DOMICILIO"]), select("status", "Estado", ["PENDIENTE", "PROGRAMADA", "EN_RUTA", "ENTREGADA", "NO_ENTREGADA", "CANCELADA"]), text("delivery_address", "Dirección de entrega"), text("recipient_name", "Nombre de quien recibe", true), date("scheduled_at", "Fecha programada"), relation("assigned_to", "Repartidor", "profiles", ["full_name"], false), packageList, note]
  },
  cobros: {
    table: "payments", roles: financeRoles, search: ["receipt_number", "reference", "method"], order: "paid_at", dateColumn: "paid_at", rpc: "save_financial_record", noEdit: true,
    columns: [col("receipt_number", "Recibo"), col("method", "Método"), col("reference", "Referencia"), col("amount", "Monto", true), col("paid_at", "Fecha")],
    fields: [relation("invoice_id", "Cuenta a cobrar", "invoices", ["invoice_number"]), branch, number("amount", "Monto del abono"), select("method", "Método", ["EFECTIVO", "TRANSFERENCIA", "TARJETA", "OTRO"]), text("reference", "Referencia del pago"), note]
  },
  "cuentas-por-cobrar": {
    table: "invoices", roles: financeRoles, search: ["invoice_number", "notes"], rpc: "save_financial_record", noEdit: true,
    columns: [col("invoice_number", "Cuenta"), col("status", "Estado"), col("total", "Total", true), col("paid_amount", "Abonado", true), col("balance", "Saldo", true), col("due_date", "Vencimiento")],
    fields: [customer, branch, relation("package_id", "Paquete a facturar (opcional)", "packages", ["internal_code", "tracking_number"], false), text("description", "Concepto", true), number("subtotal", "Subtotal (se toma del paquete si lo seleccionas)"), number("discount", "Descuento"), number("tax", "Cargo adicional"), { key: "due_date", label: "Vencimiento", type: "date" }, note]
  },
  gastos: {
    table: "expenses", roles: financeRoles, search: ["category", "description", "supplier"], dateColumn: "expense_date", rpc: "save_financial_record", noEdit: true,
    columns: [col("category", "Categoría"), col("description", "Descripción"), col("supplier", "Proveedor"), col("amount", "Monto", true), col("expense_date", "Fecha")],
    fields: [branch, text("category", "Categoría", true), text("description", "Descripción", true), text("supplier", "Proveedor"), number("amount", "Monto"), select("payment_method", "Método", ["EFECTIVO", "TRANSFERENCIA", "TARJETA", "OTRO"]), { key: "expense_date", label: "Fecha", type: "date", required: true }, note]
  },
  caja: {
    table: "cash_sessions", roles: financeRoles, search: ["status", "notes"], order: "opened_at", dateColumn: "opened_at", rpc: "save_financial_record", noEdit: true,
    columns: [col("opened_at", "Apertura"), col("status", "Estado"), col("opening_amount", "Fondo inicial", true), col("expected_amount", "Esperado al cierre", true), col("closing_amount", "Contado al cierre", true), col("difference", "Diferencia", true)],
    fields: [branch, number("opening_amount", "Fondo inicial"), note]
  },
  sucursales: {
    table: "branches", roles: adminRoles, search: ["name", "code", "city"],
    columns: [col("code", "Código"), col("name", "Nombre"), col("branch_type", "Tipo"), col("city", "Ciudad"), col("phone", "Teléfono"), col("active", "Activa")],
    fields: [text("name", "Nombre", true), text("code", "Código", true), select("branch_type", "Tipo", ["SUCURSAL", "BODEGA_MIAMI", "BODEGA_NICARAGUA"]), text("phone", "Teléfono"), text("address", "Dirección"), text("city", "Ciudad"), { ...text("country", "País", true), default: "Nicaragua" }, active]
  },
  usuarios: {
    table: "profiles", roles: adminRoles, search: ["full_name", "phone"],
    columns: [col("full_name", "Nombre"), col("role", "Rol"), col("phone", "Teléfono"), col("active", "Activo")],
    fields: [text("full_name", "Nombre completo", true), { key: "email", label: "Correo de acceso", type: "email", required: true }, { key: "password", label: "Contraseña inicial (mínimo 12 caracteres)", type: "password", required: true }, select("role", "Rol", roles.filter(role => role !== "SUPER_ADMIN")), { ...branch, required: false }, text("phone", "Teléfono"), active]
  }
};
export function canWrite(module: Module, profile: Profile) { return module.roles.includes(profile.role) && !module.readOnly; }
export function canRead(slug: string, profile: Profile) {
  if (["usuarios", "configuracion"].includes(slug)) return adminRoles.includes(profile.role);
  if (["cobros", "cuentas-por-cobrar", "gastos", "caja", "reportes"].includes(slug)) return financeRoles.includes(profile.role);
  return profile.role !== "CLIENTE";
}
export function displayValue(value: unknown): string {
  if (value === null || value === undefined || value === "") return "—";
  if (typeof value === "boolean") return value ? "Sí" : "No";
  return String(value).replaceAll("_", " ");
}
export function errorMessage(error: unknown): string {
  const e = error as { message?: string; code?: string };
  if (e?.code === "23505") return "Ya existe un registro con ese código o referencia.";
  if (e?.code === "42501") return "No tienes permisos para realizar esta operación.";
  if (e?.code === "PGRST202") return "Falta aplicar la migración 002 en Supabase.";
  return e?.message || "No se pudo completar la operación. Intenta de nuevo.";
}
export function searchPattern(value: string) {
  return value.replace(/[,%_*()"'\\]/g, " ").trim().slice(0, 100);
}
