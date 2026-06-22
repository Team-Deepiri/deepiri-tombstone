/* main.b — deepiri-tombstone entry point */

main() {
    auto cmd, arg1, arg2, model, fixture;

    cmd = cmd_buf();
    arg1 = arg1_buf();
    arg2 = arg2_buf();
    model = model_buf();
    fixture = fixture_buf();

    get_cmd(cmd, 64);
    get_arg1(arg1, 256);
    get_arg2(arg2, 512);
    default_model(model);
    str_copy_b(fixture, "fixtures/eval_prompts.txt", 256);

    if (str_eq(cmd, "ping"))
        return(cmd_ping());

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

    if (str_eq(cmd, "models")) {
        return(cmd_models());
    }

    if (str_eq(cmd, "compare")) {
        return(cmd_compare());
    }

    if (str_eq(cmd, "trend")) {
        return(cmd_trend());
    }

    printf("deepiri-tombstone — Deepiri post-training eval*n");
    printf("usage:*n");
    printf("  deepiri-tombstone ping              check Ollama connectivity*n");
    printf("  deepiri-tombstone ask <m> <p>       single prompt eval*n");
    printf("  deepiri-tombstone eval [m] [f]      batch eval from fixture*n");
    printf("  deepiri-tombstone models            list available models*n");
    printf("  deepiri-tombstone compare           compare last two eval runs*n");
    printf("  deepiri-tombstone trend             show eval trend summary*n");
    return(1);
}
