// ══════════════════════════════════════════════════════════════════════════════
// EDGE FUNCTION: Send Chat Push Notification (FCM V1 API)
// Robert Darin Fintech V10.56
// Envía notificación push FCM cuando un cliente envía un mensaje por tarjeta QR
// Usa la API V1 de Firebase Cloud Messaging (la Legacy fue deprecada)
// ══════════════════════════════════════════════════════════════════════════════

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ChatMessage {
  id: string
  tarjeta_id: string
  negocio_id: string
  emisor_tipo: string
  emisor_nombre: string
  mensaje: string
  created_at: string
}

// Función para obtener access token de Google usando Service Account
async function getAccessToken(serviceAccount: any): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  const expiry = now + 3600 // 1 hora
  
  // Crear JWT header
  const header = {
    alg: 'RS256',
    typ: 'JWT'
  }
  
  // Crear JWT claim
  const claim = {
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: expiry
  }
  
  // Codificar header y claim
  const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const encodedClaim = btoa(JSON.stringify(claim)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  // Firmar con la clave privada
  const signatureInput = `${encodedHeader}.${encodedClaim}`
  
  // Importar la clave privada
  const privateKey = serviceAccount.private_key
  const pemHeader = '-----BEGIN PRIVATE KEY-----'
  const pemFooter = '-----END PRIVATE KEY-----'
  const pemContents = privateKey.replace(pemHeader, '').replace(pemFooter, '').replace(/\s/g, '')
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  )
  
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signatureInput)
  )
  
  const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  const jwt = `${signatureInput}.${encodedSignature}`
  
  // Intercambiar JWT por access token
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`
  })
  
  const tokenData = await tokenResponse.json()
  return tokenData.access_token
}

serve(async (req) => {
  // Manejar preflight CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 1. Obtener datos del mensaje
    const payload = await req.json()
    const record: ChatMessage = payload.record
    
    console.log('📩 Nuevo mensaje de chat:', record)
    
    // Solo notificar mensajes de clientes (no de negocio)
    if (record.emisor_tipo !== 'cliente') {
      console.log('⏭️ Mensaje de negocio, no se notifica')
      return new Response(JSON.stringify({ success: true, message: 'No notification needed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 2. Obtener credenciales de Firebase
    const firebaseServiceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!firebaseServiceAccountJson) {
      console.error('❌ FIREBASE_SERVICE_ACCOUNT no configurado')
      return new Response(JSON.stringify({ error: 'Firebase not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const serviceAccount = JSON.parse(firebaseServiceAccountJson)
    const projectId = serviceAccount.project_id

    // 3. Crear cliente Supabase
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    // 4. Obtener información del negocio
    const { data: negocio, error: negocioError } = await supabase
      .from('negocios')
      .select('id, nombre, owner_email')
      .eq('id', record.negocio_id)
      .single()

    if (negocioError || !negocio) {
      console.error('❌ Error obteniendo negocio:', negocioError)
      return new Response(JSON.stringify({ error: 'Business not found' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log('🏢 Negocio:', negocio.nombre)

    // 5. Obtener tokens FCM de usuarios que deben recibir la notificación
    const { data: ownerUser } = await supabase
      .from('usuarios')
      .select('id')
      .eq('email', negocio.owner_email)
      .single()

    const { data: empleadosConPermiso } = await supabase
      .from('permisos_chat_qr')
      .select('empleado_id')
      .eq('negocio_id', record.negocio_id)
      .eq('tiene_permiso', true)

    const userIdsToNotify: string[] = []
    
    if (ownerUser?.id) {
      userIdsToNotify.push(ownerUser.id)
    }
    
    if (empleadosConPermiso) {
      for (const emp of empleadosConPermiso) {
        const { data: empUser } = await supabase
          .from('empleados')
          .select('usuario_id')
          .eq('id', emp.empleado_id)
          .single()
        
        if (empUser?.usuario_id && !userIdsToNotify.includes(empUser.usuario_id)) {
          userIdsToNotify.push(empUser.usuario_id)
        }
      }
    }

    console.log('👥 Usuarios a notificar:', userIdsToNotify)

    if (userIdsToNotify.length === 0) {
      return new Response(JSON.stringify({ success: true, message: 'No users to notify' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // 6. Obtener tokens FCM
    const { data: dispositivos } = await supabase
      .from('dispositivos_fcm')
      .select('fcm_token')
      .in('usuario_id', userIdsToNotify)
      .eq('activo', true)

    if (!dispositivos || dispositivos.length === 0) {
      console.log('⚠️ No hay dispositivos FCM registrados')
      return new Response(JSON.stringify({ success: true, message: 'No FCM devices' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    console.log(`📱 ${dispositivos.length} dispositivos encontrados`)

    // 7. Obtener access token de Google
    const accessToken = await getAccessToken(serviceAccount)

    // 8. Enviar push notification con FCM V1 API
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`
    let enviados = 0
    let errores = 0

    for (const disp of dispositivos) {
      try {
        const fcmResponse = await fetch(fcmUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${accessToken}`,
          },
          body: JSON.stringify({
            message: {
              token: disp.fcm_token,
              notification: {
                title: `💬 ${record.emisor_nombre}`,
                body: record.mensaje.substring(0, 100) + (record.mensaje.length > 100 ? '...' : ''),
              },
              data: {
                type: 'tarjeta_chat',
                tarjeta_id: record.tarjeta_id,
                negocio_id: record.negocio_id,
                message_id: record.id,
                route: '/tarjetas/chat',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
              },
              android: {
                priority: 'high',
                notification: {
                  channel_id: 'robertdarin_notifications',
                  sound: 'default',
                  icon: 'ic_notification',
                },
              },
            },
          }),
        })

        if (fcmResponse.ok) {
          enviados++
          console.log('✅ Push enviado')
        } else {
          const errText = await fcmResponse.text()
          console.error('❌ Error FCM:', errText)
          errores++
          
          // Si el token es inválido, desactivarlo
          if (errText.includes('UNREGISTERED') || errText.includes('INVALID_ARGUMENT')) {
            await supabase
              .from('dispositivos_fcm')
              .update({ activo: false })
              .eq('fcm_token', disp.fcm_token)
          }
        }
      } catch (fcmError) {
        console.error('❌ Error enviando push:', fcmError)
        errores++
      }
    }

    console.log(`📊 Resultado: ${enviados} enviados, ${errores} errores`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: enviados, 
        errors: errores,
        total_devices: dispositivos.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('❌ Error general:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
