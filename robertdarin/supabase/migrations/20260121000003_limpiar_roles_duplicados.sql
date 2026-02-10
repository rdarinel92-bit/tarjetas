-- ═══════════════════════════════════════════════════════════════════════════════
-- LIMPIEZA COMPLETA DE ROLES DUPLICADOS
-- Fecha: 21 Enero 2026
-- Problema: Roles duplicados y permisos incoherentes
-- ═══════════════════════════════════════════════════════════════════════════════

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 1: ELIMINAR ROLES DUPLICADOS (mantener solo uno de cada nombre)         ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- 1A. Primero eliminar asignaciones de roles duplicados en usuarios_roles
DELETE FROM usuarios_roles 
WHERE rol_id IN (
    SELECT r1.id 
    FROM roles r1
    WHERE EXISTS (
        SELECT 1 FROM roles r2 
        WHERE LOWER(r2.nombre) = LOWER(r1.nombre) 
        AND r2.id < r1.id
    )
);

-- 1B. Eliminar permisos de roles duplicados
DELETE FROM roles_permisos 
WHERE rol_id IN (
    SELECT r1.id 
    FROM roles r1
    WHERE EXISTS (
        SELECT 1 FROM roles r2 
        WHERE LOWER(r2.nombre) = LOWER(r1.nombre) 
        AND r2.id < r1.id
    )
);

-- 1C. Eliminar los roles duplicados (mantener el primero creado)
DELETE FROM roles 
WHERE id IN (
    SELECT r1.id 
    FROM roles r1
    WHERE EXISTS (
        SELECT 1 FROM roles r2 
        WHERE LOWER(r2.nombre) = LOWER(r1.nombre) 
        AND r2.id < r1.id
    )
);

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 2: NORMALIZAR NOMBRES DE ROLES (minúsculas consistentes)                ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

UPDATE roles SET nombre = LOWER(nombre) WHERE nombre != LOWER(nombre);

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 3: ASEGURAR QUE EXISTEN LOS ROLES BASE                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

INSERT INTO roles (nombre, descripcion) VALUES 
    ('superadmin', 'Super Administrador del Sistema'),
    ('admin', 'Administrador de negocio'),
    ('operador', 'Operador con acceso limitado'),
    ('cliente', 'Cliente del negocio'),
    ('contador', 'Contador con acceso a finanzas'),
    ('recursos_humanos', 'Recursos Humanos'),
    ('aval', 'Aval de préstamos'),
    ('vendedora_nice', 'Vendedora Nice Joyería'),
    ('tecnico_climas', 'Técnico de aires acondicionados'),
    ('repartidor_purificadora', 'Repartidor de agua purificada'),
    ('cliente_climas', 'Cliente del servicio de climas'),
    ('cliente_purificadora', 'Cliente del servicio de purificadora'),
    ('vendedor_ventas', 'Vendedor de catálogo/ventas'),
    ('admin_climas', 'Administrador del módulo Climas')
ON CONFLICT (nombre) DO UPDATE SET 
    descripcion = EXCLUDED.descripcion;

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 4: LIMPIAR PERMISOS DUPLICADOS                                          ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

-- Eliminar permisos duplicados (mantener el primero)
DELETE FROM roles_permisos 
WHERE id IN (
    SELECT rp1.id 
    FROM roles_permisos rp1
    WHERE EXISTS (
        SELECT 1 FROM roles_permisos rp2 
        WHERE rp2.rol_id = rp1.rol_id 
        AND rp2.permiso_id = rp1.permiso_id
        AND rp2.id < rp1.id
    )
);

-- ╔═══════════════════════════════════════════════════════════════════════════════╗
-- ║ PASO 5: VERIFICAR RESULTADO                                                  ║
-- ╚═══════════════════════════════════════════════════════════════════════════════╝

DO $$
DECLARE
    v_total_roles INTEGER;
    v_duplicados INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_roles FROM roles;
    
    SELECT COUNT(*) INTO v_duplicados 
    FROM (
        SELECT LOWER(nombre), COUNT(*) as cnt 
        FROM roles 
        GROUP BY LOWER(nombre) 
        HAVING COUNT(*) > 1
    ) as dups;
    
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE '✅ LIMPIEZA DE ROLES COMPLETADA';
    RAISE NOTICE '═══════════════════════════════════════════════════════════════';
    RAISE NOTICE 'Total roles: %', v_total_roles;
    RAISE NOTICE 'Duplicados restantes: %', v_duplicados;
    
    IF v_duplicados > 0 THEN
        RAISE NOTICE '⚠️ AÚN HAY DUPLICADOS - revisar manualmente';
    ELSE
        RAISE NOTICE '✅ NO HAY DUPLICADOS';
    END IF;
END $$;
