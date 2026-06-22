C     deepiri-tombstone Fortran scorer — enhanced with percentiles,
C     category tracking, quality metrics, and trending.
C     Usage: score <latency_ms> <response_file> [category]
      PROGRAM SCORE
      IMPLICIT NONE
      INTEGER MAXRUNS
      PARAMETER (MAXRUNS = 10000)
      CHARACTER*512 ARG1, ARG2, ARG3, LINE, CAT
      CHARACTER*8 TIMESTAMP
      INTEGER LATENCY, LENGTH, ISPASS, UNIT, IOS, N, I, J, CI
      REAL MEAN_LAT, MEAN_LEN, PASS_RATE
      REAL P50, P95, P99, MINLAT, MAXLAT
      REAL MINLEN, MAXLEN, MEDLEN, QUAL
      INTEGER LATS(MAXRUNS), LENS(MAXRUNS), IPASS(MAXRUNS)
      INTEGER CPASS(10), CTOTAL(10)
      CHARACTER*32 CNAMES(10)
      REAL CRATE(10)
      INTEGER TMPVAL

      DO 5 CI = 1, 10
        CPASS(CI) = 0
        CTOTAL(CI) = 0
        CNAMES(CI) = ' '
        CRATE(CI) = 0.0
    5 CONTINUE

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

      ISPASS = 0
      LENGTH = 0
      OPEN(UNIT=11, FILE=ARG2, STATUS='OLD', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        READ(11, '(A)', IOSTAT=IOS) LINE
        IF (IOS .EQ. 0) THEN
          LENGTH = LEN_TRIM(LINE)
          IF (LENGTH .GT. 0) ISPASS = 1
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
     &      LATENCY, LENGTH, ISPASS, TRIM(TIMESTAMP), TRIM(CAT)
      CLOSE(12)

      PRINT '(A,I0,A,I0,A,I0,A,A)',
     &      'SCORE latency=', LATENCY,
     &      ' length=', LENGTH,
     &      ' pass=', ISPASS,
     &      ' cat=', TRIM(CAT)

      N = 0
      MEAN_LAT = 0.0
      MEAN_LEN = 0.0
      PASS_RATE = 0.0
      MINLAT = 999999.0
      MAXLAT = 0.0
      MINLEN = 999999.0
      MAXLEN = 0.0

      OPEN(UNIT=13, FILE='reports/stats.dat', STATUS='OLD',
     &     IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
   10   N = N + 1
        IF (N .GT. MAXRUNS) GO TO 20
        READ(13, *, END=20, IOSTAT=IOS) LATS(N), LENS(N), IPASS(N)
        IF (IOS .NE. 0) THEN
          N = N - 1
          GO TO 20
        END IF
        MEAN_LAT = MEAN_LAT + REAL(LATS(N))
        MEAN_LEN = MEAN_LEN + REAL(LENS(N))
        PASS_RATE = PASS_RATE + REAL(IPASS(N))
        IF (REAL(LATS(N)) .LT. MINLAT) MINLAT = REAL(LATS(N))
        IF (REAL(LATS(N)) .GT. MAXLAT) MAXLAT = REAL(LATS(N))
        IF (REAL(LENS(N)) .LT. MINLEN) MINLEN = REAL(LENS(N))
        IF (REAL(LENS(N)) .GT. MAXLEN) MAXLEN = REAL(LENS(N))
        CI = LATCAT(LATS(N))
        CTOTAL(CI) = CTOTAL(CI) + 1
        IF (IPASS(N) .EQ. 1) CPASS(CI) = CPASS(CI) + 1
        GO TO 10
   20   CONTINUE
        CLOSE(13)
        IF (N .GT. 0) THEN
          MEAN_LAT = MEAN_LAT / REAL(N)
          MEAN_LEN = MEAN_LEN / REAL(N)
          PASS_RATE = 100.0 * PASS_RATE / REAL(N)
        END IF
      END IF

      P50 = 0.0
      P95 = 0.0
      P99 = 0.0
      MEDLEN = 0.0
      QUAL = 0.0
      IF (N .GT. 0) THEN
        CALL SORTI(LATS, N)
        CALL SORTI(LENS, N)
        P50 = PCNT(LATS, N, 50)
        P95 = PCNT(LATS, N, 95)
        P99 = PCNT(LATS, N, 99)
        MEDLEN = PCNTR(LENS, N, 50)
        QUAL = PASS_RATE
        IF (MEAN_LEN .GT. 0.0) THEN
          QUAL = PASS_RATE * 0.7 +
     &           MIN(100.0, MEAN_LEN / 50.0) * 0.3
        END IF
      END IF

      OPEN(UNIT=14, FILE='reports/summary.txt', STATUS='REPLACE',
     &     IOSTAT=IOS)
      IF (IOS .NE. 0) THEN
        PRINT *, 'ERROR: cannot write reports/summary.txt'
        CALL EXIT(1)
      END IF
      WRITE(14, '(A,I0)') 'RUNS ', N
      WRITE(14, '(A,F12.2)') 'MEAN_LATENCY_MS ', MEAN_LAT
      WRITE(14, '(A,F12.2)') 'P50_LATENCY_MS ', P50
      WRITE(14, '(A,F12.2)') 'P95_LATENCY_MS ', P95
      WRITE(14, '(A,F12.2)') 'P99_LATENCY_MS ', P99
      WRITE(14, '(A,F12.2)') 'MIN_LATENCY_MS ', MINLAT
      WRITE(14, '(A,F12.2)') 'MAX_LATENCY_MS ', MAXLAT
      WRITE(14, '(A,F12.2)') 'MEAN_LENGTH ', MEAN_LEN
      WRITE(14, '(A,F12.2)') 'MEDIAN_LENGTH ', MEDLEN
      WRITE(14, '(A,F12.2)') 'MIN_LENGTH ', MINLEN
      WRITE(14, '(A,F12.2)') 'MAX_LENGTH ', MAXLEN
      WRITE(14, '(A,F8.2)') 'PASS_RATE_PCT ', PASS_RATE
      WRITE(14, '(A,F8.2)') 'QUALITY_SCORE ', QUAL
      CLOSE(14)

      OPEN(UNIT=15, FILE='reports/category_stats.txt',
     &     STATUS='REPLACE', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        WRITE(15, '(A)') 'CATEGORY PASS_RATE_PCT TOTAL'
        DO 35 CI = 1, 10
          IF (CTOTAL(CI) .GT. 0 .AND.
     &        CNAMES(CI) .NE. ' ') THEN
            CRATE(CI) = 100.0 * REAL(CPASS(CI)) /
     &                  REAL(CTOTAL(CI))
            WRITE(15, '(A,F8.2,I6)')
     &        TRIM(CNAMES(CI)), CRATE(CI), CTOTAL(CI)
          END IF
   35   CONTINUE
        CLOSE(15)
      END IF

      OPEN(UNIT=16, FILE='reports/trend.dat',
     &     STATUS='UNKNOWN', POSITION='APPEND', IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
        WRITE(16, '(A,1X,F8.2,1X,F8.2,1X,F8.2,1X,F8.2)')
     &    TRIM(TIMESTAMP), MEAN_LAT, PASS_RATE, MEAN_LEN, QUAL
        CLOSE(16)
      END IF

      END

      INTEGER FUNCTION LATCAT(L)
      INTEGER L
      IF (L .LT. 1000) THEN
        LATCAT = 1
      ELSE IF (L .LT. 5000) THEN
        LATCAT = 2
      ELSE IF (L .LT. 15000) THEN
        LATCAT = 3
      ELSE IF (L .LT. 30000) THEN
        LATCAT = 4
      ELSE
        LATCAT = 5
      END IF
      RETURN
      END

      SUBROUTINE SORTI(ARR, N)
      INTEGER ARR(*), N, I, J, TMP
      DO 100 I = 1, N-1
        DO 101 J = I+1, N
          IF (ARR(I) .GT. ARR(J)) THEN
            TMP = ARR(I)
            ARR(I) = ARR(J)
            ARR(J) = TMP
          END IF
  101   CONTINUE
  100 CONTINUE
      END

      REAL FUNCTION PCNT(ARR, N, P)
      INTEGER ARR(*), N, P, IDX
      IDX = (P * N + 99) / 100
      IF (IDX .LT. 1) IDX = 1
      IF (IDX .GT. N) IDX = N
      PCNT = REAL(ARR(IDX))
      RETURN
      END

      REAL FUNCTION PCNTR(ARR, N, P)
      INTEGER ARR(*)
      INTEGER N, P, IDX
      IDX = (P * N + 99) / 100
      IF (IDX .LT. 1) IDX = 1
      IF (IDX .GT. N) IDX = N
      PCNTR = REAL(ARR(IDX))
      RETURN
      END

      SUBROUTINE GET_TIMESTAMP(TS)
      CHARACTER*8 TS
      INTEGER VALS(8)
      CALL DATE_AND_TIME(VALUES=VALS)
      WRITE(TS, '(I4.4,2I2.2)') VALS(1), VALS(2), VALS(3)
      END
