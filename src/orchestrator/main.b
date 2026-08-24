/* main.b — deepiri-tombstone B entry point (classic core) */

main() {
    auto cmd, arg1, arg2, model, fixture;
    auto buf;

    cmd = cmd_buf();
    arg1 = arg1_buf();
    arg2 = arg2_buf();
    model = model_buf();
    fixture = fixture_buf();
    buf = resp_buf();

    get_cmd(cmd, 64);
    get_arg1(arg1, 256);
    get_arg2(arg2, 512);
    default_model(model);
    str_copy_b(fixture, "fixtures/eval_prompts.txt", 256);

    if (str_eq(cmd, "ping"))
        return(cmd_ping());

    if (str_eq(cmd, "models"))
        return(cmd_models());

    if (str_eq(cmd, "warm")) {
        if (str_len_b(arg1) > 0)
            str_copy_b(model, arg1, 256);
        return(cmd_warm(model));
    }

    if (str_eq(cmd, "summary"))
        return(cmd_summary());

    if (str_eq(cmd, "ask")) {
        if (str_len_b(arg2) == 0) {
            printf("usage: deepiri-tombstone ask <model> <prompt>*n");
            return(1);
        }
        return(cmd_ask(arg1, arg2));
    }

    if (str_eq(cmd, "eval")) {
        if (str_len_b(arg1) > 0)
            str_copy_b(model, arg1, 256);
        if (str_len_b(arg2) > 0)
            str_copy_b(fixture, arg2, 256);
        return(cmd_eval(model, fixture));
    }

    if (str_eq(cmd, "compare")) {
        system_cmd("bash scripts/compare.sh reports/audit.ledger reports/audit.ledger text");
        return(0);
    }

    if (str_eq(cmd, "trend")) {
        system_cmd("bash scripts/trend.sh reports/trend.dat reports/summary.txt");
        return(0);
    }

    printf("deepiri-tombstone classic B core*n");
    printf("usage:*n");
    printf("  ping                 check Ollama (keep-alive)*n");
    printf("  models               list Ollama models*n");
    printf("  warm [model]         load model into VRAM*n");
    printf("  ask <m> <p>          single prompt*n");
    printf("  eval [m] [fixture]   batch classic eval*n");
    printf("  summary              print running stats*n");
    printf("  compare | trend      report helpers*n");
    return(1);
}
