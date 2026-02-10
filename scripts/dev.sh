#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
# Script de Desarrollo Local para Web Apps
# ═════════════════════════════════════════════════════════════════════════════

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Servidor de Desarrollo Local                            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

PORT=${1:-8000}

# Check if port is in use
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo -e "${RED}❌ Puerto $PORT ya está en uso${NC}"
    echo ""
    echo "Procesos usando el puerto:"
    lsof -i :$PORT
    echo ""
    read -p "¿Quieres usar otro puerto? [y/N]: " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        read -p "Nuevo puerto: " PORT
    else
        exit 1
    fi
fi

echo -e "${GREEN}✓${NC} Iniciando servidor en puerto ${BLUE}$PORT${NC}"
echo ""
echo -e "${YELLOW}📱 Accede a las aplicaciones:${NC}"
echo ""
echo -e "  ${GREEN}Tarjetas:${NC}"
echo "    http://localhost:$PORT/?codigo=DEMO"
echo "    http://localhost:$PORT/?codigo=DEMO&negocio=1&modulo=climas"
echo ""
echo -e "  ${GREEN}Pollos:${NC}"
echo "    http://localhost:$PORT/pollos/"
echo ""
echo -e "${BLUE}ℹ Presiona Ctrl+C para detener el servidor${NC}"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Start server
python3 -m http.server $PORT
