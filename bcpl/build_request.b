GET "libhdr"

LET start() BE
$(  LET model = "llama3.2"
    LET prompt = ""
    LET argv = cli()
    LET i = 1
    LET stdout = output()

    UNLESS argv=0 DO
    $(  IF i < argv!0 DO model := argv!i
        i := i + 1
        IF i < argv!0 DO prompt := argv!i
    $)

    writef("{\"model\":\"%s\",\"prompt\":\"%s\",\"stream\":false}*n",
            model, prompt)
$)
