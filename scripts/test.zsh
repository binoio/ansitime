#!/usr/bin/env zsh
set -euo pipefail

# ANSITime Test Suite Runner
# Usage:
#   ./scripts/test.zsh          # Run native unit tests via Swift Package Manager
#   ./scripts/test.zsh --docker # Run containerized test suite via Docker

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ "${1:-}" == "--docker" ]]; then
    echo "==> Running test suite in Linux container (Docker)..."
    if command -v docker-compose &>/dev/null; then
        docker-compose run --rm test
    elif command -v docker &>/dev/null; then
        docker compose run --rm test
    else
        echo "Error: docker / docker compose not found." >&2
        exit 1
    fi
else
    echo "==> Running local native Swift unit tests..."
    swift test
fi

echo "==> All test suites passed!"
