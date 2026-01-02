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
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  echo "❌ Releases must be from '$BRANCH'"
  exit 1
fi

############################################
# CHECK WORKING TREE
############################################
if ! git diff-index --quiet HEAD --; then
  echo "⚠️  Uncommitted changes detected:"
  git status
  echo ""

  read -r -p "✍️  Release notes: " RELEASE_NOTES
  [ -z "$RELEASE_NOTES" ] && echo "❌ Notes required." && exit 1

  read -r -p "✅ Commit and continue? (y/n): " CONFIRM
  [[ "$CONFIRM" != "y" ]] && exit 1

  git add -A
  git commit -m "release(chean.co): $RELEASE_NOTES ($VERSION)"
else
  read -r -p "✍️  Release notes: " RELEASE_NOTES
  [ -z "$RELEASE_NOTES" ] && echo "❌ Notes required." && exit 1
fi

############################################
# DEPLOY DEV
############################################
echo ""
echo "🧪 Deploying DEV environment"
firebase use "$DEV_ALIAS"
firebase deploy --only hosting:"$DEV_ALIAS"

############################################
# PROMOTE DEV → PROD (filesystem)
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
firebase deploy --only hosting:"$PROD_ALIAS"

############################################
# DONE
############################################
echo ""
echo "🎉 DEV + PROD release $VERSION completed successfully (chean.co)"
