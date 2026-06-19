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

cmd_ping() {
    if (ollama_ping() == 0) {
        printf("Ollama not reachable*n");
        return(1);
    }
    printf("Ollama OK*n");
    return(0);
}

cmd_ask(model, prompt) {
    auto latency, t0, t1, resp, parsed, auditline, runid, status;

    resp = resp_buf();
    parsed = parsed_buf();
    auditline = audit_buf();
    runid = runid_buf();
    status = status_buf();

    t0 = time_ms();
    if (ollama_generate(model, prompt, resp, 8192) == 0) {
        printf("generate failed*n");
        return(1);
    }
    t1 = time_ms();
    latency = t1 - t0;

    write_file("/tmp/dt_raw.json", resp);
    system_cmd("bin/parse < /tmp/dt_raw.json > /tmp/dt_parsed.txt");
    read_file("/tmp/dt_parsed.txt", parsed, 4096);
    printf("%s*n", parsed);
    run_score(latency, "/tmp/dt_parsed.txt");

    make_run_id(runid);
    str_copy_b(status, "PASS", 16);
    format_audit(auditline, 512, runid, model, prompt, parsed, latency, status);
    write_file("/tmp/dt_audit_in.txt", auditline);
    system_cmd("cat /tmp/dt_audit_in.txt | bin/audit");
    return(0);
}

cmd_eval(model, fixture_path) {
    auto latency, t0, t1, pass;
    auto resp, parsed, pr, kw, auditline, runid, status;

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
        t0 = time_ms();
        if (ollama_generate(model, pr, resp, 8192) == 0) {
            printf("  FAIL generate*n");
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

        run_score(latency, "/tmp/dt_parsed.txt");
        make_run_id(runid);
        format_audit(auditline, 512, runid, model, pr, parsed, latency, status);
        write_file("/tmp/dt_audit_in.txt", auditline);
        system_cmd("cat /tmp/dt_audit_in.txt | bin/audit");
        printf("  -> %s [%s]*n", parsed, status);
next_case:
        pass = 0;
    }
    fixture_close();
    printf("eval complete — see reports/summary.txt and reports/audit.ledger*n");
    return(0);
}
