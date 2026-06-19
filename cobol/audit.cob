       IDENTIFICATION DIVISION.
       PROGRAM-ID. DEEPIRI-AUDIT.
       AUTHOR. DEEPIRI.
      * Append eval records to reports/audit.ledger

       ENVIRONMENT DIVISION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT LEDGER-FILE ASSIGN TO "reports/audit.ledger"
               ORGANIZATION IS LINE SEQUENTIAL
               FILE STATUS IS WS-FS.

       DATA DIVISION.
       FILE SECTION.
       FD  LEDGER-FILE.
       01  LEDGER-LINE        PIC X(900).

       WORKING-STORAGE SECTION.
       01  WS-FS              PIC XX.
       01  WS-INPUT           PIC X(900).
       01  WS-RUN-ID          PIC X(20).
       01  WS-MODEL           PIC X(40).
       01  WS-PROMPT          PIC X(200).
       01  WS-RESPONSE        PIC X(500).
       01  WS-LATENCY         PIC 9(8).
       01  WS-STATUS          PIC X(4).
       01  WS-IDX             PIC 9(4) COMP.
       01  WS-FIELD           PIC X(200).
       01  WS-FIELD-NUM       PIC 9 COMP VALUE 1.
       01  WS-CHAR            PIC X.
       01  WS-OUT             PIC X(900).

       PROCEDURE DIVISION.
       MAIN-PARA.
           ACCEPT WS-INPUT FROM CONSOLE
           IF WS-INPUT = SPACES
               STOP RUN
           END-IF
           MOVE 1 TO WS-FIELD-NUM
           MOVE SPACES TO WS-FIELD
           PERFORM VARYING WS-IDX FROM 1 BY 1
               UNTIL WS-IDX > 900
               MOVE WS-INPUT(WS-IDX:1) TO WS-CHAR
               IF WS-CHAR = "|"
                   PERFORM STORE-FIELD
                   ADD 1 TO WS-FIELD-NUM
                   MOVE SPACES TO WS-FIELD
               ELSE
                   IF WS-CHAR NOT = SPACES OR WS-FIELD NOT = SPACES
                       STRING WS-FIELD DELIMITED BY SPACE
                           WS-CHAR DELIMITED BY SIZE
                           INTO WS-FIELD
                   END-IF
               END-IF
           END-PERFORM
           PERFORM STORE-FIELD
           MOVE SPACES TO WS-OUT
           STRING
               "RUN-ID     " DELIMITED BY SIZE WS-RUN-ID DELIMITED BY "  "
               " MODEL      " DELIMITED BY SIZE WS-MODEL DELIMITED BY "  "
               " PROMPT     " DELIMITED BY SIZE WS-PROMPT DELIMITED BY "  "
               " RESPONSE   " DELIMITED BY SIZE WS-RESPONSE DELIMITED BY "  "
               " LATENCY-MS " DELIMITED BY SIZE WS-LATENCY DELIMITED BY "  "
               " STATUS     " DELIMITED BY SIZE WS-STATUS DELIMITED BY "  "
               INTO WS-OUT
           OPEN EXTEND LEDGER-FILE
           IF WS-FS NOT = "00"
               DISPLAY "AUDIT FAIL FS=" WS-FS
               STOP RUN GIVING 1
           END-IF
           WRITE LEDGER-LINE FROM WS-OUT
           CLOSE LEDGER-FILE
           DISPLAY "AUDIT OK"
           STOP RUN.

       STORE-FIELD.
           EVALUATE WS-FIELD-NUM
               WHEN 1 MOVE WS-FIELD TO WS-RUN-ID
               WHEN 2 MOVE WS-FIELD TO WS-MODEL
               WHEN 3 MOVE WS-FIELD TO WS-PROMPT
               WHEN 4 MOVE WS-FIELD TO WS-RESPONSE
               WHEN 5 MOVE WS-FIELD TO WS-LATENCY
               WHEN 6 MOVE WS-FIELD TO WS-STATUS
           END-EVALUATE
           EXIT PARAGRAPH.
