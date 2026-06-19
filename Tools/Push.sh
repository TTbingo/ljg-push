#!/bin/bash
# skill-push: sync updated skills to individual github repos (TTbingo/<skill-name>).
#
# Each skill lives in its own git repo under ~/.workbuddy/skills/<skill-name>/,
# and pushes to git@github.com:TTbingo/<skill-name>.git
#
# Usage:
#   bash Push.sh                          # detect + push all skills with changes
#   bash Push.sh skill1 skill2            # push specific skills
#   bash Push.sh --ljg                     # ljg-* skills use dual-branch workflow
#   bash Push.sh --dry-run                 # show what would happen, don't push
#   bash Push.sh --force                   # skip detect, push all specified skills
#   bash Push.sh k12-math-tutor --ljg      # push k12-math-tutor (single branch) + ljg-* (dual branch)

set -euo pipefail

# === Configuration ===
SKILLS_LOCAL="$HOME/.workbuddy/skills"

# === Args ===
DRY_RUN=0
FORCE=0
USE_LJG_WORKFLOW=0
SKILLS_TO_PUSH=()

for arg in "$@"; do
  case "$arg" in
    --dry-run)        DRY_RUN=1 ;;
    --force)          FORCE=1 ;;
    --ljg)            USE_LJG_WORKFLOW=1 ;;
    --skip-readme-check)  SKIP_README_CHECK=1 ;;
    -*)               echo "Unknown arg: $arg" >&2; exit 2 ;;
    *)                SKILLS_TO_PUSH+=("$arg") ;;
  esac
done

# If no skills specified, discover all skill directories
if [ ${#SKILLS_TO_PUSH[@]} -eq 0 ]; then
  if [ ! -d "$SKILLS_LOCAL" ]; then
    echo "SKILLS_LOCAL ($SKILLS_LOCAL) not found." >&2
    exit 1
  fi
  for d in "$SKILLS_LOCAL"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    # Skip non-skill directories (e.g., .git)
    [ "$name" = ".git" ] && continue
    SKILLS_TO_PUSH+=("$name")
  done
fi

if [ ${#SKILLS_TO_PUSH[@]} -eq 0 ]; then
  echo "No skills found in $SKILLS_LOCAL" >&2
  exit 1
fi

# === Helpers ===
log()  { printf '\033[36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m! %s\033[0m\n' "$*"; }
err()  { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; }

# Check if a skill directory has a .git folder and valid origin
check_skill_repo() {
  local skill="$1"
  local skill_dir="$SKILLS_LOCAL/$skill"
  
  if [ ! -d "$skill_dir/.git" ]; then
    err "$skill: no .git found in $skill_dir"
    err "  Fix: cd $skill_dir && git init && git remote add origin git@github.com:TTbingo/$skill.git"
    return 1
  fi
  
  local actual
  actual=$(cd "$skill_dir" && git remote get-url origin 2>/dev/null || echo "")
  if [[ "$actual" != *"TTbingo/$skill"* ]]; then
    err "$skill: origin is '$actual', expected '*TTbingo/$skill*'"
    err "  Fix: cd $skill_dir && git remote set-url origin git@github.com:TTbingo/$skill.git"
    return 1
  fi
  return 0
}

# Detect if a skill has uncommitted changes
skill_has_changes() {
  local skill="$1"
  local skill_dir="$SKILLS_LOCAL/$skill"
  cd "$skill_dir"
  ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null || [ -n "$(git ls-files --others --exclude-standard)" ]
}

# Push a single skill (single branch: main or master)
push_skill_single() {
  local skill="$1"
  local skill_dir="$SKILLS_LOCAL/$skill"
  
  log "=== Pushing $skill (single branch) ==="
  
  if ! check_skill_repo "$skill"; then
    return 1
  fi
  
  if [ "$FORCE" != "1" ] && ! skill_has_changes "$skill"; then
    log "  No changes in $skill, skipping"
    return 0
  fi
  
  if [ "$DRY_RUN" = "1" ]; then
    log "  [dry-run] would: git add . && git commit && git push"
    return 0
  fi
  
  cd "$skill_dir"
  
  # Determine default branch
  local branch="main"
  if git rev-parse --verify master >/dev/null 2>&1; then
    branch="master"
  fi
  
  git add .
  
  # Check if there's anything to commit
  if git diff --cached --quiet; then
    log "  No staged changes, skipping commit"
    return 0
  fi
  
  # Commit with timestamp
  local timestamp
  timestamp=$(date +%Y-%m-%d)
  git commit -m "Update $skill ($timestamp)" --quiet
  
  # Pull --rebase first, then push
  git pull --rebase --quiet 2>/dev/null || {
    warn "  pull --rebase failed, trying reset --hard"
    git fetch origin "$branch" --quiet
    git reset --hard "origin/$branch"
    git add .
    git commit -m "Update $skill ($timestamp)" --quiet
  }
  
  git push origin "$branch" --quiet
  ok "$skill pushed to TTbingo/$skill ($branch)"
}

# Push ljg-* skills (dual branch: master + md)
# This uses the original ljg-skills repo workflow
push_skill_ljg() {
  local skill="$1"
  log "=== Pushing $skill (ljg dual-branch workflow) ==="
  warn "  ljg dual-branch workflow not yet implemented in generic mode"
  warn "  Falling back to single-branch push"
  push_skill_single "$skill"
}

# === Main ===

log "Skills to process: ${SKILLS_TO_PUSH[*]}"
echo ""

for skill in "${SKILLS_TO_PUSH[@]}"; do
  skill_dir="$SKILLS_LOCAL/$skill"
  
  if [ ! -d "$skill_dir" ]; then
    err "Skill directory not found: $skill_dir"
    continue
  fi
  
  # Decide which push method to use
  if [ "$USE_LJG_WORKFLOW" = "1" ] && [[ "$skill" == ljg-* ]]; then
    push_skill_ljg "$skill"
  else
    push_skill_single "$skill"
  fi
  
  echo ""
done

log "Done."
