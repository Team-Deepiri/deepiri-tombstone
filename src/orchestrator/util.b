/* util.b — string helpers for deepiri-tombstone */

str_eq(a, b) {
    auto i, ca, cb;
    i = 0;
    while (1) {
        ca = char(a, i);
        cb = char(b, i);
        if (ca == 0 & cb == 0)
            return(1);
        if (ca != cb)
            return(0);
        i = i + 1;
    }
}

str_len_b(s) {
    auto i;
    i = 0;
    while (char(s, i) != 0)
        i = i + 1;
    return(i);
}

str_copy_b(dst, src, max) {
    auto i, c;
    i = 0;
    while (i < max - 1) {
        c = char(src, i);
        lchar(dst, i, c);
        if (c == 0)
            return(dst);
        i = i + 1;
    }
    lchar(dst, max - 1, 0);
    return(dst);
}

default_model(buf) {
    getenv_str("DEEPIRI_TOMBSTONE_MODEL", buf, 256);
    if (str_len_b(buf) == 0)
        str_copy_b(buf, "llama3.2", 256);
    return(buf);
}

make_run_id(buf) {
    return(format_run_id(buf, 64));
}
