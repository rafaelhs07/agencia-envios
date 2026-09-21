# Instalación de Supabase — agencia-envios

Verificada el 21 de septiembre de 2026.

- Organización: **rafasteel's Org** (`tqczrkmikhuxvbcjwqwo`).
- Proyecto: [agencia-envios](https://supabase.com/dashboard/project/jxgnlncoziaabdhykwpd) (`jxgnlncoziaabdhykwpd`).
- API: https://jxgnlncoziaabdhykwpd.supabase.co
- PostgreSQL 17; proyecto activo.
- Repositorio: https://github.com/rafaelhs07/agencia-envios

## Migraciones instaladas

| Archivo del repositorio | Instalación en este proyecto |
| --- | --- |
| `001_initial_schema.sql` | Ejecutado previamente desde SQL Editor; esquema comprobado antes de continuar. |
| `002_app_access_and_operations.sql` | Aplicada; versión remota `20260921210410`. |
| `20260921210806_harden_database_access.sql` | Aplicada; versión remota `20260921211011`. |

No ejecutar de nuevo estos archivos en este proyecto. Las dos primeras migraciones se conservan sin cambios. La migración adicional se creó con Supabase CLI 2.117.0.

Los nombres de versión del historial remoto y los archivos iniciales son distintos porque la instalación comenzó en SQL Editor y continuó mediante el conector. Antes de adoptar `supabase db push`, un administrador debe alinear ese historial con las migraciones del repositorio; no hacer un reset de la base. Las futuras modificaciones se agregan en migraciones nuevas y se aplican una vez.

## Verificaciones

- 20 tablas de aplicación, todas con RLS, y 28 triggers de integridad, seguimiento y auditoría.
- Funciones de paquetes, consolidaciones, recepción, entregas, configuración, cobros y caja instaladas.
- Prueba `tests/database/permissions.sql` ejecutada correctamente en el proyecto real.
- Sin acceso anónimo a las tablas ni a las operaciones de la aplicación.
- Los usuarios autenticados no pueden truncar tablas ni escribir directamente en los registros financieros.
- Funciones de triggers sin permiso de ejecución directa para `anon` o `authenticated`; rutas de búsqueda de las funciones fijadas.
- Índices para las relaciones y las consultas de agencia/caja; políticas de lectura unificadas en clientes y perfiles.
- GitHub Actions aplica las migraciones en PostgreSQL 17 y verifica los permisos y las operaciones, además de TypeScript y la compilación.

La prueba de escritura transaccional por el conector SQL no pudo ejecutarse: la consulta se abrió en modo de solo lectura. Las pruebas operativas se ejecutan en la base aislada de CI. No se ha probado todavía un inicio de sesión HTTP real.

## Avisos de Supabase revisados

No quedan avisos de acceso anónimo a funciones privilegiadas, rutas de búsqueda variables, claves foráneas sin índice o políticas de lectura duplicadas.

Quedan 10 avisos de [funciones SECURITY DEFINER accesibles a usuarios autenticados](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). Son las operaciones autorizadas y sus comprobaciones de identidad: validan el perfil activo, la agencia y el rol antes de operar. No se debe retirar su permiso de ejecución sin sustituir el flujo de la aplicación. Los triggers internos sí tienen ese permiso retirado.

También aparecen [índices sin uso registrado](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index), algo esperable antes de cargar datos. Se conservan los índices de las relaciones y consultas previstas.

## Activar el primer acceso

Al terminar la instalación no hay usuarios en Authentication ni perfiles, agencias o datos operativos cargados.

1. Abre [Authentication > Users](https://supabase.com/dashboard/project/jxgnlncoziaabdhykwpd/auth/users) y crea tu usuario, con tu correo, contraseña y Auto Confirm User.
2. Ejecuta `supabase/setup_admin.sql` en SQL Editor, cambiando `v_email` por ese correo, `v_agency` por el nombre de tu agencia y `v_slug` por un identificador sin espacios.
3. Actualiza la copia local con `git pull --ff-only` y `npm ci`.
4. Si no existe `.env.local`, copia `.env.example`. Si ya existe, actualiza solo la URL y clave publicable con los valores del ejemplo.
5. Ejecuta `npm run dev` e inicia sesión en http://localhost:3000.

El script del paso 2 crea la agencia, la sucursal principal, las tarifas iniciales y el perfil ADMIN. Revisa las tarifas en Configuración antes de comenzar a operar.

La clave publicable incluida en `.env.example` está diseñada para utilizarse en el navegador; los permisos y RLS protegen los datos. La clave privada `SUPABASE_SERVICE_ROLE_KEY` no se incluye en Git. Solo debes configurarla en el servidor si quieres crear más usuarios desde el panel.
