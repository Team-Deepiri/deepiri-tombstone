/* util.b — string + number helpers for deepiri-tombstone B core */

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

str_startswith(s, prefix) {
    auto i, c, p;
    i = 0;
    while (1) {
        p = char(prefix, i);
        if (p == 0)
            return(1);
        c = char(s, i);
        if (c != p)
            return(0);
        i = i + 1;
    }
}

tolower_ch(c) {
    if (c >= 65 & c <= 90)
        return(c + 32);
    return(c);
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

print_num(n) {
    auto b;
    b = num_buf();
    itoa_buf(n, b, 64);
    printf("%s", b);
}
