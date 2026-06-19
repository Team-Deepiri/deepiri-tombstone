#!/usr/bin/awk -f
# parse_response.awk — extract .response from Ollama /api/generate JSON
BEGIN { RS=""; ORS="" }
{
    if (match($0, /"response"[[:space:]]*:[[:space:]]*"/)) {
        start = RSTART + RLENGTH
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
    }
    exit 2
}
