#!/bin/bash

# ═════════════════════════════════════════════════════════════════════════════
# Script de Deployment para GitHub
# ═════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Robert Darin Fintech - Deploy Script                    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo -e "${RED}❌ Hay cambios sin commitear${NC}"
    echo ""
    git status --short
    echo ""
    echo -e "${YELLOW}Opciones:${NC}"
    echo "  1) Commitear cambios y continuar"
    echo "  2) Descartar cambios"
    echo "  3) Cancelar"
    echo ""
    read -p "Opción [1-3]: " opt
    
    case $opt in
        1)
            read -p "Mensaje del commit: " msg
            git add .
            git commit -m "$msg"
            ;;
        2)
            git reset --hard
            echo -e "${YELLOW}⚠ Cambios descartados${NC}"
            ;;
        3)
            echo "Cancelado"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida${NC}"
            exit 1
            ;;
    esac
fi

# Check current branch
BRANCH=$(git branch --show-current)
echo -e "${BLUE}ℹ Branch actual:${NC} $BRANCH"

# Pull latest changes
echo ""
echo -e "${YELLOW}🔄 Sincronizando con remoto...${NC}"
git pull --rebase origin $BRANCH || {
    echo -e "${RED}❌ Error al hacer pull${NC}"
    echo "Resuelve conflictos y ejecuta: git rebase --continue"
    exit 1
}

# Push changes
echo ""
echo -e "${YELLOW}📤 Subiendo cambios...${NC}"
git push origin $BRANCH

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✓ Deploy completado exitosamente                        ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}ℹ Últimos 3 commits:${NC}"
git log --oneline -3
