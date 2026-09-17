import {
  Boxes, Building2, CircleDollarSign, ClipboardList, Container, CreditCard,
  FileChartColumn, Gauge, HandCoins, Landmark, PackageCheck, PackageOpen,
  Plane, ReceiptText, Settings, Ship, Store, Truck, Users, WalletCards,
  type LucideIcon,
} from "lucide-react";

export type NavItem = { slug: string; label: string; icon: LucideIcon; group: string };

export const navigation: NavItem[] = [
  { slug: "dashboard", label: "Dashboard", icon: Gauge, group: "General" },
  { slug: "clientes", label: "Clientes", icon: Users, group: "Operaciones" },
  { slug: "paquetes", label: "Paquetes", icon: PackageOpen, group: "Operaciones" },
  { slug: "consolidaciones", label: "Consolidaciones", icon: Container, group: "Operaciones" },
  { slug: "aereos", label: "Aéreos", icon: Plane, group: "Logística" },
  { slug: "maritimos", label: "Marítimos", icon: Ship, group: "Logística" },
  { slug: "recepcion-nicaragua", label: "Recepción Nicaragua", icon: PackageCheck, group: "Logística" },
  { slug: "entregas", label: "Entregas", icon: Truck, group: "Logística" },
  { slug: "cobros", label: "Cobros", icon: CircleDollarSign, group: "Finanzas" },
  { slug: "cuentas-por-cobrar", label: "Cuentas por cobrar", icon: HandCoins, group: "Finanzas" },
  { slug: "gastos", label: "Gastos", icon: ReceiptText, group: "Finanzas" },
  { slug: "caja", label: "Caja", icon: Landmark, group: "Finanzas" },
  { slug: "reportes", label: "Reportes", icon: FileChartColumn, group: "Análisis" },
  { slug: "sucursales", label: "Sucursales", icon: Store, group: "Administración" },
  { slug: "usuarios", label: "Usuarios", icon: Building2, group: "Administración" },
  { slug: "configuracion", label: "Configuración", icon: Settings, group: "Administración" },
];

export const moduleMeta: Record<string, { description: string; action: string; icon: LucideIcon }> = {
  clientes: { description: "Administra clientes, casilleros, contacto y estado de cuenta.", action: "Nuevo cliente", icon: Users },
  paquetes: { description: "Controla cada paquete desde Miami hasta su entrega final.", action: "Registrar paquete", icon: Boxes },
  consolidaciones: { description: "Agrupa paquetes y prepara despachos internacionales.", action: "Nueva consolidación", icon: ClipboardList },
  aereos: { description: "Gestiona guías, vuelos, manifiestos y carga aérea.", action: "Nuevo vuelo", icon: Plane },
  maritimos: { description: "Gestiona contenedores, navieras y carga marítima.", action: "Nuevo embarque", icon: Ship },
  "recepcion-nicaragua": { description: "Recibe, inspecciona y ubica paquetes en bodega.", action: "Registrar recepción", icon: PackageCheck },
  entregas: { description: "Coordina retiros en sucursal y entregas a domicilio.", action: "Nueva entrega", icon: Truck },
  cobros: { description: "Registra pagos, métodos y comprobantes de clientes.", action: "Registrar cobro", icon: CreditCard },
  "cuentas-por-cobrar": { description: "Da seguimiento a saldos pendientes y vencimientos.", action: "Nueva cuenta", icon: WalletCards },
  gastos: { description: "Controla gastos operativos por categoría y sucursal.", action: "Registrar gasto", icon: ReceiptText },
  caja: { description: "Aperturas, movimientos y cierres de caja diarios.", action: "Abrir caja", icon: Landmark },
  reportes: { description: "Indicadores operativos, financieros y exportaciones.", action: "Exportar reporte", icon: FileChartColumn },
  sucursales: { description: "Configura sedes, bodegas, horarios y responsables.", action: "Nueva sucursal", icon: Store },
  usuarios: { description: "Gestiona accesos, roles y permisos del equipo.", action: "Nuevo usuario", icon: Users },
  configuracion: { description: "Datos de la agencia, tarifas, tracking y preferencias.", action: "Guardar cambios", icon: Settings },
};
