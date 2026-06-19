C     deepiri-tombstone fortran/score.f
C     Usage: score <latency_ms> <response_file>
      PROGRAM SCORE
      IMPLICIT NONE
      CHARACTER*512 ARG1, ARG2, LINE
      INTEGER LATENCY, LENGTH, PASS, UNIT, IOS
      REAL MEAN_LAT, MEAN_LEN, PASS_RATE
      INTEGER N

      CALL GETARG(1, ARG1)
      CALL GETARG(2, ARG2)
      READ(ARG1, *) LATENCY

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
      END IF

      OPEN(UNIT=12, FILE='reports/stats.dat', STATUS='UNKNOWN',
     &     POSITION='APPEND')
      WRITE(12, '(I10,1X,I10,1X,I2)') LATENCY, LENGTH, PASS
      CLOSE(12)

      PRINT '(A,I0,A,I0,A,I0)', 'SCORE latency=', LATENCY,
     &      ' length=', LENGTH, ' pass=', PASS

      N = 0
      MEAN_LAT = 0.0
      MEAN_LEN = 0.0
      PASS_RATE = 0.0
      OPEN(UNIT=13, FILE='reports/stats.dat', STATUS='OLD',
     &     IOSTAT=IOS)
      IF (IOS .EQ. 0) THEN
 10     READ(13, *, END=20) LATENCY, LENGTH, PASS
        N = N + 1
        MEAN_LAT = MEAN_LAT + REAL(LATENCY)
        MEAN_LEN = MEAN_LEN + REAL(LENGTH)
        PASS_RATE = PASS_RATE + REAL(PASS)
        GO TO 10
 20     CLOSE(13)
        IF (N .GT. 0) THEN
          MEAN_LAT = MEAN_LAT / REAL(N)
          MEAN_LEN = MEAN_LEN / REAL(N)
          PASS_RATE = 100.0 * PASS_RATE / REAL(N)
        END IF
      END IF

      OPEN(UNIT=14, FILE='reports/summary.txt', STATUS='REPLACE')
      WRITE(14, '(A,I0)') 'RUNS ', N
      WRITE(14, '(A,F12.2)') 'MEAN_LATENCY_MS ', MEAN_LAT
      WRITE(14, '(A,F12.2)') 'MEAN_LENGTH ', MEAN_LEN
      WRITE(14, '(A,F8.2)') 'PASS_RATE_PCT ', PASS_RATE
      CLOSE(14)
      END
