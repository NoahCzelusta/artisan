#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-"$ROOT_DIR/.scratch/benchmark-fixtures"}"
TARGET_BYTES="${ARTISAN_BENCH_FIXTURE_BYTES:-10485760}"

mkdir -p "$OUT_DIR"

generate_ts() {
  perl - "$TARGET_BYTES" > "$OUT_DIR/large.ts" <<'PERL'
use strict;
use warnings;
my $target = shift @ARGV;
my $bytes = 0;
my $i = 0;
while ($bytes < $target) {
  my $line = sprintf(
    "export const value_%06d: string = `template-%06d`; type Item%06d = { id: number; label: string; active?: boolean }; // benchmark TypeScript fixture\n",
    $i, $i, $i
  );
  print $line;
  $bytes += length($line);
  $i++;
}
PERL
}

generate_md() {
  perl - "$TARGET_BYTES" > "$OUT_DIR/large.md" <<'PERL'
use strict;
use warnings;
my $target = shift @ARGV;
my $bytes = 0;
my $i = 0;
while ($bytes < $target) {
  my $line = sprintf(
    "## Section %06d\n\nThis benchmark paragraph contains `inline_code_%06d`, links, emphasis, and text for viewport rendering.\n\n```ts\nconst value_%06d = \"markdown fixture\";\n```\n\n",
    $i, $i, $i
  );
  print $line;
  $bytes += length($line);
  $i++;
}
PERL
}

generate_txt() {
  perl - "$TARGET_BYTES" > "$OUT_DIR/large.txt" <<'PERL'
use strict;
use warnings;
my $target = shift @ARGV;
my $bytes = 0;
my $i = 0;
while ($bytes < $target) {
  my $line = sprintf(
    "Plain text benchmark line %06d abcdefghijklmnopqrstuvwxyz 0123456789 repeated content for scrolling and editing.\n",
    $i
  );
  print $line;
  $bytes += length($line);
  $i++;
}
PERL
}

generate_ts
generate_md
generate_txt

wc -c "$OUT_DIR"/large.ts "$OUT_DIR"/large.md "$OUT_DIR"/large.txt
