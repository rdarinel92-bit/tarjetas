# PLAN DE CONEXIÓN DE DATOS, PRUEBAS, OPTIMIZACIÓN Y MANUAL OPERATIVO

## SECCIÓN 1 — PLAN DE CONEXIÓN DE DATOS (PASO A PASO)

1. MODELOS Y REPOSITORIOS
- Verificar que todos los modelos Dart coinciden con las tablas de Supabase.
- Verificar que todos los repositorios usan los nombres de tablas correctos.
- Verificar que no hay campos extra ni faltantes.

2. CONFIGURAR CLIENTE SUPABASE
- Confirmar archivo de configuración (por ejemplo: /lib/core/supabase_client.dart).
- Verificar URL y KEY de Supabase (variables de entorno).
- Probar conexión simple: listar un registro de una tabla pequeña (ej. perfiles).

3. CONECTAR MÓDULO POR MÓDULO
Orden recomendado:
  a) Clientes
  b) Avales
  c) Préstamos
  d) Tandas
  e) Pagos
  f) Documentos
  g) Comprobantes
  h) Chat
  i) Auditoría
  j) Inventario
  k) Facturación
  l) Entregas

Para cada módulo:
- Conectar la pantalla de listado al repositorio (getAll / getByFilter).
- Conectar la pantalla de detalle al repositorio (getById).
- Conectar botones de crear/editar/eliminar a métodos del repositorio.
- Manejar estados de carga (loading), éxito y error.

4. VALIDAR RLS Y PERMISOS
- Probar que cada consulta respeta RLS.
- Probar que cada rol solo ve lo que debe ver.
- Probar que las mutaciones fallan si el usuario no tiene permiso.

5. PRUEBA DE CONEXIÓN COMPLETA
- Crear un cliente desde la UI.
- Verificar que aparece en Supabase.
- Crear un préstamo desde la UI.
- Verificar que aparece en Supabase.
- Registrar un pago desde la UI.
- Verificar que aparece en Supabase.

---

## SECCIÓN 2 — PLAN DE PRUEBAS REALES (END-TO-END)

OBJETIVO:
Simular el uso real del sistema como si ya estuviera en producción.

ESCENARIO 1 — CLIENTE + PRÉSTAMO + PAGOS
1. Crear un cliente real (datos ficticios pero coherentes).
2. Crear un aval para ese cliente.
3. Crear un préstamo para ese cliente.
4. Subir documentos al expediente del préstamo.
5. Registrar varios pagos.
6. Ver el historial de pagos.
7. Ver el expediente completo.
8. Ver la auditoría de todas estas acciones.

ESCENARIO 2 — TANDA + APORTACIONES
1. Crear una tanda.
2. Agregar participantes.
3. Registrar aportaciones.
4. Ver historial de aportaciones.
5. Ver auditoría de movimientos.

ESCENARIO 3 — CHAT
1. Abrir una conversación entre operador y cliente.
2. Enviar mensajes desde ambos lados.
3. Ver historial de mensajes.
4. Ver auditoría de accesos al chat.

ESCENARIO 4 — INVENTARIO + FACTURACIÓN + ENTREGAS
1. Crear un producto en inventario.
2. Crear una factura que incluya ese producto.
3. Registrar una entrega asociada a esa factura.
4. Ver historial de facturas.
5. Ver historial de entregas.
6. Ver auditoría de estas acciones.

RESULTADO ESPERADO:
- Ningún error de UI.
- Ningún error de permisos.
- Ningún error de RLS.
- Auditoría completa de todas las acciones.

---

## SECCIÓN 3 — PLAN DE OPTIMIZACIÓN PARA PRODUCCIÓN

1. CONFIGURACIÓN DE BUILD
- Activar modo release en todas las plataformas.
- Verificar que no se muestra debugBanner.
- Minimizar assets no usados.

2. RENDIMIENTO
- Revisar que no haya listas gigantes sin paginación.
- Revisar que no haya consultas innecesarias.
- Revisar que no haya animaciones pesadas en dispositivos de gama baja.

3. SEGURIDAD
- Verificar que las keys sensibles no están hardcodeadas.
- Verificar que todas las tablas sensibles tienen RLS activo.
- Verificar que los roles están correctamente configurados.

4. LOGS Y MONITOREO
- Activar logs de errores en producción.
- Activar monitoreo básico (crashes, tiempos de respuesta).
- Definir proceso de revisión de logs (diario/semanal).

5. BACKUPS
- Configurar backups automáticos de la base de datos.
- Definir política de retención (ej. 30 días).
- Probar restaurar un backup en entorno de prueba.

6. CHECKLIST FINAL DE PRODUCCIÓN
- App compila en modo release.
- Conexión a Supabase estable.
- RLS validado.
- Roles y permisos validados.
- Logs activos.
- Backups activos.

---

## SECCIÓN 4 — MANUAL OPERATIVO POR ROL

### ROL: CLIENTE
- Puede:
  - Ver sus préstamos.
  - Ver sus tandas.
  - Ver sus documentos.
  - Ver sus comprobantes.
  - Usar el chat con el operador.
- No puede:
  - Ver datos de otros clientes.
  - Ver auditoría.
  - Ver administración.

### ROL: AVAL
- Puede:
  - Ver préstamos donde es aval.
  - Ver documentos relacionados a esos préstamos.
- No puede:
  - Crear préstamos.
  - Ver otros clientes.
  - Ver auditoría.

### ROL: OPERADOR
- Puede:
  - Crear y editar clientes.
  - Crear y editar avales.
  - Crear y editar préstamos.
  - Registrar pagos.
  - Crear tandas y registrar aportaciones.
  - Subir documentos y comprobantes.
  - Usar el chat con clientes.
- No puede:
  - Cambiar roles.
  - Ver configuración avanzada.
  - Ver auditoría completa (solo parcial si se define).

### ROL: SUPERVISOR
- Puede:
  - Ver todo lo que ve el operador.
  - Ver reportes.
  - Ver auditoría de operaciones.
- No puede:
  - Cambiar permisos.
  - Cambiar configuración global.

### ROL: ADMIN
- Puede:
  - Todo lo del supervisor.
  - Gestionar usuarios.
  - Gestionar roles.
  - Gestionar sucursales.
  - Gestionar inventario.
  - Gestionar facturación.
  - Gestionar entregas.
- No puede:
  - Cambiar permisos de superadmin.

### ROL: SUPERADMIN
- Puede:
  - Todo lo del admin.
  - Gestionar permisos.
  - Activar/desactivar módulos.
  - Cambiar configuración global.
  - Ver auditoría completa del sistema.
