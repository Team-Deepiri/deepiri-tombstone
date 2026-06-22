C     deepiri-tombstone Fortran scorer — enhanced with percentiles,
C     category tracking, quality metrics, and trending.
C     Usage: score <latency_ms> <response_file> [category]
C     Appends to reports/stats.dat and writes reports/summary.txt
C     with rich statistics.
      PROGRAM SCORE
      IMPLICIT NONE
      CHARACTER*512 ARG1, ARG2, ARG3, LINE, CAT
      CHARACTER*8 TIMESTAMP
      INTEGER LATENCY, LENGTH, PASS, UNIT, IOS, N, I, J
      REAL MEAN_LAT, MEAN_LEN, PASS_RATE
      REAL P50_LAT, P95_LAT, P99_LAT, MIN_LAT, MAX_LAT
      REAL MIN_LEN, MAX_LEN, MEDIAN_LEN, QUALITY
      PARAMETER (MAX_RUNS = 10000)
      INTEGER LATS(MAX_RUNS), LENS(MAX_RUNS), PASSES(MAX_RUNS)
      INTEGER CAT_PASS(10), CAT_TOTAL(10)
      CHARACTER*32 CAT_NAMES(10)
      REAL CAT_RATE(10)
      INTEGER NCATS, CI, TMP

      DO 5 CI = 1, 10
        CAT_PASS(CI) = 0
        CAT_TOTAL(CI) = 0
        CAT_NAMES(CI) = ' '
        CAT_RATE(CI) = 0.0
    5 CONTINUE
      NCATS = 0

      IF (IARGC() .LT. 2) THEN
        PRINT *, 'usage: score <latency_ms> <response_file> [category]'
        CALL EXIT(1)
      END IF

      CALL GETARG(1, ARG1)
      CALL GETARG(2, ARG2)
      READ(ARG1, *, IOSTAT=IOS) LATENCY
      IF (IOS .NE. 0) THEN
        PRINT *, 'ERROR: invalid latency value: ', TRIM(ARG1)
        CALL EXIT(1)
      END IF

      CAT = 'general'
      IF (IARGC() .GE. 3) THEN
        CALL GETARG(3, ARG3)
        IF (ARG3 .NE. ' ') CAT = ARG3
      END IF

      CALL GET_TIMESTAMP(TIMESTAMP)

      LENGTH = 0
      PASS = 0
      OPEN(UNIT=11, FILE=ARG2, STATUS='OLD', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        READ(11, '(A)', IOSTAT=IOS) LINE
        IF (IOS .EQ. 0) THEN
          LENGTH = LEN_TRIM(LINE)
          IF (LENGTH .GT. 0) PASS = 1
        END IF
        CLOSE(11)
      ELSE
        PRINT *, 'WARNING: response file not found: ', TRIM(ARG2)
      END IF

      OPEN(UNIT=12, FILE='reports/stats.dat', STATUS='UNKNOWN',
     &     POSITION='APPEND', IOSTAT=IOS)
      IF (IOS .NE. 0) THEN
        PRINT *, 'ERROR: cannot open reports/stats.dat'
        CALL EXIT(1)
      END IF
      WRITE(12, '(I10,1X,I10,1X,I2,1X,A8,1X,A)')
     &      LATENCY, LENGTH, PASS, TRIM(TIMESTAMP), TRIM(CAT)
      CLOSE(12)

      PRINT '(A,I0,A,I0,A,I0,A,A)',
     &      'SCORE latency=', LATENCY,
     &      ' length=', LENGTH,
     &      ' pass=', PASS,
     &      ' cat=', TRIM(CAT)

      N = 0
      MEAN_LAT = 0.0
      MEAN_LEN = 0.0
      PASS_RATE = 0.0
      MIN_LAT = 999999.0
      MAX_LAT = 0.0
      MIN_LEN = 999999.0
      MAX_LEN = 0.0

      OPEN(UNIT=13, FILE='reports/stats.dat', STATUS='OLD',
     &     IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
   10   READ(13, *, END=20) LATS(N+1), LENS(N+1), PASSES(N+1)
        N = N + 1
        IF (N .GT. MAX_RUNS) GO TO 20
        MEAN_LAT = MEAN_LAT + REAL(LATS(N))
        MEAN_LEN = MEAN_LEN + REAL(LENS(N))
        PASS_RATE = PASS_RATE + REAL(PASSES(N))
        IF (REAL(LATS(N)) .LT. MIN_LAT) MIN_LAT = REAL(LATS(N))
        IF (REAL(LATS(N)) .GT. MAX_LAT) MAX_LAT = REAL(LATS(N))
        IF (REAL(LENS(N)) .LT. MIN_LEN) MIN_LEN = REAL(LENS(N))
        IF (REAL(LENS(N)) .GT. MAX_LEN) MAX_LEN = REAL(LENS(N))
        CI = LAT_CATEGORY(LATS(N))
        CAT_TOTAL(CI) = CAT_TOTAL(CI) + 1
        IF (PASSES(N) .EQ. 1) CAT_PASS(CI) = CAT_PASS(CI) + 1
        GO TO 10
   20   CLOSE(13)
        IF (N .GT. 0) THEN
          MEAN_LAT = MEAN_LAT / REAL(N)
          MEAN_LEN = MEAN_LEN / REAL(N)
          PASS_RATE = 100.0 * PASS_RATE / REAL(N)
        END IF
      END IF

      P50_LAT = 0.0
      P95_LAT = 0.0
      P99_LAT = 0.0
      MEDIAN_LEN = 0.0
      QUALITY = 0.0
      IF (N .GT. 0) THEN
        CALL SORT_INT(LATS, N)
        CALL SORT_INT(LENS, N)
        P50_LAT = PERCENTILE(LATS, N, 50)
        P95_LAT = PERCENTILE(LATS, N, 95)
        P99_LAT = PERCENTILE(LATS, N, 99)
        MEDIAN_LEN = PERCENTILE_REAL(REAL(LENS), N, 50)
        QUALITY = PASS_RATE
        IF (MEAN_LEN .GT. 0.0) THEN
          QUALITY = PASS_RATE * 0.7 +
     &              MIN(100.0, MEAN_LEN / 50.0) * 0.3
        END IF
      END IF

      DO 30 CI = 1, 10
        IF (CAT_TOTAL(CI) .GT. 0) THEN
          CAT_RATE(CI) = 100.0 * REAL(CAT_PASS(CI)) /
     &                   REAL(CAT_TOTAL(CI))
        END IF
   30 CONTINUE

      OPEN(UNIT=14, FILE='reports/summary.txt', STATUS='REPLACE',
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN
        PRINT *, 'ERROR: cannot write reports/summary.txt'
        CALL EXIT(1)
      END IF
      WRITE(14, '(A,I0)') 'RUNS ', N
      WRITE(14, '(A,F12.2)') 'MEAN_LATENCY_MS ', MEAN_LAT
      WRITE(14, '(A,F12.2)') 'P50_LATENCY_MS ', P50_LAT
      WRITE(14, '(A,F12.2)') 'P95_LATENCY_MS ', P95_LAT
      WRITE(14, '(A,F12.2)') 'P99_LATENCY_MS ', P99_LAT
      WRITE(14, '(A,F12.2)') 'MIN_LATENCY_MS ', MIN_LAT
      WRITE(14, '(A,F12.2)') 'MAX_LATENCY_MS ', MAX_LAT
      WRITE(14, '(A,F12.2)') 'MEAN_LENGTH ', MEAN_LEN
      WRITE(14, '(A,F12.2)') 'MEDIAN_LENGTH ', MEDIAN_LEN
      WRITE(14, '(A,F12.2)') 'MIN_LENGTH ', MIN_LEN
      WRITE(14, '(A,F12.2)') 'MAX_LENGTH ', MAX_LEN
      WRITE(14, '(A,F8.2)') 'PASS_RATE_PCT ', PASS_RATE
      WRITE(14, '(A,F8.2)') 'QUALITY_SCORE ', QUALITY
      CLOSE(14)

      OPEN(UNIT=15, FILE='reports/category_stats.txt',
     &     STATUS='REPLACE', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        WRITE(15, '(A)') 'CATEGORY PASS_RATE_PCT TOTAL'
        DO 35 CI = 1, 10
          IF (CAT_TOTAL(CI) .GT. 0 .AND.
     &        CAT_NAMES(CI) .NE. ' ') THEN
            WRITE(15, '(A,F8.2,I6)')
     &        TRIM(CAT_NAMES(CI)), CAT_RATE(CI), CAT_TOTAL(CI)
          END IF
   35   CONTINUE
        CLOSE(15)
      END IF

      OPEN(UNIT=16, FILE='reports/trend.dat',
     &     STATUS='UNKNOWN', POSITION='APPEND', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        WRITE(16, '(A,1X,F8.2,1X,F8.2,1X,F8.2,1X,F8.2)')
     &    TRIM(TIMESTAMP), MEAN_LAT, PASS_RATE, MEAN_LEN, QUALITY
        CLOSE(16)
      END IF

      END

      INTEGER FUNCTION LAT_CATEGORY(L)
      INTEGER L
      IF (L .LT. 1000) THEN
        LAT_CATEGORY = 1
      ELSE IF (L .LT. 5000) THEN
        LAT_CATEGORY = 2
      ELSE IF (L .LT. 15000) THEN
        LAT_CATEGORY = 3
      ELSE IF (L .LT. 30000) THEN
        LAT_CATEGORY = 4
      ELSE
        LAT_CATEGORY = 5
      END IF
      RETURN
      END

      SUBROUTINE SORT_INT(ARR, N)
      INTEGER ARR(*), N, I, J, TMP
      DO 100 I = 1, N-1
        DO 100 J = I+1, N
          IF (ARR(I) .GT. ARR(J)) THEN
            TMP = ARR(I)
            ARR(I) = ARR(J)
            ARR(J) = TMP
          END IF
  100 CONTINUE
      END

      REAL FUNCTION PERCENTILE(ARR, N, P)
      INTEGER ARR(*), N, P, IDX
      REAL FRAC
      IDX = (P * N + 99) / 100
      IF (IDX .LT. 1) IDX = 1
      IF (IDX .GT. N) IDX = N
      PERCENTILE = REAL(ARR(IDX))
      RETURN
      END

      REAL FUNCTION PERCENTILE_REAL(ARR, N, P)
      REAL ARR(*)
      INTEGER N, P, IDX
      IDX = (P * N + 99) / 100
      IF (IDX .LT. 1) IDX = 1
      IF (IDX .GT. N) IDX = N
      PERCENTILE_REAL = ARR(IDX)
      RETURN
      END

      SUBROUTINE GET_TIMESTAMP(TS)
      CHARACTER*8 TS
      INTEGER VALUES(8)
      CALL DATE_AND_TIME(VALUES=VALUES)
      WRITE(TS, '(I4.4,2I2.2)') VALUES(1), VALUES(2), VALUES(3)
      END
