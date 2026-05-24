#!/bin/bash

# Setup symlinks for shared skills into tool discovery paths
# Fails if any symlink already exists (prevents accidental overwrites)

set -e

AGENT_SKILLS_DIR="$HOME/.agent-skills"
CURSOR_SKILLS_DIR="$HOME/.cursor/skills-cursor"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
CODEX_SKILLS_DIR="$HOME/.codex/skills"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔗 Setting up symlinks for shared skills..."
echo ""

# Verify source directory exists
if [ ! -d "$AGENT_SKILLS_DIR" ]; then
    echo -e "${RED}✗ Error: $AGENT_SKILLS_DIR does not exist${NC}"
    exit 1
fi

# Verify all target directories exist
for dir in "$CURSOR_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR"; do
    if [ ! -d "$dir" ]; then
        echo -e "${RED}✗ Error: $dir does not exist${NC}"
        exit 1
    fi
done

failed=0
created=0

# Iterate through all skill directories
for skill in "$AGENT_SKILLS_DIR"/*; do
    # Skip files and special directories
    if [ ! -d "$skill" ]; then
        continue
    fi

    # Skip hidden directories and metadata files
    skill_name=$(basename "$skill")
    if [[ "$skill_name" == .* ]] || [[ "$skill_name" == README* ]]; then
        continue
    fi

    echo -n "Processing: $skill_name ... "

    # Check and create symlinks in the appropriate tools
    all_ok=true

    case "$skill_name" in
        codex)
            target_dirs=("$CLAUDE_SKILLS_DIR")
            ;;
        *)
            target_dirs=("$CURSOR_SKILLS_DIR" "$CLAUDE_SKILLS_DIR" "$CODEX_SKILLS_DIR")
            ;;
    esac

    for tool_dir in "${target_dirs[@]}"; do
        symlink_path="$tool_dir/$skill_name"

        if [ -e "$symlink_path" ] || [ -L "$symlink_path" ]; then
            echo ""
            echo -e "${RED}✗ Already exists: $symlink_path${NC}"
            all_ok=false
            failed=$((failed + 1))
        fi
    done

    if [ "$all_ok" = true ]; then
        # Create symlinks
        for tool_dir in "${target_dirs[@]}"; do
            ln -s "$skill" "$tool_dir/$skill_name"
        done
        echo -e "${GREEN}✓ Created${NC}"
        created=$((created + 1))
    fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Summary: ${GREEN}$created created${NC}, ${RED}$failed failed${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $failed -gt 0 ]; then
    exit 1
fi

echo -e "${GREEN}✓ All symlinks created successfully!${NC}"
