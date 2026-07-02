#!/bin/bash

# iOS New Features Skill - Installation Script
# Compatible with macOS, Linux, and Windows (Git Bash)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect OS
OS="$(uname -s)"
case "$OS" in
    Linux*)     MACHINE=Linux;;
    Darwin*)    MACHINE=Mac;;
    CYGWIN*)    MACHINE=Cygwin;;
    MINGW*)     MACHINE=MinGw;;
    *)          MACHINE="UNKNOWN:${OS}"
esac

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  iOS New Features Skill Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Detected OS: ${MACHINE}${NC}"
echo ""

# Determine installation directory
if [ "$MACHINE" = "Mac" ] || [ "$MACHINE" = "Linux" ]; then
    DEFAULT_DIR="$HOME/.claude/skills"
else
    # Windows with Git Bash
    DEFAULT_DIR="$USERPROFILE/.claude/skills"
fi

SKILL_DIR="$DEFAULT_DIR/ios-new-features"

# Check if directory exists
if [ -d "$SKILL_DIR" ]; then
    echo -e "${YELLOW}⚠️  Skill already installed at:${NC}"
    echo -e "   $SKILL_DIR"
    echo ""
    read -p "Do you want to reinstall? (y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Installation cancelled.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Removing existing installation...${NC}"
    rm -rf "$SKILL_DIR"
fi

# Create directory
echo -e "${BLUE}Creating directory: $DEFAULT_DIR${NC}"
mkdir -p "$DEFAULT_DIR"

# Copy skill files
echo -e "${BLUE}Copying skill files...${NC}"
cp -r "$(dirname "$0")/ios-new-features" "$SKILL_DIR"

# Verify installation
if [ -f "$SKILL_DIR/SKILL.md" ]; then
    echo ""
    echo -e "${GREEN}✅ Installation successful!${NC}"
    echo ""
    echo -e "${BLUE}Skill installed to:${NC}"
    echo -e "   $SKILL_DIR"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo -e "   1. Restart Claude Code (if running)"
    echo -e "   2. Open any iOS project"
    echo -e "   3. Try asking: 'How to use AlarmKit in iOS 26?'"
    echo ""
    echo -e "${BLUE}Features:${NC}"
    echo -e "   • 27+ iOS/macOS/watchOS features"
    echo -e "   • Auto-triggered by keywords"
    echo -e "   • Based on WWDC 2023-2025 sessions"
    echo ""
    echo -e "${GREEN}Happy coding! 🚀${NC}"
else
    echo ""
    echo -e "${RED}❌ Installation failed!${NC}"
    echo -e "${RED}Please check the error messages above.${NC}"
    exit 1
fi
