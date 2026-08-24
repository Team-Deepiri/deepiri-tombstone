/* cli.b — classic B commands: ping, ask, eval, warm, summary, models */

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
            c = tolower_ch(c);
            k = tolower_ch(k);
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

/* Cheap lexical novelty: higher = less echo of the prompt */
check_relevance(response, prompt) {
    auto rl, pl, overlap, i, j;
    rl = str_len_b(response);
    pl = str_len_b(prompt);
    overlap = 0;
    if (rl == 0 | pl == 0)
        return(100);
    i = 0;
    while (i < rl & i < 120) {
        j = 0;
        while (j < pl & j < 120) {
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

fail_fast_limit() {
    auto b, n, i, c;
    b = num_buf();
    getenv_str("DEEPIRI_TOMBSTONE_FAIL_FAST", b, 64);
    if (str_len_b(b) == 0)
        return(0);
    n = 0;
    i = 0;
    while (1) {
        c = char(b, i);
        if (c < 48 | c > 57)
            goto done_ff;
        n = n * 10 + (c - 48);
        i = i + 1;
    }
done_ff:
    return(n);
}

cmd_ping() {
    auto buf;
    buf = resp_buf();
    if (ollama_ping() == 0) {
        printf("Ollama not reachable*n");
        return(1);
    }
    printf("Ollama OK (keep-alive bridge)*n");
    if (ollama_models(buf, 4096) > 0)
        printf("Available models: %s*n", buf);
    return(0);
}

cmd_models() {
    auto buf;
    buf = resp_buf();
    if (ollama_models(buf, 4096) == 0) {
        printf("Ollama not reachable*n");
        return(1);
    }
    printf("%s*n", buf);
    return(0);
}

cmd_warm(model) {
    auto t0, t1;
    printf("Warming model %s ...*n", model);
    t0 = time_ms();
    if (ollama_warm(model) == 0) {
        printf("warm failed*n");
        return(1);
    }
    t1 = time_ms();
    printf("warm ok in ");
    print_num(t1 - t0);
    printf("ms*n");
    return(0);
}

cmd_summary() {
    printf("classic eval summary*n");
    printf("  runs=");
    print_num(stats_total());
    printf(" pass=");
    print_num(stats_pass());
    printf(" fail=");
    print_num(stats_fail());
    printf(" pass_rate=");
    print_num(stats_pass_rate());
    printf("%% mean_latency_ms=");
    print_num(stats_mean_latency());
    printf(" cache_hits=");
    print_num(stats_cache_hits());
    printf("*n");
    write_summary();
    printf("wrote reports/summary.txt*n");
    return(0);
}

cmd_ask(model, prompt) {
    auto latency, t0, t1, resp, parsed, auditline, runid, status, cat;
    auto relevance, n;

    resp = resp_buf();
    parsed = parsed_buf();
    auditline = audit_buf();
    runid = runid_buf();
    status = status_buf();

    cat = fixture_category(prompt);
    run_tokenize(prompt);

    t0 = time_ms();
    if (ollama_retry_generate(model, prompt, resp, 65536) == 0) {
        printf("generate failed after retries*n");
        return(1);
    }
    t1 = time_ms();
    latency = t1 - t0;

    n = parse_response_json(resp, parsed, 32768);
    if (n == 0) {
        /* fallback AWK parse */
        write_file("/tmp/dt_raw.json", resp);
        system_cmd("bin/parse < /tmp/dt_raw.json > /tmp/dt_parsed.txt");
        read_file("/tmp/dt_parsed.txt", parsed, 32768);
    }
    printf("%s*n", parsed);

    relevance = check_relevance(parsed, prompt);
    run_score_args(latency, "/tmp/dt_parsed.txt", cat);
    write_file("/tmp/dt_parsed.txt", parsed);

    make_run_id(runid);
    str_copy_b(status, "PASS", 16);
    format_audit(auditline, 4096, runid, model, prompt, parsed, latency, status);
    ledger_queue(auditline);
    ledger_flush();
    append_stats_line(latency, str_len_b(parsed), 1);
    stats_record(1, latency, str_len_b(parsed), 0);

    printf("ask ok latency=");
    print_num(latency);
    printf("ms relevance=");
    print_num(relevance);
    printf("%% cat=%s*n", cat);
    return(0);
}

cmd_eval(model, fixture_path) {
    auto latency, t0, t1, pass, cache_hit;
    auto resp, parsed, pr, kw, auditline, runid, status, cat;
    auto relevance, total, idx, ff, n, words;

    resp = resp_buf();
    parsed = parsed_buf();
    pr = prompt_buf();
    kw = keyword_buf();
    auditline = audit_buf();
    runid = runid_buf();
    status = status_buf();

    system_cmd("mkdir -p reports");
    stats_reset();
    total = fixture_count(fixture_path);
    idx = 0;
    ff = fail_fast_limit();

    if (fixture_open(fixture_path) == 0) {
        printf("cannot open fixtures: %s*n", fixture_path);
        return(1);
    }

    printf("classic eval model=%s fixture=%s cases=", model, fixture_path);
    print_num(total);
    printf(" (keep-alive+cache+batch ledger)*n");

    /* Warm once so first prompt is not cold-load dominated */
    ollama_warm(model);

    while (fixture_next(pr, 2048, kw, 256)) {
        idx = idx + 1;
        printf("[");
        print_num(idx);
        printf("/");
        print_num(total);
        printf("] EVAL %s*n", pr);

        words = run_tokenize(pr);
        cat = fixture_category(pr);
        cache_hit = 0;

        t0 = time_ms();
        if (ollama_retry_generate(model, pr, resp, 65536) == 0) {
            printf("  FAIL generate after retries*n");
            str_copy_b(status, "FAIL", 16);
            str_copy_b(parsed, "", 16);
            latency = 0;
            pass = 0;
            goto record;
        }
        t1 = time_ms();
        latency = t1 - t0;
        cache_hit = last_cache_hit();

        n = parse_response_json(resp, parsed, 32768);
        if (n == 0) {
            write_file("/tmp/dt_raw.json", resp);
            system_cmd("bin/parse < /tmp/dt_raw.json > /tmp/dt_parsed.txt");
            read_file("/tmp/dt_parsed.txt", parsed, 32768);
        }

        pass = 1;
        if (str_len_b(parsed) == 0)
            pass = 0;
        if (pass & check_keyword(parsed, kw) == 0)
            pass = 0;
        if (pass == 0)
            str_copy_b(status, "FAIL", 16);
        else
            str_copy_b(status, "PASS", 16);

        relevance = check_relevance(parsed, pr);
        write_file("/tmp/dt_parsed.txt", parsed);
        run_score_args(latency, "/tmp/dt_parsed.txt", cat);

record:
        make_run_id(runid);
        format_audit(auditline, 4096, runid, model, pr, parsed, latency, status);
        ledger_queue(auditline);
        append_stats_line(latency, str_len_b(parsed), pass);
        stats_record(pass, latency, str_len_b(parsed), cache_hit);

        printf("  -> [%s] lat=", status);
        print_num(latency);
        printf("ms cat=%s rel=", cat);
        print_num(relevance);
        printf("%% words=");
        print_num(words);
        if (cache_hit)
            printf(" CACHE");
        printf("*n");

        if (ff > 0 & stats_fail() >= ff) {
            printf("fail-fast: failures reached ");
            print_num(ff);
            printf("*n");
            goto done_eval;
        }
    }

done_eval:
    fixture_close();
    ledger_flush();
    write_summary();
    printf("eval complete runs=");
    print_num(stats_total());
    printf(" pass_rate=");
    print_num(stats_pass_rate());
    printf("%% mean_ms=");
    print_num(stats_mean_latency());
    printf(" cache_hits=");
    print_num(stats_cache_hits());
    printf("*n");
    printf("see reports/summary.txt reports/audit.ledger reports/stats.dat*n");
    if (stats_pass_rate() < 50)
        return(1);
    return(0);
}
