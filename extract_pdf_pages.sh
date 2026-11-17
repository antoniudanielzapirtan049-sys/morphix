#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 INPUT.pdf FIRST_PAGE LAST_PAGE [OUTPUT.pdf]" >&2
  exit 2
}

[[ $# -ge 3 && $# -le 4 ]] || usage

input_pdf=$(realpath -- "$1")
first_page=$2
last_page=$3

for page in "$first_page" "$last_page"; do
  [[ $page =~ ^[1-9][0-9]*$ ]] || {
    echo "Page numbers must be positive integers." >&2
    exit 2
  }
done

(( first_page <= last_page )) || {
  echo "FIRST_PAGE must be less than or equal to LAST_PAGE." >&2
  exit 2
}
[[ -f $input_pdf ]] || {
  echo "Input PDF not found: $input_pdf" >&2
  exit 1
}

for command in pdfinfo pdfseparate pdfunite; do
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
(( last_page <= page_count )) || {
  echo "LAST_PAGE ($last_page) exceeds the PDF page count ($page_count)." >&2
  exit 2
}

input_dir=$(dirname -- "$input_pdf")
input_name=$(basename -- "$input_pdf")
input_stem=${input_name%.*}
output_pdf=${4:-"$input_dir/${input_stem}_pages_${first_page}-${last_page}.pdf"}
[[ $output_pdf = /* ]] || output_pdf="$PWD/$output_pdf"
[[ ! -e $output_pdf ]] || {
  echo "Output file already exists: $output_pdf" >&2
  exit 1
}

tmp_dir=$(mktemp -d)
trap 'rm -rf -- "$tmp_dir"' EXIT

pdfseparate -f "$first_page" -l "$last_page" "$input_pdf" "$tmp_dir/page-%d.pdf"
pages=()
for (( page = first_page; page <= last_page; page++ )); do
  pages+=("$tmp_dir/page-$page.pdf")
done
pdfunite "${pages[@]}" "$output_pdf"
printf 'Saved pages %s-%s to %s\n' "$first_page" "$last_page" "$output_pdf"
