#!/bin/sh
# Formats Dart sources with `dart format` (page width 120), keeping its two-space indentation (canon 006).
# tool/comment_spacing.pl then adds the empty line canon 003 wants above multi-line comments, except right after
# `{`, where dart format leaves none (canon 006).
# Usage: tool/format.sh [paths...]   (default: packages)
set -eu

cd "$(dirname "$0")/.."
[ $# -eq 0 ] && set -- packages

dart format --page-width 120 "$@" >/dev/null
find "$@" -name '*.dart' -type f -exec perl tool/comment_spacing.pl {} +
