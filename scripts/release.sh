#!/bin/bash
set -e

############################################
# CONFIG (che-an)
############################################
PROD_ALIAS="prod"
DEV_ALIAS="dev"
BRANCH="main"

VERSION=$(date +"%y.%m.%d.%H.%M")

############################################
# CLEANUP: always return to DEV
############################################
cleanup() {
  echo ""
  echo "🔄 Restoring Firebase environment to DEV (che-an)"
  firebase use "$DEV_ALIAS" >/dev/null || true
  echo "✅ Firebase environment set to DEV"
}
trap cleanup EXIT

############################################
# START
############################################
echo "🚀 Starting PRODUCTION release (che-an)"
echo "🏷️  Version: $VERSION"
echo ""

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
  echo "📄 This means you have changes that are NOT committed yet."
  echo ""
  echo "📄 Here is what is dirty:"
  echo "----------------------------------------"
  git status
  echo "----------------------------------------"
  echo ""

  echo "🧠 Before releasing to PRODUCTION, please reflect:"
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

  echo ""
  echo "📦 Committing changes..."
  git add -A
  git commit -m "release: $RELEASE_NOTES ($VERSION)"

else
  echo "✅ Git working tree is clean."

  echo ""
  echo "🧠 Before releasing to PRODUCTION, please reflect:"
  read -r -p "✍️  Release notes (one sentence): " RELEASE_NOTES

  if [ -z "$RELEASE_NOTES" ]; then
    echo "❌ Release notes cannot be empty."
    exit 1
  fi
fi

############################################
# PROMOTE DEV → PROD
############################################
echo ""
echo "➡️  Promoting DEV → PROD (che-an)"
rsync -av --delete dev/ prod/

git commit -am "release: promote dev to prod ($VERSION)" || true

############################################
# UPDATE CHANGELOG
############################################
echo ""
echo "➡️  Updating changelog"
echo "- $VERSION: $RELEASE_NOTES" >> CHANGELOG.md
git commit -am "chore: update changelog for $VERSION"

############################################
# TAG RELEASE
############################################
echo ""
echo "🏷️  Tagging release"
git tag "v$VERSION"

############################################
# PUSH TO REMOTE
############################################
echo ""
echo "⬆️  Pushing to remote"
git push origin "$BRANCH" --tags

############################################
# FIREBASE DEPLOY (PROD)
############################################
echo ""
echo "🔥 Switching Firebase project to PROD (che-an)"
firebase use "$PROD_ALIAS"

echo ""
echo "🔥 Deploying to Firebase (PROD)"
firebase deploy --only hosting:"$PROD_ALIAS"

############################################
# DONE
############################################
echo ""
echo "🎉 PRODUCTION release $VERSION completed successfully (che-an)"
