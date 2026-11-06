#!/usr/bin/env bash
#
# push-to-github.sh — replace the ENTIRE contents of a GitHub repo with this
# project, in a single commit.
#
#   ⚠️  DESTRUCTIVE: this deletes every existing file in the target repo.
#       The old history is preserved as a branch called `backup-before-aero`
#       unless you pass --no-backup.
#
# Usage:
#   GITHUB_TOKEN=ghp_xxx ./scripts/push-to-github.sh owner/repo
#   GITHUB_TOKEN=ghp_xxx ./scripts/push-to-github.sh owner/repo --branch main
#   GITHUB_TOKEN=ghp_xxx ./scripts/push-to-github.sh owner/repo --no-backup
#   ./scripts/push-to-github.sh owner/repo --dry-run
#
# The token is read from the environment and is NEVER written to disk,
# git config, or the remote URL that gets stored in .git/config.
#
set -euo pipefail

REPO=""
BRANCH="main"
DO_BACKUP=1
DRY_RUN=0
COMMIT_MSG="Aero TV: Flutter media player & plugin host (Phase 1 MVP)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --no-backup) DO_BACKUP=0; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --message) COMMIT_MSG="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"; exit 0 ;;
    *) REPO="$1"; shift ;;
  esac
done

if [[ -z "$REPO" ]]; then
  echo "Usage: GITHUB_TOKEN=... $0 owner/repo [--branch main] [--no-backup] [--dry-run]" >&2
  exit 1
fi

# Accept a full URL as well as owner/repo.
REPO="${REPO#https://github.com/}"
REPO="${REPO%.git}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ "$DRY_RUN" -eq 0 && -z "${GITHUB_TOKEN:-}" ]]; then
  echo "ERROR: GITHUB_TOKEN is not set." >&2
  echo "Create a fine-grained token with 'Contents: read and write' on $REPO." >&2
  exit 1
fi

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }

echo "──────────────────────────────────────────────"
echo " Target : github.com/$REPO"
echo " Branch : $BRANCH"
echo " Source : $ROOT"
echo " Backup : $([[ $DO_BACKUP -eq 1 ]] && echo 'yes (backup-before-aero)' || echo 'no')"
echo "──────────────────────────────────────────────"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] Files that would be pushed:"
  git ls-files 2>/dev/null | head -50 || find . -type f -not -path "./.git/*" | head -50
  echo "[dry-run] Nothing was pushed."
  exit 0
fi

if [[ "$DO_BACKUP" -eq 0 ]]; then
  read -r -p "This will DELETE all existing files in $REPO. Type 'yes' to continue: " CONFIRM
  [[ "$CONFIRM" == "yes" ]] || { echo "Aborted."; exit 1; }
fi

# Use a credential helper that reads the env var, so the token never lands in
# .git/config or in the remote URL.
export GIT_ASKPASS="$(mktemp)"
cat > "$GIT_ASKPASS" <<'ASKPASS'
#!/usr/bin/env bash
case "$1" in
  *Username*) echo "x-access-token" ;;
  *Password*) echo "${GITHUB_TOKEN}" ;;
  *) echo "${GITHUB_TOKEN}" ;;
esac
ASKPASS
chmod +x "$GIT_ASKPASS"
trap 'rm -f "$GIT_ASKPASS"' EXIT

REMOTE_URL="https://github.com/${REPO}.git"

# Fresh git history for the replacement commit.
rm -rf .git
git init -q
git checkout -q -b "$BRANCH"
git config user.name  "${GIT_AUTHOR_NAME:-Aero TV CI}"
git config user.email "${GIT_AUTHOR_EMAIL:-ci@aero.local}"
git remote add origin "$REMOTE_URL"

# Back up whatever is currently on the remote before we overwrite it.
if [[ "$DO_BACKUP" -eq 1 ]]; then
  echo "→ Fetching current remote state for backup…"
  if git fetch --depth=1 origin "$BRANCH" 2>/dev/null; then
    BACKUP_BRANCH="backup-before-aero-$(date -u +%Y%m%d-%H%M%S)"
    git branch "$BACKUP_BRANCH" FETCH_HEAD
    if git push -q origin "$BACKUP_BRANCH" 2>/dev/null; then
      echo "✓ Existing content backed up to branch: $BACKUP_BRANCH"
    else
      echo "! Could not push backup branch (continuing)."
    fi
  else
    echo "→ Remote branch '$BRANCH' not found or empty; nothing to back up."
  fi
fi

echo "→ Staging project files…"
git add -A
# Safety: never commit secrets even if they exist locally.
git rm -r --cached --quiet \
  apps/aero_app/android/local.properties \
  apps/aero_app/android/key.properties \
  2>/dev/null || true

FILE_COUNT="$(git diff --cached --name-only | wc -l | tr -d ' ')"
echo "→ $FILE_COUNT files staged."

git commit -q -m "$COMMIT_MSG"

echo "→ Pushing to $REPO ($BRANCH)…"
git push --force -u origin "$BRANCH"

echo ""
echo "✓ Done. Repository contents replaced."
echo "  Actions: https://github.com/$REPO/actions"
echo ""
echo "The 'Build APK' workflow will start automatically."
echo "Download the APK from the run's Artifacts section when it finishes."
