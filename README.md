# NexoCargo — Sistema para agencia de envíos

Panel administrativo escalable para gestionar la operación completa de una agencia de paquetería entre Miami y Nicaragua.

## Módulos incluidos

- Dashboard operativo y financiero.
- Clientes y casilleros.
- Paquetes con tracking y cambio de estado.
- Consolidaciones aéreas y marítimas.
- Recepción en Nicaragua y ubicación en bodega.
- Entregas en sucursal o domicilio.
- Cobros, cuentas por cobrar, gastos y caja.
- Reportes, sucursales, usuarios y configuración.
- Esquema multiagencia preparado para un portal futuro de clientes.

La interfaz inicia con datos de demostración y guarda cambios en el navegador. El esquema de producción para Supabase se encuentra en `supabase/migrations/001_initial_schema.sql`.

## Ejecutar en Windows (CMD)

```cmd
git clone https://github.com/rafaelhs07/agencia-envios.git
cd agencia-envios
npm install
npm run dev
```

Abrir `http://localhost:3000`.

## Conectar Supabase

1. Crear un proyecto en Supabase.
2. Abrir **SQL Editor**, copiar el contenido de `supabase/migrations/001_initial_schema.sql` y ejecutarlo.
3. Copiar `.env.example` como `.env.local`.
4. Colocar `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_ANON_KEY` desde **Project Settings > API**.
5. Reiniciar `npm run dev`.

## Arquitectura

- Next.js App Router + TypeScript.
- Diseño responsivo sin dependencia de un kit visual.
- Supabase Auth + PostgreSQL + Row Level Security.
- Separación por `organization_id` para soportar varias agencias.
- Roles operativos y rol `CLIENTE` reservado para el portal.
- Historial de eventos separado de paquetes para un tracking auditable.

## Próxima etapa

La base queda preparada para reemplazar el almacenamiento de demostración por consultas de Supabase, activar autenticación, emitir recibos PDF, enviar notificaciones por WhatsApp/correo y habilitar el portal del cliente.
