-- Función de trigger para enviar push notifications V10.56
CREATE OR REPLACE FUNCTION public.trigger_send_chat_push()
RETURNS TRIGGER AS $$
BEGIN
  -- Solo para mensajes de clientes
  IF NEW.emisor_tipo = 'cliente' THEN
    -- Llamar a la Edge Function via pg_net (net.http_post)
    PERFORM net.http_post(
      url := 'https://qtfsxfvxqiihnofrpmmu.supabase.co/functions/v1/send-chat-push',
      body := json_build_object('record', row_to_json(NEW))::jsonb,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0ZnN4ZnZ4cWlpaG5vZnJwbW11Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjczMjU5MDIsImV4cCI6MjA4MjkwMTkwMn0.D4LrG8FlnqfK0Zhi2Ex0z2UGeoVSr6u1XR2jnxis9Bg'
      )
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Crear el trigger
DROP TRIGGER IF EXISTS on_tarjetas_chat_insert ON tarjetas_chat;
CREATE TRIGGER on_tarjetas_chat_insert
  AFTER INSERT ON tarjetas_chat
  FOR EACH ROW
  EXECUTE FUNCTION trigger_send_chat_push();

-- Comentario
COMMENT ON FUNCTION trigger_send_chat_push() IS 'Trigger para enviar push notifications en nuevos mensajes de chat QR V10.56';
