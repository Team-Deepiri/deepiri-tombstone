\ Tokenize prompt on stdin, report word count and budget status.
\ deepiri-tombstone forth/tokenize.fs

: skip-blanks ( addr -- addr )
  BEGIN dup c@ bl WHILE 1+ REPEAT ;

: word-count ( addr -- n )
  0 swap
  BEGIN dup c@
    WHILE skip-blanks dup c@ 0= IF 2DROP EXIT THEN
      1+ skip-blanks 1+
    REPEAT
  2DROP ;

: trim ( addr -- addr )
  BEGIN dup c@ bl = WHILE 1+ REPEAT
  dup ;

: main ( -- )
  pad 256 accept drop pad trim word-count
  ." WORDS " . ." BUDGET_OK "
  dup 512 <= IF 1 ELSE 0 THEN . cr ;

main bye
