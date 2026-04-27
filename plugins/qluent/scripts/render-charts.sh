#!/usr/bin/env bash
# render-charts.sh — Reads qluent JSON output and generates a self-contained HTML dashboard
# Usage: render-charts.sh <input.json> <output.html>

set -euo pipefail

INPUT="${1:-/tmp/qluent-viz-data.json}"
OUTPUT="${2:-/tmp/qluent-viz.html}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/../templates/render-charts.html"

if [ ! -f "$INPUT" ]; then
  echo "Error: Input file not found: $INPUT" >&2
  exit 1
fi

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: Template file not found: $TEMPLATE" >&2
  exit 1
fi

perl -0777 -e '
  use strict;
  use warnings;

  my ($input, $template, $output) = @ARGV;

  open my $json_fh, "<", $input or die "Error: Cannot read input file: $input\n";
  my $json = <$json_fh>;
  close $json_fh;

  $json =~ s{</script>}{<\\/script>}ig;

  open my $template_fh, "<", $template or die "Error: Cannot read template file: $template\n";
  my $html = <$template_fh>;
  close $template_fh;

  $html =~ s/__QLUENT_JSON_DATA__/$json/g;

  open my $out_fh, ">", $output or die "Error: Cannot write output file: $output\n";
  print {$out_fh} $html;
  close $out_fh;
' "$INPUT" "$TEMPLATE" "$OUTPUT"

echo "$OUTPUT"
