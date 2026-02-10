#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
# Setup Inicial del Proyecto Robert Darin Fintech
# ═════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

clear
echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                       ║"
echo "║          🚀 ROBERT DARIN FINTECH - SETUP WIZARD 🚀                   ║"
echo "║                                                                       ║"
echo "║              Configuración automática del proyecto                   ║"
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 1. VERIFICAR REQUISITOS
# ═════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}[1/6] Verificando requisitos del sistema...${NC}"
echo ""

MISSING_DEPS=false

# Git
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓${NC} Git: $(git --version | head -1)"
else
    echo -e "${RED}✗${NC} Git no encontrado"
    MISSING_DEPS=true
fi

# Python
if command -v python3 &> /dev/null; then
    echo -e "${GREEN}✓${NC} Python: $(python3 --version)"
else
    echo -e "${RED}✗${NC} Python3 no encontrado"
    MISSING_DEPS=true
fi

# Flutter
if command -v flutter &> /dev/null; then
    echo -e "${GREEN}✓${NC} Flutter: $(flutter --version | head -1)"
else
    echo -e "${YELLOW}⚠${NC} Flutter no encontrado (opcional para web)"
fi

# Java (opcional)
if command -v java &> /dev/null; then
    echo -e "${GREEN}✓${NC} Java: $(java -version 2>&1 | head -1)"
else
    echo -e "${YELLOW}⚠${NC} Java no encontrado (necesario para builds Android)"
fi

if [ "$MISSING_DEPS" = true ]; then
    echo ""
    echo -e "${RED}❌ Faltan dependencias obligatorias${NC}"
    echo "Instala Git y Python3 antes de continuar"
    exit 1
fi

echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 2. CONFIGURAR GIT
# ═════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}[2/6] Configurando Git...${NC}"
echo ""

if ! git config user.name &> /dev/null; then
    read -p "Tu nombre para Git: " git_name
    git config --global user.name "$git_name"
fi

if ! git config user.email &> /dev/null; then
    read -p "Tu email para Git: " git_email
    git config --global user.email "$git_email"
fi

echo -e "${GREEN}✓${NC} Git configurado: $(git config user.name) <$(git config user.email)>"
echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 3. FLUTTER SETUP
# ═════════════════════════════════════════════════════════════════════════════

if command -v flutter &> /dev/null; then
    echo -e "${CYAN}[3/6] Configurando Flutter...${NC}"
    echo ""
    
    cd robertdarin
    
    echo -e "${YELLOW}📦 Obteniendo dependencias...${NC}"
    flutter pub get
    
    echo ""
    echo -e "${YELLOW}🔍 Doctor check...${NC}"
    flutter doctor
    
    cd ..
    echo -e "${GREEN}✓${NC} Flutter configurado"
else
    echo -e "${CYAN}[3/6] Saltando configuración Flutter (no instalado)${NC}"
fi

echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 4. CREAR ARCHIVOS DE CONFIGURACIÓN
# ═════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}[4/6] Creando archivos de configuración...${NC}"
echo ""

# .env para Flutter (ejemplo)
if [ ! -f "robertdarin/.env" ]; then
    cat > robertdarin/.env << EOF
# Supabase Configuration
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu-anon-key

# Firebase Configuration (opcional)
FIREBASE_API_KEY=tu-api-key

# Environment
ENV=development
EOF
    echo -e "${GREEN}✓${NC} Creado robertdarin/.env (recuerda configurar)"
else
    echo -e "${BLUE}ℹ${NC} robertdarin/.env ya existe"
fi

# VS Code settings
mkdir -p .vscode
if [ ! -f ".vscode/settings.json" ]; then
    cat > .vscode/settings.json << EOF
{
  "dart.flutterSdkPath": null,
  "dart.lineLength": 120,
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": true
  },
  "files.exclude": {
    "**/.dart_tool": true,
    "**/.flutter-plugins": true,
    "**/.packages": true
  },
  "search.exclude": {
    "**/build": true,
    "**/.dart_tool": true
  }
}
EOF
    echo -e "${GREEN}✓${NC} Creado .vscode/settings.json"
else
    echo -e "${BLUE}ℹ${NC} .vscode/settings.json ya existe"
fi

echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 5. HACER SCRIPTS EJECUTABLES
# ═════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}[5/6] Configurando scripts...${NC}"
echo ""

chmod +x scripts/*.sh
echo -e "${GREEN}✓${NC} Scripts ejecutables configurados"

echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# 6. GENERAR RESUMEN
# ═════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}[6/6] Generando resumen del proyecto...${NC}"
echo ""

# Contar líneas de código
if [ -d "robertdarin/lib" ]; then
    DART_LINES=$(find robertdarin/lib -name '*.dart' 2>/dev/null | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Código Dart: ~$DART_LINES líneas"
fi

if [ -f "index.html" ]; then
    HTML_LINES=$(wc -l index.html pollos/index.html 2>/dev/null | tail -1 | awk '{print $1}')
    echo -e "${GREEN}✓${NC} Código Web: ~$HTML_LINES líneas"
fi

echo ""
sleep 1

# ═════════════════════════════════════════════════════════════════════════════
# FINALIZACIÓN
# ═════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                       ║"
echo "║                    ✓ SETUP COMPLETADO ✓                              ║"
echo "║                                                                       ║"
echo "╚═══════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${MAGENTA}📚 Próximos pasos:${NC}"
echo ""
echo "1. ${YELLOW}Configurar Supabase:${NC}"
echo "   Edita: robertdarin/.env"
echo ""
echo "2. ${YELLOW}Iniciar desarrollo web:${NC}"
echo "   ${CYAN}./scripts/dev.sh${NC}"
echo ""
echo "3. ${YELLOW}Desarrollar app Flutter:${NC}"
echo "   ${CYAN}cd robertdarin && flutter run${NC}"
echo ""
echo "4. ${YELLOW}Leer documentación:${NC}"
echo "   - README.md"
echo "   - QUICKSTART.md"
echo "   - CONTRIBUTING.md"
echo ""
echo -e "${BLUE}💡 Tip:${NC} Ejecuta ${CYAN}./scripts/build.sh${NC} para ver opciones de build"
echo ""
echo -e "${GREEN}¡Feliz coding! 🚀${NC}"
echo ""
