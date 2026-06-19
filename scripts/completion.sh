#!/usr/bin/env bash
# Bash completion for deepiri-tombstone
_deepiri_tombstone_completions() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  commands="ping ask eval"
  models="llama3.2 llama3.1 llama3 mistral phi3 gemma2"
  fixtures="fixtures/eval_prompts.txt fixtures/edge_cases.txt fixtures/benchmark_prompts.txt fixtures/stress_prompts.txt"

  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
  elif [[ $COMP_CWORD -eq 2 ]]; then
    case "$prev" in
      ask) COMPREPLY=($(compgen -W "$models" -- "$cur")) ;;
      eval) COMPREPLY=($(compgen -W "$models $fixtures" -- "$cur")) ;;
    esac
  elif [[ $COMP_CWORD -eq 3 ]]; then
    case "${COMP_WORDS[1]}" in
      ask) COMPREPLY=($(compgen -f -- "$cur")) ;;
      eval) COMPREPLY=($(compgen -W "$fixtures" -- "$cur")) ;;
    esac
  fi
}
complete -F _deepiri_tombstone_completions deepiri-tombstone
