#!/bin/bash
set -e

############################################
# CONFIG (chean.co)
############################################
PROD_ALIAS="prod"
DEV_ALIAS="dev"
BRANCH="main"

DEV_ROOT="/Users/elior/Web/chean/dev/chean_co"
PROD_ROOT="/Users/elior/Web/chean/prod/chean_co"

VERSION=$(date +"%y.%m.%d.%H.%M")

############################################
# CLEANUP: always return to DEV
############################################
cleanup() {
  echo ""
  echo "🔄 Restoring Firebase environment to DEV (chean.co)"
  firebase use "$DEV_ALIAS" >/dev/null || true
  echo "✅ Firebase environment set to DEV"
}
trap cleanup EXIT

############################################
# START
############################################
echo "🚀 Starting DEV + PROD release (chean.co)"
echo "🏷️  Version: $VERSION"
echo ""

############################################
# ENSURE RUN FROM DEV ROOT
############################################
CURRENT_DIR=$(pwd)
if [ "$CURRENT_DIR" != "$DEV_ROOT" ]; then
  echo "❌ This script must be run from:"
  echo "   $DEV_ROOT"
  echo "   Current dir: $CURRENT_DIR"
  exit 1
fi

############################################
# CHECK BRANCH
############################################
echo "➡️  Checking git branch"
CURRENT_BRANCH=$(git branch --show-current)

if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ You are on '$CURRENT_BRANCH'. Releases must be from '$BRANCH'."
  exit 1
fi

############################################
# CHECK WORKING TREE
############################################
echo "➡️  Checking git working tree"

if ! git diff-index --quiet HEAD --; then
  echo ""
  echo "⚠️  Git working tree is DIRTY."
  echo ""
  git status
  echo ""

  read -r -p "✍️  Release notes (one sentence): " RELEASE_NOTES
  if [ -z "$RELEASE_NOTES" ]; then
    echo "❌ Release notes cannot be empty."
    exit 1
  fi

  read -r -p "✅ Commit these changes and continue release? (y/n): " CONFIRM
  if [[ "$CONFIRM" != "y" ]]; then
    echo "❌ Release aborted."
    exit 1
  fi

  echo "📦 Committing changes..."
  git add -A
  git commit -m "release(chean.co): $RELEASE_NOTES ($VERSION)"
else
  echo "✅ Git working tree is clean."

  read -r -p "✍️  Release notes (one sentence): " RELEASE_NOTES
  if [ -z "$RELEASE_NOTES" ]; then
    echo "❌ Release notes cannot be empty."
    exit 1
  fi
fi

############################################
# DEPLOY DEV
############################################
echo ""
echo "🧪 Deploying DEV environment"
firebase use "$DEV_ALIAS"
firebase deploy --only hosting

############################################
# PROMOTE DEV → PROD (filesystem only)
############################################
echo ""
echo "➡️  Promoting DEV → PROD (chean.co)"
rsync -av --delete \
  --exclude=".git" \
  --exclude="node_modules" \
  "$DEV_ROOT/" "$PROD_ROOT/"

############################################
# UPDATE PROD CHANGELOG
############################################
echo "- $VERSION: $RELEASE_NOTES" >> "$PROD_ROOT/CHANGELOG.md"

############################################
# COMMIT PROD PROMOTION
############################################
cd "$PROD_ROOT"
git add -A
git commit -m "release(chean.co): promote dev to prod ($VERSION)" || true

############################################
# TAG + PUSH
############################################
git tag "chean-co-v$VERSION"
git push origin "$BRANCH" --tags

############################################
# DEPLOY PROD
############################################
echo ""
echo "🔥 Deploying PROD environment"
firebase use "$PROD_ALIAS"
firebase deploy --only hosting

############################################
# DONE
############################################
echo ""
echo "🎉 DEV + PROD release $VERSION completed successfully (chean.co)"
