.PHONY: all clean dist libdeepiri_tombstone.a combined.b \
        bin/tokenize bin/score bin/audit bin/parse bin/build_request \
        bin/http_fallback deepiri-tombstone-core deepiri-tombstone

BLANG ?= blang
CLANG ?= clang
LIBB ?= /usr/lib/libb.a

all: deepiri-tombstone

libdeepiri_tombstone.a: c/ollama_bridge.c c/ollama_bridge.h
	$(CLANG) -c -o c/ollama_bridge.o c/ollama_bridge.c
	ar rcs libdeepiri_tombstone.a c/ollama_bridge.o

combined.b: b/util.b b/cli.b b/main.b
	cat b/util.b b/cli.b b/main.b > combined.b

deepiri-tombstone-core: combined.b libdeepiri_tombstone.a
	@mkdir -p bin
	@command -v $(BLANG) >/dev/null || { echo "install blang first: ./scripts/install-deps.sh"; exit 1; }
	$(BLANG) combined.b -o combined.ll
	$(CLANG) combined.ll -L. -ldeepiri_tombstone -L/usr/lib -lb -o bin/deepiri-tombstone-core

deepiri-tombstone: deepiri-tombstone-core scripts/run-b.sh bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback
	cp scripts/run-b.sh deepiri-tombstone
	chmod +x deepiri-tombstone bin/deepiri-tombstone-core bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

bin/tokenize: forth/tokenize.fs
	@mkdir -p bin
	printf '#!/usr/bin/env bash\nset -euo pipefail\ncd "$$(dirname "$$0")/.."\ngforth -e "include forth/tokenize.fs"\n' > bin/tokenize
	chmod +x bin/tokenize

bin/score: fortran/score.f
	@mkdir -p bin reports
	gfortran -o bin/score fortran/score.f

bin/audit: cobol/audit.cob
	@mkdir -p bin reports
	cobc -x -o bin/audit cobol/audit.cob

bin/parse: awk/parse_response.awk
	@mkdir -p bin
	cp awk/parse_response.awk bin/parse
	chmod +x bin/parse

bin/build_request: scripts/build_request_fallback.sh
	@mkdir -p bin
	cp scripts/build_request_fallback.sh bin/build_request
	chmod +x bin/build_request

bin/http_fallback: perl/http_fallback.pl
	@mkdir -p bin
	cp perl/http_fallback.pl bin/http_fallback
	chmod +x bin/http_fallback

clean:
	rm -f combined.b combined.ll c/ollama_bridge.o libdeepiri_tombstone.a
	rm -f bin/deepiri-tombstone-core deepiri-tombstone
	rm -f bin/tokenize bin/score bin/audit bin/parse bin/build_request bin/http_fallback

dist: clean all
