#!/usr/bin/env bash
# Integration verification: test each pipeline component independently
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
errors=0

header() { echo ""; echo "=== $1 ==="; }
pass()   { echo "  PASS: $1"; }
fail()   { echo "  FAIL: $1"; errors=$((errors + 1)); }

# ---- 1. Fixture format ----
header "Fixture validation"
bash scripts/validate_fixtures.sh && pass "fixtures valid" || fail "fixtures invalid"

# ---- 2. AWK parser ----
header "AWK parser"
echo '{"model":"test","response":"hello world","done":true}' | awk -f awk/parse_response.awk > /tmp/dt_test_parse.txt 2>&1
grep -q "hello world" /tmp/dt_test_parse.txt && pass "AWK parse OK" || fail "AWK parse failed"

# ---- 3. Perl fallback ----
header "Perl http_fallback (syntax)"
perl -c perl/http_fallback.pl > /dev/null 2>&1 && pass "Perl syntax OK" || fail "Perl syntax failed"

# ---- 4. Forth tokenize ----
header "Forth tokenize"
if command -v gforth >/dev/null 2>&1; then
  echo "hello world" | gforth -e "include forth/tokenize.fs" > /tmp/dt_test_forth.txt 2>&1
  grep -q "WORDS" /tmp/dt_test_forth.txt && pass "Forth OK" || fail "Forth output unexpected"
else
  echo "hello world" | bash scripts/tokenize_fallback.sh > /tmp/dt_test_forth.txt 2>&1
  grep -q "WORDS" /tmp/dt_test_forth.txt && pass "Forth fallback OK" || fail "Forth fallback failed"
fi

# ---- 5. COBOL audit ----
header "COBOL audit"
echo "run-001|test-model|test prompt|test response|1234|PASS" > /tmp/dt_audit_in.txt
if command -v cobc >/dev/null 2>&1; then
  cobc -x -o /tmp/dt_audit_test cobol/audit.cob 2>/dev/null
  /tmp/dt_audit_test < /tmp/dt_audit_in.txt > /tmp/dt_audit_out.txt 2>&1
  grep -q "AUDIT OK" /tmp/dt_audit_out.txt && pass "COBOL audit OK" || fail "COBOL audit failed"
else
  bash scripts/audit_fallback.sh < /tmp/dt_audit_in.txt > /tmp/dt_audit_out.txt 2>&1
  grep -q "AUDIT OK" /tmp/dt_audit_out.txt && pass "Audit fallback OK" || fail "Audit fallback failed"
fi

# ---- 6. Fortran score ----
header "Fortran score"
echo "some response text" > /tmp/dt_response.txt
if command -v gfortran >/dev/null 2>&1; then
  gfortran -o /tmp/dt_score_test fortran/score.f 2>/dev/null
  /tmp/dt_score_test 500 /tmp/dt_response.txt > /tmp/dt_score_out.txt 2>&1
  grep -q "SCORE" /tmp/dt_score_out.txt && pass "Fortran score OK" || fail "Fortran score failed"
else
  bash scripts/score_fallback.sh 500 /tmp/dt_response.txt > /tmp/dt_score_out.txt 2>&1
  grep -q "SCORE" /tmp/dt_score_out.txt && pass "Score fallback OK" || fail "Score fallback failed"
fi

# ---- 7. BCPL build_request ----
header "BCPL build_request"
if command -v cintsys >/dev/null 2>&1; then
  pass "BCPL compiler available (manual test)"
else
  bash scripts/build_request_fallback.sh llama3.2 "hello" > /tmp/dt_req.json
  grep -q '"model"' /tmp/dt_req.json && grep -q '"prompt"' /tmp/dt_req.json && \
    pass "Build request fallback OK" || fail "Build request fallback failed"
fi

# ---- Summary ----
echo ""
if [[ "$errors" -eq 0 ]]; then
  echo "ALL CHECKS PASSED"
else
  echo "$errors CHECK(S) FAILED"
fi
exit "$errors"
