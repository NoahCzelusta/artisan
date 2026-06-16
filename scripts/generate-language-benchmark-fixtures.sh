#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-"$ROOT_DIR/.scratch/all-language-highlighting-fixtures"}"
TARGET_BYTES="${ARTISAN_LANGUAGE_BENCH_FIXTURE_BYTES:-10485760}"

mkdir -p "$OUT_DIR"

perl - "$OUT_DIR" "$TARGET_BYTES" <<'PERL'
use strict;

my ($out_dir, $target_bytes) = @ARGV;

my @fixtures = (
  ["large.ts", q{export const value_%06d: string = `template-%06d`; type Item%06d = { id: number; label: string; active?: boolean }; // benchmark TypeScript fixture\n}],
  ["large.js", q{export const value_%06d = "template-%06d"; function render%06d() { return <section data-id="hero">%06d</section>; } // benchmark JavaScript fixture\n}],
  ["large.py", q{def value_%06d(): value = %06d; return "template-%06d"  # benchmark python\n}],
  ["Large.java", q{public class Item%06d { private int value = %06d; String name = "template-%06d"; } // benchmark java\n}],
  ["large.c", q{const int value_%06d = %06d; const char *name = "template-%06d"; // benchmark c\n}],
  ["large.cpp", q{template <typename T> auto value_%06d = %06d; std::string name = "template-%06d"; // benchmark cpp\n}],
  ["Large.cs", q{public class Item%06d { static int Value = %06d; string Name = "template-%06d"; } // benchmark csharp\n}],
  ["large.go", q{func value%06d() int { var value int = %06d; return value } // benchmark go template-%06d\n}],
  ["large.rs", q{pub fn value_%06d() -> i32 { let value: i32 = %06d; value } // benchmark rust template-%06d\n}],
  ["large.php", q{<?php function value_%06d() { $value = %06d; return "template-%06d"; } // benchmark php\n}],
  ["large.rb", q{def value_%06d; value = %06d; name = "template-%06d"; end # benchmark ruby\n}],
  ["large.swift", q{func value%06d() -> Int { let value: Int = %06d; return value } // benchmark swift template-%06d\n}],
  ["Large.kt", q{fun value%06d(): Int { val value: Int = %06d; return value } // benchmark kotlin template-%06d\n}],
  ["large.sql", q{SELECT 'template-%06d' AS label, %06d AS value FROM items WHERE active = 1; -- benchmark sql %06d\n}],
  ["large.html", q{<section data-id="item-%06d" class="benchmark">template-%06d value %06d</section>\n}],
  ["large.css", q{.item-%06d { color: "red"; margin: %06dpx; width: 100%%; } /* benchmark css %06d */\n}],
  ["large.sh", q{if test %06d -gt 0; then echo "template-%06d"; fi # benchmark shell %06d\n}],
  ["large.json", q{{"id": %06d, "label": "template-%06d", "active": true, "value": null, "index": %06d}\n}],
  ["large.yaml", q{item_%06d: "template-%06d" # benchmark yaml %06d\n}],
  ["large.r", q{value_%06d <- %06d # benchmark r template-%06d\n}],
  ["README.md", q{## Section %06d with `code_%06d` and [link](https://example.com/%06d) **bold**\n}],
  ["large.txt", q{Plain text benchmark line %06d template-%06d repeated content for language performance %06d.\n}],
  ["Makefile", q{target_%06d:\n\techo "template-%06d" # benchmark makefile %06d\n}],
  ["Dockerfile", q{RUN echo "template-%06d" && export VALUE=%06d # benchmark dockerfile %06d\n}],
  ["large.xml", q{<item id="%06d" label="template-%06d">benchmark xml %06d</item>\n}],
  ["large.toml", q{item_%06d = "template-%06d" # benchmark toml %06d\n}]
);

for my $fixture (@fixtures) {
  my ($filename, $template) = @$fixture;
  open my $fh, ">", "$out_dir/$filename" or die "could not write $filename: $!";

  my $bytes = 0;
  my $i = 0;
  while ($bytes < $target_bytes) {
    my $line = sprintf($template, $i, $i, $i, $i);
    $line =~ s/\\n/\n/g;
    $line =~ s/\\t/\t/g;
    print {$fh} $line;
    $bytes += length($line);
    $i++;
  }
  close $fh;
}
PERL

wc -c "$OUT_DIR"/*
