#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ENV_FILE="$REPO_ROOT/.env"
PRIVATE_DIR="$REPO_ROOT/private"
OUTPUT_DIR="$REPO_ROOT/public-encrypted"

if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env not found at $ENV_FILE" >&2
  exit 1
fi

# Load .env (skip comments and blank lines)
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
  export "$key=$value"
done < "$ENV_FILE"

if [ -z "${ENCRYPTION_SECRET:-}" ]; then
  echo "Error: ENCRYPTION_SECRET is not set in .env" >&2
  exit 1
fi

# Nothing to encrypt if private/ is empty
if [ -z "$(find "$PRIVATE_DIR" -type f ! -name '.gitkeep')" ]; then
  echo "No files in private/ to encrypt."
  exit 0
fi

find "$PRIVATE_DIR" -type f ! -name '.gitkeep' | while IFS= read -r file; do
  relative="${file#$PRIVATE_DIR/}"
  output="$OUTPUT_DIR/${relative}.enc"
  mkdir -p "$(dirname "$output")"
  openssl enc -aes-256-cbc -pbkdf2 -salt \
    -in "$file" \
    -out "$output" \
    -pass env:ENCRYPTION_SECRET
  echo "Encrypted: private/$relative → public-encrypted/${relative}.enc"
done
