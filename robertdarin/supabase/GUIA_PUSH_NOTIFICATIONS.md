# 🔔 GUÍA: Habilitar Push Notifications Chat QR

## 📋 CHECKLIST RÁPIDO

Ve a cada sección en tu Dashboard de Supabase y verifica:

### 1️⃣ EXTENSIÓN pg_net
📍 **Dashboard → Database → Extensions**

- [ ] Busca "pg_net" 
- [ ] Si está OFF, habilítalo

---

### 2️⃣ EDGE FUNCTION desplegada
📍 **Dashboard → Edge Functions**

- [ ] Debe existir `send-chat-push`
- [ ] Si NO existe, hay que desplegarla (ver paso de despliegue abajo)

---

### 3️⃣ SECRETO FIREBASE configurado
📍 **Dashboard → Edge Functions → send-chat-push → Settings/Secrets**

- [ ] Debe existir `FIREBASE_SERVICE_ACCOUNT`
- [ ] Valor: TODO el contenido JSON del archivo `robert-darin-fintech-firebase-adminsdk-*.json`

---

### 4️⃣ TOKEN FCM guardado
📍 **Dashboard → Table Editor → dispositivos_fcm**

- [ ] Debe haber un registro con tu `usuario_id`
- [ ] `activo` debe ser `true`
- [ ] Si no hay registro, cierra sesión y vuelve a iniciar sesión en la app

---

### 5️⃣ TRIGGER instalado  
📍 **Dashboard → SQL Editor**

Ejecuta esto:
```sql
SELECT tgname FROM pg_trigger WHERE tgrelid = 'public.tarjetas_chat'::regclass;
```

- [ ] Debe retornar `on_tarjetas_chat_insert`
- [ ] Si no existe, ejecuta el SQL del archivo `DIAGNOSTICO_PUSH_NOTIFICATIONS.sql` PASO 7

---

## 🚀 CÓMO DESPLEGAR LA EDGE FUNCTION

### Opción A: Desde GUI (Recomendado)

1. Ve a **Dashboard → Edge Functions → New Function**
2. Nombre: `send-chat-push`
3. Copia el código de `supabase/functions/send-chat-push/index.ts`
4. Deploy

### Opción B: Desde CLI

```powershell
cd C:\Users\rober\Desktop\robertdarin
npx supabase functions deploy send-chat-push --project-ref qtfsxfvxqiihnofrpmmu
```

---

## 🔐 CONFIGURAR SECRETO FIREBASE

1. Ve a **Edge Functions → send-chat-push → Settings**
2. En "Secrets", añade:
   - **Name:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** El contenido COMPLETO del archivo JSON de Firebase Admin SDK

El archivo está en:
```
C:\Users\rober\Desktop\robertdarin\robert-darin-fintech-firebase-adminsdk-fbsvc-4266245f92.json
```

Copia TODO su contenido (empieza con `{` y termina con `}`).

---

## 🧪 PROBAR

1. Envía un mensaje desde la página web QR (como cliente)
2. Revisa los logs en: **Edge Functions → send-chat-push → Logs**
3. Si hay errores, aparecerán ahí

---

## ❓ PROBLEMAS COMUNES

| Síntoma | Causa probable | Solución |
|---------|---------------|----------|
| Logs vacíos | Trigger no instalado | Ejecutar SQL del PASO 7 |
| "Firebase not configured" | Secreto no configurado | Agregar FIREBASE_SERVICE_ACCOUNT |
| "No FCM devices" | Token no guardado | Cerrar/abrir sesión en app |
| "No users to notify" | owner_email incorrecto | Verificar negocio tiene owner_email correcto |
