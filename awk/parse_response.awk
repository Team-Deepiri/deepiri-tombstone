#!/usr/bin/awk -f
# Parse Ollama /api/generate JSON — extract .response field
BEGIN { RS=""; ORS="" }

{
    # Handle streaming chunks: find "response":"..." in any chunk position
    idx = index($0, "\"response\"")
    if (idx == 0) {
        exit 1
    }
    start = idx + 10  # len of "response":
    # skip whitespace and colon
    while (substr($0, start, 1) ~ /[[:space:]:]/) start++
    if (substr($0, start, 1) != "\"") exit 2
    start++  # skip opening quote
    out = ""
    i = start
    while (i <= length($0)) {
        c = substr($0, i, 1)
        if (c == "\\") {
            if (i + 1 <= length($0)) {
                esc = substr($0, i + 1, 1)
                if (esc == "n") out = out "\n"
                else if (esc == "t") out = out "\t"
                else if (esc == "r") out = out "\r"
                else if (esc == "\"") out = out "\""
                else if (esc == "\\") out = out "\\"
                else if (esc == "/") out = out "/"
                else out = out esc
                i += 2
                continue
            }
        } else if (c == "\"") {
            print out
            exit 0
        } else {
            out = out c
        }
        i++
    }
    exit 3
}
