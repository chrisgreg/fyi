#!/bin/bash
set -e

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current version from mix.exs
CURRENT_VERSION=$(grep '@version' mix.exs | sed 's/.*"\(.*\)".*/\1/')

echo -e "${GREEN}Current version: ${CURRENT_VERSION}${NC}"
echo ""

# Parse version
IFS='.' read -r -a VERSION_PARTS <<< "$CURRENT_VERSION"
MAJOR="${VERSION_PARTS[0]}"
MINOR="${VERSION_PARTS[1]}"
PATCH="${VERSION_PARTS[2]}"

# Determine new version based on argument
case "${1:-}" in
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="${NEW_MAJOR}.0.0"
    ;;
  minor)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
    ;;
  patch)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    ;;
  *)
    echo -e "${RED}Usage: $0 {major|minor|patch}${NC}"
    echo ""
    echo "Examples:"
    echo "  $0 patch  # ${CURRENT_VERSION} -> ${MAJOR}.${MINOR}.$((PATCH + 1))"
    echo "  $0 minor  # ${CURRENT_VERSION} -> ${MAJOR}.$((MINOR + 1)).0"
    echo "  $0 major  # ${CURRENT_VERSION} -> $((MAJOR + 1)).0.0"
    exit 1
    ;;
esac

echo -e "${YELLOW}Releasing version ${NEW_VERSION}${NC}"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo -e "${RED}Error: You have uncommitted changes. Please commit or stash them first.${NC}"
  exit 1
fi

# Check if on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
  echo -e "${YELLOW}Warning: You're not on the main branch (current: ${CURRENT_BRANCH})${NC}"
  read -p "Continue anyway? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Check if [Unreleased] section exists
if ! grep -q "## \[Unreleased\]" CHANGELOG.md; then
  echo -e "${RED}Error: No [Unreleased] section found in CHANGELOG.md${NC}"
  echo "Please add your changes to an [Unreleased] section first."
  exit 1
fi

# Check if there are actual changes in [Unreleased]
if grep -A 3 "## \[Unreleased\]" CHANGELOG.md | grep -q "^## \["; then
  echo -e "${RED}Error: [Unreleased] section appears to be empty${NC}"
  echo "Please add your changes to the [Unreleased] section first."
  exit 1
fi

echo "📝 Updating mix.exs..."
sed -i.bak "s/@version \"${CURRENT_VERSION}\"/@version \"${NEW_VERSION}\"/" mix.exs
rm mix.exs.bak

echo "📝 Updating CHANGELOG.md..."
TODAY=$(date +%Y-%m-%d)
sed -i.bak "s/## \[Unreleased\]/## [${NEW_VERSION}] - ${TODAY}/" CHANGELOG.md
rm CHANGELOG.md.bak

# Add a new [Unreleased] section at the top
sed -i.bak "/^## \[${NEW_VERSION}\]/i\\
## [Unreleased]\\
\\
" CHANGELOG.md
rm CHANGELOG.md.bak

echo "✅ Committing changes..."
git add mix.exs CHANGELOG.md
git commit -m "Release v${NEW_VERSION}"

echo "🏷️  Creating git tag..."
git tag "v${NEW_VERSION}"

echo ""
echo -e "${GREEN}✨ Release ${NEW_VERSION} prepared successfully!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review the commit and tag:"
echo "     git show"
echo "     git show v${NEW_VERSION}"
echo ""
echo "  2. Push to GitHub (this will trigger the publish workflow):"
echo "     git push origin main --tags"
echo ""
echo "  3. The GitHub Action will automatically publish to Hex.pm"
echo ""
echo -e "${YELLOW}Note: You can undo this release with:${NC}"
echo "  git reset --hard HEAD~1"
echo "  git tag -d v${NEW_VERSION}"
