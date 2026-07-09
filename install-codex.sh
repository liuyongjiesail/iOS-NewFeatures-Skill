#!/bin/bash

# iOS New Features Skill - Codex Installation Script
# Codex (OpenAI CLI) does not auto-trigger skills. This script copies the
# reference docs to ~/.codex/skills/ios-new-features/ and injects an
# idempotent instruction block into the global ~/.codex/AGENTS.md.
#
# Compatible with macOS, Linux, and Windows (Git Bash).

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/liuyongjiesail/iOS-NewFeatures-Skill"
BEGIN_MARKER="<!-- BEGIN ios-new-features (managed by install-codex) -->"
END_MARKER="<!-- END ios-new-features (managed by install-codex) -->"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  iOS New Features Skill (Codex) Installer${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Determine home directory (Windows Git Bash uses USERPROFILE).
HOME_DIR="${HOME:-$USERPROFILE}"
CODEX_DIR="$HOME_DIR/.codex"
SKILL_DIR="$CODEX_DIR/skills/ios-new-features"
AGENTS_FILE="$CODEX_DIR/AGENTS.md"

# Locate source files: prefer a local checkout, otherwise clone to a temp dir.
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd || true)"
SRC_ROOT=""
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/codex/AGENTS.md" ]; then
    SRC_ROOT="$SCRIPT_DIR"
fi

TMP_CLONE=""
if [ -z "$SRC_ROOT" ]; then
    echo -e "${YELLOW}Source files not found locally — cloning repository...${NC}"
    TMP_CLONE="$(mktemp -d)"
    git clone --depth 1 "$REPO_URL" "$TMP_CLONE" >/dev/null 2>&1
    SRC_ROOT="$TMP_CLONE"
fi

SRC_AGENTS="$SRC_ROOT/codex/AGENTS.md"
SRC_REFERENCE="$SRC_ROOT/skills/ios-new-features/reference"

if [ ! -f "$SRC_AGENTS" ] || [ ! -d "$SRC_REFERENCE" ]; then
    echo -e "${RED}❌ Source files not found. Aborting.${NC}"
    [ -n "$TMP_CLONE" ] && rm -rf "$TMP_CLONE"
    exit 1
fi

echo -e "${BLUE}📁 Target directory: $SKILL_DIR${NC}"

# Fresh copy of the skill payload.
if [ -d "$SKILL_DIR" ]; then
    echo -e "${YELLOW}⚠️  Existing install found — refreshing...${NC}"
    rm -rf "$SKILL_DIR"
fi
mkdir -p "$SKILL_DIR"

echo -e "${BLUE}📋 Copying reference docs...${NC}"
cp "$SRC_AGENTS" "$SKILL_DIR/AGENTS.md"
cp -r "$SRC_REFERENCE" "$SKILL_DIR/reference"

# Build the managed instruction block.
BLOCK="$BEGIN_MARKER
## iOS New Features Reference

When a request involves iOS 18+ / iOS 26+ Swift or SwiftUI APIs, a specific WWDC session
(2023–2025), or any trigger keyword listed in the index below, **read the matching reference
file before writing code**. Do not answer newer-iOS API questions from memory alone.

- Index & trigger keywords: \`$SKILL_DIR/AGENTS.md\`
- Reference docs: \`$SKILL_DIR/reference/\`
$END_MARKER"

echo -e "${BLUE}📝 Updating global ~/.codex/AGENTS.md...${NC}"
mkdir -p "$CODEX_DIR"

if [ -f "$AGENTS_FILE" ] && grep -qF "$BEGIN_MARKER" "$AGENTS_FILE"; then
    # Replace existing managed block (delete from BEGIN to END, then append fresh).
    TMP_FILE="$(mktemp)"
    awk -v b="$BEGIN_MARKER" -v e="$END_MARKER" '
        $0==b {skip=1}
        skip==0 {print}
        $0==e {skip=0}
    ' "$AGENTS_FILE" > "$TMP_FILE"
    # Strip surrounding blank lines from the remaining content.
    REMAINING="$(cat "$TMP_FILE")"
    rm -f "$TMP_FILE"
    if [ -n "$REMAINING" ]; then
        printf '%s\n\n%s\n' "$REMAINING" "$BLOCK" > "$AGENTS_FILE"
    else
        printf '%s\n' "$BLOCK" > "$AGENTS_FILE"
    fi
    ACTION="updated"
elif [ -f "$AGENTS_FILE" ]; then
    printf '\n%s\n' "$BLOCK" >> "$AGENTS_FILE"
    ACTION="appended"
else
    printf '%s\n' "$BLOCK" > "$AGENTS_FILE"
    ACTION="created"
fi

[ -n "$TMP_CLONE" ] && rm -rf "$TMP_CLONE"

if [ -f "$SKILL_DIR/AGENTS.md" ]; then
    echo ""
    echo -e "${GREEN}✅ Codex installation successful!${NC}"
    echo ""
    echo -e "${BLUE}📍 Docs installed to:${NC}"
    echo -e "   $SKILL_DIR"
    echo -e "${BLUE}📍 Global instructions ($ACTION):${NC}"
    echo -e "   $AGENTS_FILE"
    echo ""
    echo -e "${YELLOW}🎯 Next steps:${NC}"
    echo -e "   1. Start (or restart) Codex"
    echo -e "   2. Ask about an iOS 18+ API, e.g. 'How do I use AlarmKit?'"
    echo -e "   3. Codex will read the matching reference file automatically"
    echo ""
    echo -e "${GREEN}🚀 Happy coding!${NC}"
else
    echo -e "${RED}❌ Installation failed.${NC}"
    exit 1
fi
