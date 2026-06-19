/*
 * deepiri-tombstone Ollama HTTP bridge for B orchestrator.
 * Uses popen/curl — minimal C glove over syscalls B cannot reach.
 */
#include "ollama_bridge.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static char g_host[256] = "127.0.0.1:11434";
static char g_cmd[64];
static char g_arg1[256];
static char g_arg2[2048];
static FILE *g_fixture = NULL;

void tombstone_set_args(int argc, char **argv) {
    g_cmd[0] = g_arg1[0] = g_arg2[0] = '\0';
    if (argc > 1) snprintf(g_cmd, sizeof(g_cmd), "%s", argv[1]);
    if (argc > 2) snprintf(g_arg1, sizeof(g_arg1), "%s", argv[2]);
    if (argc > 3) snprintf(g_arg2, sizeof(g_arg2), "%s", argv[3]);
}

word_t get_cmd(word_t buf, word_t buflen) {
    if (g_cmd[0] == '\0')
        getenv_str((word_t)"DEEPIRI_TOMBSTONE_CMD", buf, buflen);
    else
        str_copy(buf, (word_t)g_cmd, buflen);
    return buf;
}

word_t get_arg1(word_t buf, word_t buflen) {
    if (g_arg1[0] == '\0')
        getenv_str((word_t)"DEEPIRI_TOMBSTONE_ARG1", buf, buflen);
    else
        str_copy(buf, (word_t)g_arg1, buflen);
    return buf;
}

word_t get_arg2(word_t buf, word_t buflen) {
    if (g_arg2[0] == '\0')
        getenv_str((word_t)"DEEPIRI_TOMBSTONE_ARG2", buf, buflen);
    else
        str_copy(buf, (word_t)g_arg2, buflen);
    return buf;
}

word_t format_run_id(word_t buf, word_t buflen) {
    struct timespec ts;
    clock_gettime(CLOCK_REALTIME, &ts);
    snprintf((char *)buf, (size_t)buflen, "run-%ld%03ld",
             (long)ts.tv_sec, (long)(ts.tv_nsec / 1000000L));
    return buf;
}

static void load_host(void) {
    const char *env = getenv("DEEPIRI_TOMBSTONE_HOST");
    if (env && env[0]) {
        snprintf(g_host, sizeof(g_host), "%s", env);
    }
}

static int shell_escape(const char *in, char *out, size_t outlen) {
    size_t j = 0;
    if (outlen < 3) return -1;
    out[j++] = '\'';
    for (size_t i = 0; in[i]; i++) {
        if (in[i] == '\'') {
            if (j + 4 >= outlen) return -1;
            out[j++] = '\'';
            out[j++] = '\\';
            out[j++] = '\'';
            out[j++] = '\'';
        } else {
            if (j + 1 >= outlen) return -1;
            out[j++] = in[i];
        }
    }
    if (j + 1 >= outlen) return -1;
    out[j++] = '\'';
    out[j] = '\0';
    return 0;
}

static int json_escape(const char *in, char *out, size_t outlen) {
    size_t j = 0;
    for (size_t i = 0; in[i]; i++) {
        const char *rep = NULL;
        char tmp[2];
        if (in[i] == '\\') rep = "\\\\";
        else if (in[i] == '"') rep = "\\\"";
        else if (in[i] == '\n') rep = "\\n";
        else if (in[i] == '\r') rep = "\\r";
        else if (in[i] == '\t') rep = "\\t";
        if (rep) {
            if (j + strlen(rep) >= outlen) return -1;
            memcpy(out + j, rep, strlen(rep));
            j += strlen(rep);
        } else {
            if (j + 1 >= outlen) return -1;
            out[j++] = in[i];
        }
    }
    if (j >= outlen) return -1;
    out[j] = '\0';
    return 0;
}

word_t str_len(word_t s) {
    return (word_t)strlen((const char *)s);
}

word_t str_copy(word_t dst, word_t src, word_t maxlen) {
    strncpy((char *)dst, (const char *)src, (size_t)maxlen - 1);
    ((char *)dst)[(size_t)maxlen - 1] = '\0';
    return dst;
}

word_t getenv_str(word_t name, word_t buf, word_t buflen) {
    const char *val = getenv((const char *)name);
    if (!val) {
        ((char *)buf)[0] = '\0';
        return 0;
    }
    str_copy(buf, (word_t)val, buflen);
    return buf;
}

word_t time_ms(void) {
    struct timespec ts;
    if (clock_gettime(CLOCK_MONOTONIC, &ts) != 0) return 0;
    return (word_t)(ts.tv_sec * 1000L + ts.tv_nsec / 1000000L);
}

word_t read_file(word_t path, word_t buf, word_t buflen) {
    FILE *f = fopen((const char *)path, "r");
    if (!f) return 0;
    size_t n = fread((char *)buf, 1, (size_t)buflen - 1, f);
    ((char *)buf)[n] = '\0';
    fclose(f);
    return (word_t)n;
}

word_t write_file(word_t path, word_t content) {
    FILE *f = fopen((const char *)path, "w");
    if (!f) return 0;
    fputs((const char *)content, f);
    fclose(f);
    return 1;
}

word_t ollama_ping(void) {
    char cmd[512];
    load_host();
    snprintf(cmd, sizeof(cmd),
             "curl -sf http://%s/api/tags >/dev/null 2>&1", g_host);
    return system(cmd) == 0 ? 1 : 0;
}

word_t ollama_generate(word_t model, word_t prompt, word_t buf, word_t buflen) {
    char esc_model[512];
    char esc_prompt[8192];
    char json[16384];
    char cmd[32768];
    char tmpfile[] = "/tmp/deepiri_tombstone_resp_XXXXXX";
    FILE *fp;

    load_host();
    if (json_escape((const char *)model, esc_model, sizeof(esc_model)) != 0) return 0;
    if (json_escape((const char *)prompt, esc_prompt, sizeof(esc_prompt)) != 0) return 0;

    snprintf(json, sizeof(json),
             "{\"model\":\"%s\",\"prompt\":\"%s\",\"stream\":false}",
             esc_model, esc_prompt);

    int fd = mkstemp(tmpfile);
    if (fd < 0) return 0;
    close(fd);

    char shell_json[16384];
    if (shell_escape(json, shell_json, sizeof(shell_json)) != 0) {
        unlink(tmpfile);
        return 0;
    }
    snprintf(cmd, sizeof(cmd),
             "curl -sf http://%s/api/generate -d %s > %s",
             g_host, shell_json, tmpfile);

    if (system(cmd) != 0) {
        unlink(tmpfile);
        return 0;
    }

    fp = fopen(tmpfile, "r");
    if (!fp) {
        unlink(tmpfile);
        return 0;
    }
    size_t n = fread((char *)buf, 1, (size_t)buflen - 1, fp);
    ((char *)buf)[n] = '\0';
    fclose(fp);
    unlink(tmpfile);
    return (word_t)n;
}

word_t ollama_chat(word_t model, word_t user_msg, word_t buf, word_t buflen) {
    char esc_model[512];
    char esc_msg[8192];
    char json[16384];
    char cmd[32768];
    char tmpfile[] = "/tmp/deepiri_tombstone_chat_XXXXXX";
    FILE *fp;

    load_host();
    if (json_escape((const char *)model, esc_model, sizeof(esc_model)) != 0) return 0;
    if (json_escape((const char *)user_msg, esc_msg, sizeof(esc_msg)) != 0) return 0;

    snprintf(json, sizeof(json),
             "{\"model\":\"%s\",\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}],\"stream\":false}",
             esc_model, esc_msg);

    int fd = mkstemp(tmpfile);
    if (fd < 0) return 0;
    close(fd);

    char shell_json[16384];
    if (shell_escape(json, shell_json, sizeof(shell_json)) != 0) {
        unlink(tmpfile);
        return 0;
    }
    snprintf(cmd, sizeof(cmd),
             "curl -sf http://%s/api/chat -d %s > %s",
             g_host, shell_json, tmpfile);

    if (system(cmd) != 0) {
        unlink(tmpfile);
        return 0;
    }

    fp = fopen(tmpfile, "r");
    if (!fp) {
        unlink(tmpfile);
        return 0;
    }
    size_t n = fread((char *)buf, 1, (size_t)buflen - 1, fp);
    ((char *)buf)[n] = '\0';
    fclose(fp);
    unlink(tmpfile);
    return (word_t)n;
}

word_t run_filter(word_t cmd, word_t input, word_t outpath) {
    char pipeline[8192];
    char esc_in[4096];
    char esc_out[1024];

    if (shell_escape((const char *)input, esc_in, sizeof(esc_in)) != 0) return 0;
    if (shell_escape((const char *)outpath, esc_out, sizeof(esc_out)) != 0) return 0;

    snprintf(pipeline, sizeof(pipeline),
             "printf '%%s' %s | %s > %s",
             esc_in, (const char *)cmd, esc_out);
    return system(pipeline) == 0 ? 1 : 0;
}

word_t system_cmd(word_t cmd) {
    return system((const char *)cmd) == 0 ? 1 : 0;
}

static void trim(char *s) {
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == '\n' || s[n - 1] == '\r' || s[n - 1] == ' ')) {
        s[--n] = '\0';
    }
}

word_t fixture_open(word_t path) {
    if (g_fixture) fclose(g_fixture);
    g_fixture = fopen((const char *)path, "r");
    return g_fixture ? 1 : 0;
}

word_t fixture_next(word_t prompt, word_t plen, word_t keyword, word_t klen) {
    char line[2048];
    char *pipe_pos;
    if (!g_fixture) return 0;
    while (fgets(line, sizeof(line), g_fixture)) {
        trim(line);
        if (line[0] == '\0' || line[0] == '#') continue;
        pipe_pos = strchr(line, '|');
        if (pipe_pos) {
            *pipe_pos = '\0';
            str_copy(prompt, (word_t)line, plen);
            str_copy(keyword, (word_t)(pipe_pos + 1), klen);
        } else {
            str_copy(prompt, (word_t)line, plen);
            ((char *)keyword)[0] = '\0';
        }
        trim((char *)prompt);
        trim((char *)keyword);
        return 1;
    }
    return 0;
}

word_t fixture_close(void) {
    if (g_fixture) {
        fclose(g_fixture);
        g_fixture = NULL;
    }
    return 1;
}

word_t format_audit(word_t buf, word_t buflen, word_t runid, word_t model,
                    word_t prompt, word_t response, word_t latency, word_t status) {
    snprintf((char *)buf, (size_t)buflen, "%s|%s|%s|%s|%ld|%s",
             (const char *)runid, (const char *)model, (const char *)prompt,
             (const char *)response, (long)latency, (const char *)status);
    return buf;
}

word_t run_score(word_t latency, word_t response_path) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "bin/score %ld %s", (long)latency, (const char *)response_path);
    return system(cmd) == 0 ? 1 : 0;
}

word_t run_tokenize(word_t prompt) {
    char cmd[4096];
    char esc[2048];
    if (shell_escape((const char *)prompt, esc, sizeof(esc)) != 0) return 0;
    snprintf(cmd, sizeof(cmd), "printf '%%s\\n' %s | bin/tokenize", esc);
    return system(cmd) == 0 ? 1 : 0;
}
