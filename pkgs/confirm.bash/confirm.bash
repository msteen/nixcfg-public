#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'EOF'
@description@.
It allows answering with the most commonly used keys for agreeing and disagreeing.

Usage:
  @pname@ <prompt>
  @pname@ (-h | --help)

Options:
  -h --help  Show this help message.
  --version  Show version information.
EOF
}

while (( $# >= 1 )); do
  case $1 in
    -h|--help) show_usage; exit;;
    --version) printf '@version@'; exit;;
    *) [[ ! -v prompt ]] && prompt=$1 || show_usage; shift;;
  esac
done

ask() {
  IFS= read -rsn1 answer
  if [[ $answer =~ ^(Y|y| )$ || -z $answer ]]; then
    code=0
  elif [[ $answer =~ ^(N|n|$'\e')$ ]]; then
    code=1
  else
    return 1
  fi
}

{
  echo -n "$prompt [Y/n] "
  if ! ask; then
    echo -n $(tput sc)"Invalid answer, it should be either Y, y, <SPACE>, or <ENTER> for agreeing; and N, n, or <ESC> for disagreeing."
    while ! ask; do :; done
    echo -n $(tput rc; tput el)
  fi
  echo -n $(tput cub 6; tput el)
  (( code )) && echo "No." || echo "Yes."
  exit "$code"
} >&2
