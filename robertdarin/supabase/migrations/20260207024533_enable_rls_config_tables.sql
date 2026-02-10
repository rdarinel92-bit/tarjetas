-- Migración: Habilitar RLS en tablas de configuración del sistema
-- Estas tablas tenían políticas definidas pero RLS no estaba habilitado

-- Habilitar RLS en tablas de configuración
ALTER TABLE IF EXISTS configuracion_global ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS temas_app ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS fondos_pantalla ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS promociones ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notificaciones_masivas ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS preferencias_usuario ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS configuracion ENABLE ROW LEVEL SECURITY;

-- Política para preferencias_usuario (cada usuario ve solo las suyas)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE policyname = 'preferencias_usuario_own') THEN
        CREATE POLICY "preferencias_usuario_own" ON preferencias_usuario FOR ALL 
        USING (usuario_id = auth.uid());
    END IF;
END $$;
