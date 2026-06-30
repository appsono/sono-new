#!/bin/sh

set -eu

YEAR=$(date +%Y)
HOLDER=mathiiiiiis
export YEAR HOLDER

files=$(grep -rlE "Copyright \(C\) [0-9]{4}(-[0-9]{4})? $HOLDER" --include='*.dart' lib 2>/dev/null || true)

if [ -z "$files" ]; then
  echo "no stamped files found"
  exit 0
fi

printf '%s\n' "$files" | while IFS= read -r f; do
  perl -i -pe '
        my $y = $ENV{YEAR};
        my $h = $ENV{HOLDER};
        s/Copyright \(C\) (\d{4})(?:-\d{4})? \Q$h\E/
            ($1 eq $y) ? "Copyright (C) $1 $h" : "Copyright (C) $1-$y $h"
        /ge;
    ' "$f"
done

echo "license year set to $YEAR where applicable"
