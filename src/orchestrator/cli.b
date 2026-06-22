/* cli.b — commands for deepiri-tombstone */

check_keyword(response, keyword) {
    auto i, c, k, found, ki;
    if (str_len_b(keyword) == 0)
        return(1);
    found = 0;
    i = 0;
    while (char(response, i) != 0) {
        ki = 0;
        found = 1;
        while (char(keyword, ki) != 0) {
            c = char(response, i + ki);
            k = char(keyword, ki);
            if (c >= 65 & c <= 90)
                c = c + 32;
            if (k >= 65 & k <= 90)
                k = k + 32;
            if (c != k) {
                found = 0;
                goto next_i;
            }
            ki = ki + 1;
        }
        if (found)
            return(1);
next_i:
        i = i + 1;
    }
    return(0);
}

check_relevance(response, prompt) {
    auto rl, pl, overlap, i, j;
    rl = str_len_b(response);
    pl = str_len_b(prompt);
    overlap = 0;
    if (rl == 0 | pl == 0)
        return(100);
    i = 0;
    while (i < rl & i < 100) {
        j = 0;
        while (j < pl & j < 100) {
            if (char(response, i) == char(prompt, j)) {
                overlap = overlap + 1;
                goto next_ri;
            }
            j = j + 1;
        }
next_ri:
        i = i + 1;
    }
    return(100 - (overlap * 100 / rl));
}

cmd_ping() {
    auto buf;
    buf = resp_buf();
    if (ollama_ping() == 0) {
        printf("Ollama not reachable*n");
        return(1);
    }
    printf("Ollama OK*n");
    ollama_models(buf, 4096);
    printf("Available models: %s*n", buf);
    return(0);
}

cmd_ask(model, prompt) {
    auto latency, t0, t1, resp, parsed, auditline, runid, status, cat;
    auto relevance;

    resp = resp_buf();
    parsed = parsed_buf();
    auditline = audit_buf();
    runid = runid_buf();
    status = status_buf();

    cat = fixture_category(prompt);

    t0 = time_ms();
    if (ollama_retry_generate(model, prompt, resp, 8192) == 0) {
        printf("generate failed after retries*n");
        return(1);
    }
    t1 = time_ms();
    latency = t1 - t0;

    write_file("/tmp/dt_raw.json", resp);
    system_cmd("bin/parse < /tmp/dt_raw.json > /tmp/dt_parsed.txt");
    read_file("/tmp/dt_parsed.txt", parsed, 4096);
    printf("%s*n", parsed);

    relevance = check_relevance(parsed, prompt);

    run_score_args(latency, "/tmp/dt_parsed.txt", cat);

    make_run_id(runid);
    str_copy_b(status, "PASS", 16);
    format_audit(auditline, 512, runid, model, prompt, parsed, latency, status);
    write_file("/tmp/dt_audit_in.txt", auditline);
    system_cmd("cat /tmp/dt_audit_in.txt | bin/audit");
    return(0);
}

cmd_eval(model, fixture_path) {
    auto latency, t0, t1, pass;
    auto resp, parsed, pr, kw, auditline, runid, status, cat;
    auto relevance;

    resp = resp_buf();
    parsed = parsed_buf();
    pr = prompt_buf();
    kw = keyword_buf();
    auditline = audit_buf();
    runid = runid_buf();
    status = status_buf();

    system_cmd("mkdir -p reports");
    if (fixture_open(fixture_path) == 0) {
        printf("cannot open fixtures*n");
        return(1);
    }

    while (fixture_next(pr, 512, kw, 128)) {
        printf("EVAL %s*n", pr);
        run_tokenize(pr);
        cat = fixture_category(pr);
        t0 = time_ms();
        if (ollama_retry_generate(model, pr, resp, 8192) == 0) {
            printf("  FAIL generate after retries*n");
            goto next_case;
        }
        t1 = time_ms();
        latency = t1 - t0;

        write_file("/tmp/dt_raw.json", resp);
        system_cmd("bin/parse < /tmp/dt_raw.json > /tmp/dt_parsed.txt");
        read_file("/tmp/dt_parsed.txt", parsed, 4096);

        str_copy_b(status, "PASS", 16);
        pass = 1;
        if (str_len_b(parsed) == 0)
            pass = 0;
        if (pass & check_keyword(parsed, kw) == 0)
            pass = 0;
        if (pass == 0)
            str_copy_b(status, "FAIL", 16);

        relevance = check_relevance(parsed, pr);
        run_score_args(latency, "/tmp/dt_parsed.txt", cat);
        make_run_id(runid);
        format_audit(auditline, 512, runid, model, pr, parsed, latency, status);
        write_file("/tmp/dt_audit_in.txt", auditline);
        system_cmd("cat /tmp/dt_audit_in.txt | bin/audit");
        printf("  -> %s [%s] (cat=%s, rel=%d%%)*n", parsed, status, cat, relevance);
next_case:
        pass = 0;
    }
    fixture_close();
    printf("eval complete — see reports/summary.txt, reports/audit.ledger, reports/category_stats.txt*n");
    return(0);
}
