#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
# Script de Build Completo para App Flutter
# ═════════════════════════════════════════════════════════════════════════════

set -e  # Exit on error

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Robert Darin Fintech - Flutter Build Script             ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we're in the right directory
if [ ! -f "robertdarin/pubspec.yaml" ]; then
    echo -e "${RED}❌ Error: Este script debe ejecutarse desde la raíz del repositorio${NC}"
    exit 1
fi

cd robertdarin

# Check Flutter installation
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter no está instalado o no está en el PATH${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Flutter encontrado: $(flutter --version | head -1)"
echo ""

# Menu
echo "Selecciona el tipo de build:"
echo "  1) APK Debug"
echo "  2) APK Release"
echo "  3) App Bundle (Play Store)"
echo "  4) iOS (solo en macOS)"
echo "  5) Análisis de código"
echo "  6) Clean + Get dependencies"
echo ""
read -p "Opción [1-6]: " option

case $option in
    1)
        echo -e "${YELLOW}🔨 Construyendo APK Debug...${NC}"
        flutter build apk --debug
        echo -e "${GREEN}✓ APK Debug generado:${NC}"
        echo "  build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    2)
        echo -e "${YELLOW}🔨 Construyendo APK Release...${NC}"
        flutter build apk --release
        
        # Copy to app/ folder
        mkdir -p ../app
        cp build/app/outputs/flutter-apk/app-release.apk ../app/robertdarin-latest.apk
        
        echo -e "${GREEN}✓ APK Release generado:${NC}"
        echo "  build/app/outputs/flutter-apk/app-release.apk"
        echo "  app/robertdarin-latest.apk (copia)"
        ;;
    3)
        echo -e "${YELLOW}🔨 Construyendo App Bundle (AAB) para Play Store...${NC}"
        flutter build appbundle --release
        
        echo -e "${GREEN}✓ App Bundle generado:${NC}"
        echo "  build/app/outputs/bundle/release/app-release.aab"
        echo ""
        echo -e "${BLUE}ℹ Siguiente paso:${NC}"
        echo "  Sube el AAB a Google Play Console"
        ;;
    4)
        if [[ "$OSTYPE" != "darwin"* ]]; then
            echo -e "${RED}❌ Build iOS solo disponible en macOS${NC}"
            exit 1
        fi
        
        echo -e "${YELLOW}🔨 Construyendo para iOS...${NC}"
        flutter build ios --release
        
        echo -e "${GREEN}✓ Build iOS completado${NC}"
        echo "  Abre Xcode y archiva el build"
        ;;
    5)
        echo -e "${YELLOW}🔍 Analizando código...${NC}"
        flutter analyze
        
        echo ""
        echo -e "${YELLOW}📊 Generando métricas...${NC}"
        find lib -name '*.dart' | xargs wc -l | tail -1
        ;;
    6)
        echo -e "${YELLOW}🧹 Limpiando...${NC}"
        flutter clean
        
        echo -e "${YELLOW}📦 Obteniendo dependencias...${NC}"
        flutter pub get
        
        echo -e "${GREEN}✓ Limpieza completada${NC}"
        ;;
    *)
        echo -e "${RED}❌ Opción inválida${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Build completado exitosamente                         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
