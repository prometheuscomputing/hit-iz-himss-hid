#!/bin/bash
# Move TCAMT export folders under a domain segment (e.g. iz).
# Usage: organize_rb.sh <domain_name> <folder_path>

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <domain_name> <folder_path>" >&2
    exit 1
fi

DOMAIN=$1
FOLDER_PATH=$2

if [ ! -d "$FOLDER_PATH" ]; then
    echo "Error: $FOLDER_PATH does not exist or is not a directory." >&2
    exit 1
fi

CONTEXTBASED_PATH="$FOLDER_PATH/Contextbased"
GLOBAL_PATH="$FOLDER_PATH/Global"

if [ ! -d "$CONTEXTBASED_PATH" ] || [ ! -d "$GLOBAL_PATH" ]; then
    echo "Error: Either Contextbased or Global directory is missing in $FOLDER_PATH." >&2
    exit 1
fi

DOMAIN_CONTEXTBASED_PATH="$CONTEXTBASED_PATH/$DOMAIN"
mkdir -p "$DOMAIN_CONTEXTBASED_PATH"
shopt -s dotglob
for item in "$CONTEXTBASED_PATH"/*; do
    [ "$item" = "$DOMAIN_CONTEXTBASED_PATH" ] && continue
    mv "$item" "$DOMAIN_CONTEXTBASED_PATH"/
done
shopt -u dotglob

for dir in "$GLOBAL_PATH"/*; do
    if [ -d "$dir" ]; then
        DOMAIN_GLOBAL_PATH="$dir/$DOMAIN"
        mkdir -p "$DOMAIN_GLOBAL_PATH"
        shopt -s dotglob
        for item in "$dir"/*; do
            [ "$item" = "$DOMAIN_GLOBAL_PATH" ] && continue
            mv "$item" "$DOMAIN_GLOBAL_PATH"/
        done
        shopt -u dotglob
    fi
done

echo "Reorganization complete for domain '$DOMAIN'."
