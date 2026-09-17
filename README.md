# NexoCargo — Agencia de envíos

Sistema administrativo para una agencia entre Miami y Nicaragua. Repositorio de trabajo: https://github.com/rafaelhs07/agencia-envios.

## Estado actual

La aplicación utiliza Supabase Auth y PostgreSQL. Los registros se consultan y guardan en la base de datos de la agencia; no se cargan cifras ficticias ni se guardan operaciones en localStorage.

- Inicio de sesión, cierre de sesión y bloqueo de perfiles o agencias inactivos.
- Dashboard con conteos, cobros, gastos y saldos reales.
- Clientes, casilleros, sucursales y usuarios.
- Paquetes con tarifa y seguro calculados en PostgreSQL e historial de estados.
- Consolidaciones con selección de paquetes; embarques aéreos y marítimos.
- Recepciones en Nicaragua y entregas asociadas a paquetes.
- Cuentas, abonos parciales, gastos y apertura/cierre de caja.
- Operaciones de dinero atómicas: no se permiten sobrepagos y el efectivo requiere caja abierta.
- Búsqueda, paginación y reportes CSV con filtro de fechas.
- Separación por agencia y permisos de operación mediante RLS.

## Instalacion

Requiere Node.js 22 LTS y un proyecto Supabase.

### 1. Descargar en CMD

Si es la primera descarga:

~~~cmd
git clone https://github.com/rafaelhs07/agencia-envios.git
cd agencia-envios
npm ci
~~~

Si ya tienes una copia con Git, entra en la carpeta que contiene package.json y ejecuta:

~~~cmd
git status
git pull --ff-only
npm ci
~~~

Si descargaste un ZIP, clona el repositorio en una carpeta nueva para disponer de Git. Conserva tu .env.local y cópialo a la carpeta nueva.

### 2. Preparar la base de datos

En Supabase > SQL Editor ejecuta, en orden:

1. supabase/migrations/001_initial_schema.sql, solo si aún no lo ejecutaste.
2. supabase/migrations/002_app_access_and_operations.sql.

Las migraciones se ejecutan una sola vez por base de datos. La 002 reemplaza las políticas iniciales y agrega funciones y validaciones. Ejecutarla no conecta automáticamente las credenciales de tu computadora.

### 3. Configurar el entorno

~~~cmd
copy .env.example .env.local
notepad .env.local
~~~

Completa NEXT_PUBLIC_SUPABASE_URL y NEXT_PUBLIC_SUPABASE_ANON_KEY. También se admite NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY en lugar de la clave anon.

SUPABASE_SERVICE_ROLE_KEY solo es necesaria para que un administrador cree nuevos usuarios desde /usuarios. Es una clave privada de servidor: nunca debe llevar NEXT_PUBLIC_ ni publicarse en GitHub. .env.local está excluido de Git.

Obtén la URL y la clave pública desde Connect o Settings > API Keys de tu proyecto Supabase. La clave service_role se encuentra entre las claves privadas/legacy. No compartas contraseñas ni claves privadas en el chat.

### 4. Crear el primer administrador

1. En Supabase, abre Authentication > Users > Add user > Create new user.
2. Escribe tu correo y contraseña y activa Auto Confirm User.
3. Abre supabase/setup_admin.sql y reemplaza v_email, v_agency y v_slug.
4. Ejecuta ese archivo en SQL Editor. No incluye contraseñas y solo debe ejecutarlo quien administra la base.

El script crea la agencia, la sucursal principal, las tarifas y el perfil ADMIN. No cambia de agencia a usuarios existentes.

### 5. Iniciar

~~~cmd
npm run dev
~~~

Abre http://localhost:3000 e ingresa con el usuario creado. Si cambias .env.local, detén el servidor con Ctrl+C y vuelve a iniciarlo.

## Primera operación

1. Revisa nombre, moneda, tarifas y seguro en Configuración. La moneda queda fija cuando existen operaciones.
2. Registra un cliente y su casillero.
3. Registra un paquete en Miami con su peso; el sistema calcula el servicio.
4. Agrupa paquetes del mismo transporte en una consolidación y despáchala.
5. Crea un embarque asociado a esa consolidación.
6. Registra la recepción de sus paquetes y su ubicación en Nicaragua.
7. Tras inspeccionarlos, cambia los paquetes a LISTO_RETIRO.
8. Crea una cuenta para el cliente y elige el paquete a facturar, o registra un concepto independiente.
9. Abre caja si vas a recibir efectivo. Registra uno o varios abonos; el saldo se actualiza en la misma operación.
10. Crea la entrega y selecciona sus paquetes. Si el crédito está desactivado, deben estar pagados para salir a reparto o entregarse.
11. Al terminar, cierra la caja con el efectivo contado. El sistema calcula lo esperado y la diferencia.

Los pagos con métodos distintos se registran como abonos separados a la misma cuenta. Los registros financieros se conservan: esta versión no incluye anulación/reversión de cobros ni gastos. No edites importes manualmente en las tablas.

## Permisos

- ADMIN / SUPER_ADMIN: administración y operación de su agencia.
- OPERACIONES: clientes, paquetes y logística.
- BODEGA_MIAMI: paquetes, consolidaciones y embarques.
- RECEPCION: clientes, paquetes, logística y entregas.
- CAJA: clientes, cuentas, cobros, gastos, caja y reportes.
- REPARTIDOR: consulta operativa.
- CLIENTE: reservado para un portal futuro; sin acceso al panel.

Cada cuenta pertenece a una agencia. El rol SUPER_ADMIN no elimina el aislamiento por agencia.

## Verificación

~~~cmd
npm run typecheck
npm run build
~~~

GitHub Actions ejecuta TypeScript, compilación y pruebas de PostgreSQL sobre una base de prueba. Las pruebas verifican aislamiento de agencias, roles, tarifas, abonos, reintentos, sobrepagos, caja y logística.

La base de prueba simula auth.users y auth.uid; no reemplaza una prueba de inicio de sesión real en tu proyecto Supabase.

## Pendiente de etapas posteriores

Recibos PDF, notificaciones por WhatsApp/correo, archivos/fotografías, portal del cliente, reversión de operaciones financieras y reglas más detalladas por sucursal. Los botones de esta versión ejecutan las operaciones descritas arriba.

## Desarrollo

Los cambios se publican en este repositorio mediante commits y ramas. Cada migración nueva se agrega en un archivo separado; no se modifica una migración ya aplicada. No se incluyen credenciales ni datos privados en los commits.
