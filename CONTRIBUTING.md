# Contributing to FYI

Thank you for your interest in contributing to FYI! This guide will help you get started.

## Development Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/chrisgreg/fyi.git
   cd fyi
   ```

2. **Install dependencies**
   ```bash
   mix deps.get
   ```

3. **Run tests**
   ```bash
   mix test
   ```

4. **Check formatting**
   ```bash
   mix format --check-formatted
   ```

## Making Changes

1. **Create a branch** for your changes
   ```bash
   git checkout -b your-feature-name
   ```

2. **Make your changes** and write tests

3. **Update the CHANGELOG**
   - Add your changes to the `[Unreleased]` section in `CHANGELOG.md`
   - Use the existing format: `- **Feature name** - Description`
   - Categorize under `### Added`, `### Changed`, `### Fixed`, or `### Removed`

4. **Ensure tests pass and code is formatted**
   ```bash
   mix test
   mix format
   ```

5. **Commit your changes**
   ```bash
   git add .
   git commit -m "Add feature X"
   ```

6. **Push and create a pull request**
   ```bash
   git push origin your-feature-name
   ```

## Release Process

> **Note**: Only maintainers can create releases.

Releases are managed using semantic versioning (MAJOR.MINOR.PATCH):
- **PATCH** (1.0.1): Bug fixes, no breaking changes
- **MINOR** (1.1.0): New features, backwards compatible
- **MAJOR** (2.0.0): Breaking changes

### Steps to Release

1. **Ensure you're on main with latest changes**
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Verify the CHANGELOG has an [Unreleased] section with changes**
   - Check that all changes since the last release are documented
   - Ensure changes are categorized properly (Added/Changed/Fixed/Removed)

3. **Run the release script**
   ```bash
   ./scripts/release.sh patch   # For bug fixes (1.0.0 -> 1.0.1)
   ./scripts/release.sh minor   # For new features (1.0.0 -> 1.1.0)
   ./scripts/release.sh major   # For breaking changes (1.0.0 -> 2.0.0)
   ```

   The script will:
   - Bump the version in `mix.exs`
   - Move `[Unreleased]` to the new version with today's date in `CHANGELOG.md`
   - Create a new empty `[Unreleased]` section
   - Commit the changes
   - Create a git tag (e.g., `v1.0.1`)

4. **Review the changes**
   ```bash
   git show              # Review the commit
   git show v1.0.1       # Review the tag
   ```

5. **Push to GitHub** (this triggers the publish workflow)
   ```bash
   git push origin main --tags
   ```

6. **GitHub Actions will automatically**:
   - Run the full test suite
   - Publish the new version to Hex.pm (using the `HEX_API_KEY` secret)

### If Something Goes Wrong

If you need to undo a release before pushing:

```bash
git reset --hard HEAD~1    # Undo the commit
git tag -d v1.0.1          # Delete the tag
```

If you already pushed, you'll need to:
1. Yank the version from Hex.pm if it was published
2. Delete the tag from GitHub
3. Revert the commit

### First-Time Release Setup

The `HEX_API_KEY` secret must be configured in GitHub:

1. Generate a Hex API key:
   ```bash
   mix hex.user key generate
   ```

2. Add it to GitHub:
   - Go to repository Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `HEX_API_KEY`
   - Value: Your generated key

## Code Style

- Follow the existing code style
- Run `mix format` before committing
- Write descriptive commit messages
- Add tests for new features
- Update documentation as needed

## Questions?

If you have questions or need help, feel free to:
- Open an issue
- Start a discussion
- Reach out to the maintainers

Thank you for contributing! 🎉
