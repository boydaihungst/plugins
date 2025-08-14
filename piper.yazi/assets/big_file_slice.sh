#!/usr/bin/env bash
file="$1"
start="$2"
end="$3"

is_markdown_file() {
  case "${file,,}" in
  *.md | *.markdown | *.mdown | *.mkd | *.mkdn | *.mdtxt | *.mdtext) return 0 ;;
  *) return 1 ;;
  esac
}

if is_markdown_file; then
  # Grab a little before start and a little after end for block detection
  buffer_lines=50
  slice_start=$((start > buffer_lines ? start - buffer_lines : 1))
  slice_end=$((end + buffer_lines))

  # Pre-slice to reduce data for awk
  head -n "$slice_end" "$file" | tail -n +$slice_start |
    awk -v s="$start" -v e="$end" -v offset="$((slice_start - 1))" '
  BEGIN {
    in_code=0
    in_html=0
    in_table=0
  }
  {
    NR_adj = NR + offset

    # Detect fenced code blocks
    if ($0 ~ /^(```|~~~)/) {
      in_code = !in_code
    }

    # Detect HTML block start/end
    if ($0 ~ /^<[^/][^>]*>$/) in_html=1
    if ($0 ~ /^<\/[^>]+>$/) in_html=0

    # Detect Markdown tables
    if ($0 ~ /^[ \t]*\|.*\|[ \t]*$/) {
      in_table=1
    } else if (in_table && $0 !~ /^[ \t]*\|.*\|[ \t]*$/) {
      in_table=0
    }

    # Print conditions
    if ((NR_adj >= s && NR_adj <= e) ||
        (in_code && NR_adj >= s) ||
        (in_html && NR_adj >= s) ||
        (in_table && NR_adj >= s)) {
      print
    }

    # Stop if past end and not inside a block
    if (NR_adj > e && !in_code && !in_html && !in_table) {
      exit
    }
  }'
else
  # Non-Markdown → simple slice
  head -n "$end" "$file" | tail -n +"$start"
fi
