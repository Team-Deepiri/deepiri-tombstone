GET "libhdr"

LET json_escape(s) BE
$(  LET i = 0
    LET ch = ?
    WHILE i < s%0 DO
    $(  i := i + 1
        ch := s%i
        SWITCHON ch INTO
        $(  CASE '"':  wrch('\\'); wrch('"');  ENDCASE
            CASE '\\': wrch('\\'); wrch('\\'); ENDCASE
            CASE '*n': wrch('\\'); wrch('n');  ENDCASE
            CASE '*r': wrch('\\'); wrch('r');  ENDCASE
            CASE '*t': wrch('\\'); wrch('t');  ENDCASE
            DEFAULT:   wrch(ch)
        $)
    $)
$)

LET start() BE
$(  LET model = "llama3.2"
    LET prompt = ""
    LET argv = cli()
    LET i = 1

    UNLESS argv=0 DO
    $(  IF i < argv!0 DO model := argv!i
        i := i + 1
        IF i < argv!0 DO prompt := argv!i
    $)

    writes("{\"model\":\"")
    json_escape(model)
    writes("\",\"prompt\":\"")
    json_escape(prompt)
    writes("\",\"stream\":false}*n")
$)
