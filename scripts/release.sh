#!/bin/bash
set -e

############################################
# CONFIG (chean.co)
############################################
DEV_ALIAS="dev"
PROD_ALIAS="prod"
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
if [ "$(pwd)" != "$DEV_ROOT" ]; then
  echo "❌ Must run from:"
  echo "   $DEV_ROOT"
  exit 1
fi

############################################
# CHECK BRANCH
############################################
echo "➡️  Checking git branch"
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ Releases must be from '$BRANCH'"
  exit 1
fi

############################################
# CHECK WORKING TREE
############################################
echo "➡️  Checking git working tree"

if ! git diff-index --quiet HEAD --; then
  echo "⚠️  Git working tree is DIRTY."
  git status
  echo ""

  read -r -p "✍️  Release notes (one sentence): " RELEASE_NOTES
  [ -z "$RELEASE_NOTES" ] && exit 1

  read -r -p "✅ Commit these changes and continue release? (y/n): " CONFIRM
  [[ "$CONFIRM" != "y" ]] && exit 1

  git add -A
  git commit -m "release(chean.co): $RELEASE_NOTES ($VERSION)"
else
  read -r -p "✍️  Release notes (one sentence): " RELEASE_NOTES
  [ -z "$RELEASE_NOTES" ] && exit 1
fi

############################################
# TAG RELEASE (DEV REPO ONLY)
############################################
git tag "chean-co-v$VERSION"
git push origin "$BRANCH" --tags

############################################
# DEPLOY DEV
############################################
echo ""
echo "🧪 Deploying DEV environment"
firebase use "$DEV_ALIAS"
firebase deploy --only hosting

############################################
# PROMOTE DEV → PROD (FILES ONLY)
############################################
echo ""
echo "➡️  Promoting DEV → PROD (chean.co)"
rsync -av --delete \
  --exclude=".git" \
  --exclude=".firebase" \
  --exclude="node_modules" \
  "$DEV_ROOT/" "$PROD_ROOT/"

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
