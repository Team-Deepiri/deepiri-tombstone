#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
errors=0
pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; errors=$((errors + 1)); }

echo "=== B classic core / bridge tests ==="

CORE="$ROOT/bin/deepiri-tombstone-core"
if [[ -x "$CORE" ]]; then
  pass "deepiri-tombstone-core is built"
else
  fail "deepiri-tombstone-core missing — run make"
fi

# In-process JSON extract (no Ollama)
cat > /tmp/dt_parse_test.c <<'EOF'
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
typedef long word_t;
word_t parse_response_json(word_t raw, word_t out, word_t outlen);
int main(void) {
  char out[256];
  const char *raw = "{\"model\":\"x\",\"response\":\"Hello\\nWorld\",\"done\":true}";
  long n = parse_response_json((word_t)raw, (word_t)out, 256);
  if (n <= 0) return 1;
  if (strcmp(out, "Hello\nWorld") != 0) {
    fprintf(stderr, "got [%s]\n", out);
    return 2;
  }
  return 0;
}
EOF
if cc -o /tmp/dt_parse_test /tmp/dt_parse_test.c "$ROOT/src/bridge/ollama_bridge.o" -lcurl 2>/dev/null \
   && /tmp/dt_parse_test; then
  pass "parse_response_json extracts escaped response"
else
  fail "parse_response_json extracts escaped response"
fi

# In-process tokenize budget
cat > /tmp/dt_tok_test.c <<'EOF'
typedef long word_t;
word_t run_tokenize(word_t prompt);
int main(void) {
  long n = run_tokenize((word_t)"one two three");
  return n == 3 ? 0 : 1;
}
EOF
if cc -o /tmp/dt_tok_test /tmp/dt_tok_test.c "$ROOT/src/bridge/ollama_bridge.o" -lcurl 2>/dev/null \
   && /tmp/dt_tok_test; then
  pass "run_tokenize counts words in-process"
else
  fail "run_tokenize counts words in-process"
fi

# Stats + ledger batch without network
cat > /tmp/dt_stats_test.c <<'EOF'
#include <stdio.h>
typedef long word_t;
word_t stats_reset(void);
word_t stats_record(word_t, word_t, word_t, word_t);
word_t stats_pass_rate(void);
word_t ledger_queue(word_t);
word_t ledger_flush(void);
word_t write_summary(void);
word_t format_audit(word_t, word_t, word_t, word_t, word_t, word_t, word_t, word_t);
int main(void) {
  char line[512];
  stats_reset();
  stats_record(1, 10, 5, 0);
  stats_record(0, 20, 3, 1);
  if (stats_pass_rate() != 50) return 2;
  format_audit((word_t)line, 512, (word_t)"r1", (word_t)"m",
               (word_t)"p|ipe", (word_t)"resp", 10, (word_t)"PASS");
  ledger_queue((word_t)line);
  ledger_flush();
  write_summary();
  return 0;
}
EOF
if cc -o /tmp/dt_stats_test /tmp/dt_stats_test.c "$ROOT/src/bridge/ollama_bridge.o" -lcurl 2>/dev/null \
   && (cd "$ROOT" && /tmp/dt_stats_test); then
  pass "stats_record / ledger_queue / write_summary"
else
  fail "stats_record / ledger_queue / write_summary"
fi

# CLI wires classic B commands
CLI="$ROOT/deepiri-tombstone"
for cmd in models warm summary; do
  if grep -qE "ping\|ask\|models\|warm\|summary|${cmd}" "$CLI" 2>/dev/null \
     || grep -q "$cmd" "$CLI"; then
    pass "dispatcher mentions $cmd"
  else
    fail "dispatcher mentions $cmd"
  fi
done

if "$CLI" help 2>&1 | grep -qi "warm"; then
  pass "help lists warm"
else
  fail "help lists warm"
fi

if grep -q "keep-alive+cache+batch" "$CLI" || "$CLI" help 2>&1 | grep -qi "fail-fast\|keep-alive"; then
  pass "help/classic path documents keep-alive bridge"
else
  fail "help/classic path documents keep-alive bridge"
fi

# B sources expose the castle commands
if grep -q "cmd_warm" "$ROOT/src/orchestrator/cli.b" \
   && grep -q "cmd_eval" "$ROOT/src/orchestrator/cli.b" \
   && grep -q "fail_fast_limit" "$ROOT/src/orchestrator/cli.b"; then
  pass "B cli.b has warm/eval/fail-fast"
else
  fail "B cli.b has warm/eval/fail-fast"
fi

if grep -q "ollama_warm\|ledger_queue\|parse_response_json" "$ROOT/src/bridge/ollama_bridge.c"; then
  pass "bridge exports warm/ledger/parse"
else
  fail "bridge exports warm/ledger/parse"
fi

echo ""
if [[ "$errors" -eq 0 ]]; then echo "ALL B CORE TESTS PASSED"
else echo "$errors B CORE TEST(S) FAILED"; fi
exit "$errors"
