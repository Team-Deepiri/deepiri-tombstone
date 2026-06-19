/* main.b — deepiri-tombstone entry point */

main() {
    auto model, prompt, fixture, cmd, arg1, arg2;

    cmd = 512;
    arg1 = 1024;
    arg2 = 2048;
    model = 4096;
    prompt = 6144;
    fixture = 8192;

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

    printf("deepiri-tombstone — Deepiri post-training eval*n");
    printf("usage:*n");
    printf("  deepiri-tombstone ping*n");
    printf("  deepiri-tombstone ask <model> <prompt>*n");
    printf("  deepiri-tombstone eval [model] [fixture]*n");
    return(1);
}
