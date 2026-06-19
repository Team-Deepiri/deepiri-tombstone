# Forth tokenizer

File: `forth/tokenize.fs`
Binary: `bin/tokenize`
Fallback: `scripts/tokenize_fallback.sh`

Reads a line from stdin, counts whitespace-delimited words, and checks against a 512-word budget.

Output: `WORDS <n> BUDGET_OK <0|1>`
