export type Row = {
  id: string;
  primary: string;
  secondary: string;
  reference: string;
  date: string;
  amount?: number;
  status: string;
  route?: string;
};

export const statusOptions = ["En Miami", "En tránsito", "En aduana", "Listo para retirar", "Entregado", "Pendiente", "Activo"];

export const seedRows: Record<string, Row[]> = {
  clientes: [
    { id: "1", primary: "María Fernanda López", secondary: "maria.lopez@email.com · 8888-1204", reference: "MIA-10428", date: "17 sep 2026", status: "Activo", amount: 0 },
    { id: "2", primary: "Carlos Mendoza", secondary: "carlos.m@email.com · 7754-0911", reference: "MIA-10396", date: "16 sep 2026", status: "Activo", amount: 128.5 },
    { id: "3", primary: "Ana Lucía Ruiz", secondary: "ana.ruiz@email.com · 8241-7782", reference: "MIA-10372", date: "15 sep 2026", status: "Pendiente", amount: 49.75 },
    { id: "4", primary: "José Martínez", secondary: "jose.m@email.com · 8912-3301", reference: "MIA-10318", date: "14 sep 2026", status: "Activo", amount: 0 },
  ],
  paquetes: [
    { id: "1", primary: "Amazon · Audífonos inalámbricos", secondary: "María F. López · 2.4 lb", reference: "PKG-92841", date: "Hoy, 9:42 AM", status: "En Miami", route: "Miami → Managua", amount: 16.8 },
    { id: "2", primary: "Shein · Ropa y accesorios", secondary: "Carlos Mendoza · 7.1 lb", reference: "PKG-92840", date: "Hoy, 8:18 AM", status: "En tránsito", route: "Miami → Managua", amount: 49.7 },
    { id: "3", primary: "eBay · Repuesto automotriz", secondary: "Ana Lucía Ruiz · 12.8 lb", reference: "PKG-92839", date: "Ayer, 4:31 PM", status: "En aduana", route: "Miami → Managua", amount: 89.6 },
    { id: "4", primary: "Apple · MacBook Air", secondary: "José Martínez · 4.6 lb", reference: "PKG-92838", date: "Ayer, 1:07 PM", status: "Listo para retirar", route: "Miami → León", amount: 35.2 },
    { id: "5", primary: "Temu · Artículos del hogar", secondary: "Sofía Blandón · 9.3 lb", reference: "PKG-92837", date: "15 sep, 5:20 PM", status: "Entregado", route: "Miami → Estelí", amount: 65.1 },
  ],
  consolidaciones: [
    { id: "1", primary: "Consolidado aéreo #A-184", secondary: "38 paquetes · 216.7 lb", reference: "CON-A184", date: "Sale 18 sep", status: "En tránsito", route: "MIA → MGA" },
    { id: "2", primary: "Consolidado marítimo #M-061", secondary: "74 paquetes · 18.4 ft³", reference: "CON-M061", date: "Sale 21 sep", status: "En Miami", route: "MIA → COR" },
  ],
  aereos: [
    { id: "1", primary: "Vuelo AV-451", secondary: "Avianca Cargo · 216.7 lb", reference: "AWB-134-908251", date: "18 sep 2026", status: "En tránsito", route: "MIA → MGA" },
    { id: "2", primary: "Vuelo CM-823", secondary: "Copa Cargo · 184.2 lb", reference: "AWB-230-118407", date: "20 sep 2026", status: "Pendiente", route: "MIA → PTY → MGA" },
  ],
  maritimos: [
    { id: "1", primary: "Contenedor TGHU-772190", secondary: "Seaboard · 18.4 ft³", reference: "BL-2026-0914", date: "ETA 28 sep", status: "En tránsito", route: "Miami → Corinto" },
  ],
  "recepcion-nicaragua": [
    { id: "1", primary: "Lote REC-0917-01", secondary: "31 de 38 paquetes procesados", reference: "REC-20260917", date: "Hoy, 10:15 AM", status: "Pendiente", route: "Bodega Managua" },
  ],
  entregas: [
    { id: "1", primary: "María Fernanda López", secondary: "Retiro en sucursal · 2 paquetes", reference: "ENT-18042", date: "Hoy, 2:00 PM", status: "Listo para retirar", route: "Managua Central" },
    { id: "2", primary: "Roberto Sánchez", secondary: "Entrega a domicilio · 1 paquete", reference: "ENT-18041", date: "Hoy, 4:30 PM", status: "En tránsito", route: "Carretera Masaya" },
  ],
  cobros: [
    { id: "1", primary: "María Fernanda López", secondary: "Efectivo · Recibo #004821", reference: "COB-4821", date: "Hoy, 10:02 AM", status: "Pagado", amount: 35.2 },
    { id: "2", primary: "Carlos Mendoza", secondary: "Transferencia BAC · Recibo #004820", reference: "COB-4820", date: "Ayer, 3:44 PM", status: "Pagado", amount: 49.7 },
  ],
  "cuentas-por-cobrar": [
    { id: "1", primary: "Carlos Mendoza", secondary: "2 paquetes pendientes", reference: "CXC-2190", date: "Vence 22 sep", status: "Pendiente", amount: 128.5 },
    { id: "2", primary: "Ana Lucía Ruiz", secondary: "1 paquete pendiente", reference: "CXC-2187", date: "Venció 15 sep", status: "Vencido", amount: 49.75 },
  ],
  gastos: [
    { id: "1", primary: "Transporte aduanero", secondary: "Logística · Managua", reference: "GAS-9031", date: "Hoy", status: "Pagado", amount: 185 },
    { id: "2", primary: "Alquiler bodega Miami", secondary: "Operación · Miami", reference: "GAS-9030", date: "15 sep 2026", status: "Pagado", amount: 850 },
  ],
  caja: [
    { id: "1", primary: "Caja Managua Central", secondary: "Abierta por Andrea Castillo", reference: "CAJ-0917-A", date: "Hoy, 8:01 AM", status: "Abierta", amount: 1342.6 },
  ],
  sucursales: [
    { id: "1", primary: "Managua Central", secondary: "Rotonda El Güegüense, 2c al sur", reference: "SUC-001", date: "Lun–Sáb 8:00–17:30", status: "Activo" },
    { id: "2", primary: "León", secondary: "Del parque central 3c al norte", reference: "SUC-002", date: "Lun–Sáb 8:00–17:00", status: "Activo" },
    { id: "3", primary: "Miami Warehouse", secondary: "Doral, FL 33172", reference: "SUC-MIA", date: "Lun–Vie 9:00–18:00", status: "Activo" },
  ],
  usuarios: [
    { id: "1", primary: "Andrea Castillo", secondary: "andrea@nexocargo.com · Administradora", reference: "USR-001", date: "Activo ahora", status: "Activo" },
    { id: "2", primary: "Luis Herrera", secondary: "luis@nexocargo.com · Bodega Miami", reference: "USR-002", date: "Hace 18 min", status: "Activo" },
    { id: "3", primary: "Karla Pérez", secondary: "karla@nexocargo.com · Caja", reference: "USR-003", date: "Ayer", status: "Activo" },
  ],
};
