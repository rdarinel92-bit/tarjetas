#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
# Script de Testing para App Flutter
# ═════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Robert Darin Fintech - Testing Suite                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

cd robertdarin

# Run tests
echo -e "${YELLOW}🧪 Ejecutando tests...${NC}"
flutter test --coverage

# Check if coverage exists
if [ -f "coverage/lcov.info" ]; then
    echo ""
    echo -e "${GREEN}✓ Tests completados${NC}"
    echo ""
    echo -e "${YELLOW}📊 Cobertura de código:${NC}"
    
    # Install lcov if not present (Linux)
    if command -v lcov &> /dev/null; then
        lcov --summary coverage/lcov.info
    else
        echo "  (Instala lcov para ver resumen de cobertura)"
        echo "  Archivo generado: coverage/lcov.info"
    fi
else
    echo -e "${GREEN}✓ Tests completados (sin reporte de cobertura)${NC}"
fi

echo ""
echo -e "${BLUE}ℹ Tip:${NC} Abre coverage/lcov.info en tu IDE para ver cobertura detallada"
