#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 INPUT.pdf PAGE_NUMBER [OUTPUT.txt]" >&2
  exit 2
}

[[ $# -ge 2 && $# -le 3 ]] || usage

input_pdf=$(realpath -- "$1")
page=$2
[[ $page =~ ^[1-9][0-9]*$ ]] || {
  echo "PAGE_NUMBER must be a positive integer." >&2
  exit 2
}
[[ -f $input_pdf ]] || {
  echo "Input PDF not found: $input_pdf" >&2
  exit 1
}
for command in pdfinfo pdftotext; do
  command -v "$command" >/dev/null 2>&1 || {
    echo "Required command not found: $command (install Poppler)." >&2
    exit 1
  }
done

page_count=$(pdfinfo "$input_pdf" | awk '$1 == "Pages:" { print $2; exit }')
[[ $page_count =~ ^[1-9][0-9]*$ ]] || {
  echo "Could not read the page count from: $input_pdf" >&2
  exit 1
}
(( page <= page_count )) || {
  echo "PAGE_NUMBER ($page) exceeds the PDF page count ($page_count)." >&2
  exit 2
}

input_dir=$(dirname -- "$input_pdf")
input_name=$(basename -- "$input_pdf")
input_stem=${input_name%.*}
output_txt=${3:-"$input_dir/${input_stem}_page_${page}.txt"}
[[ $output_txt = /* ]] || output_txt="$PWD/$output_txt"
[[ ! -e $output_txt ]] || {
  echo "Output file already exists: $output_txt" >&2
  exit 1
}

pdftotext -f "$page" -l "$page" "$input_pdf" "$output_txt"
printf 'Saved text from page %s to %s\n' "$page" "$output_txt"
