/*
 * deepiri-tombstone Ollama HTTP bridge for B orchestrator.
 * Keep-alive libcurl, in-process JSON extract, response cache,
 * running eval stats, and batched ledger flush — so classic B
 * eval is limited by the model, not by fork(curl)/AWK/COBOL.
 */
#include "ollama_bridge.h"

#include <curl/curl.h>
#include <openssl/sha.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include <ctype.h>

#if defined(__linux__)
/* symbol aliases live in ollama_bridge_syms.S */
#endif

static char g_host[256] = "127.0.0.1:11434";
static char g_cmd[64];
static char g_arg1[256];
static char g_arg2[2048];
static FILE *g_fixture = NULL;
static char g_resp_buf[65536];
static char g_parsed_buf[32768];
static char g_prompt_buf[2048];
static char g_keyword_buf[256];
static char g_audit_buf[4096];
static char g_runid_buf[64];
static char g_status_buf[16];
static char g_model_buf[256];
static char g_fixture_path[256];
static char g_cmd_buf[64];
static char g_arg1_buf[256];
static char g_arg2_buf[512];
static char g_num_buf[64];

static int g_last_cache_hit = 0;

word_t last_cache_hit(void) {
    return (word_t)g_last_cache_hit;
}

static long g_stat_total = 0;
static long g_stat_pass = 0;
static long g_stat_fail = 0;
static long g_stat_latency_sum = 0;
static long g_stat_cache_hits = 0;
static long g_stat_bytes = 0;

/* Batched ledger */
#define LEDGER_BATCH_MAX 64
static char g_ledger_batch[LEDGER_BATCH_MAX][4096];
static int g_ledger_n = 0;
static char g_ledger_path[512] = "reports/audit.ledger";
static char g_stats_path[512] = "reports/stats.dat";
static char g_summary_path[512] = "reports/summary.txt";

/* libcurl handle (process-lifetime keep-alive) */
static CURL *g_curl = NULL;
static int g_curl_ready = 0;
static struct curl_slist *g_hdrs = NULL;

struct mem_buf {
    char *data;
    size_t len;
    size_t cap;
};

word_t resp_buf(void) { return (word_t)g_resp_buf; }
word_t parsed_buf(void) { return (word_t)g_parsed_buf; }
word_t prompt_buf(void) { return (word_t)g_prompt_buf; }
word_t keyword_buf(void) { return (word_t)g_keyword_buf; }
word_t audit_buf(void) { return (word_t)g_audit_buf; }
word_t runid_buf(void) { return (word_t)g_runid_buf; }
word_t status_buf(void) { return (word_t)g_status_buf; }
word_t model_buf(void) { return (word_t)g_model_buf; }
word_t fixture_buf(void) { return (word_t)g_fixture_path; }
word_t cmd_buf(void) { return (word_t)g_cmd_buf; }
word_t arg1_buf(void) { return (word_t)g_arg1_buf; }
word_t arg2_buf(void) { return (word_t)g_arg2_buf; }
word_t num_buf(void) { return (word_t)g_num_buf; }

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
    if (env && env[0])
        snprintf(g_host, sizeof(g_host), "%s", env);
}

#define MAX_RETRIES 3
#define RETRY_DELAY_MS 500
#define TIMEOUT_SECONDS 120

static int retry_count = 0;

word_t set_retry_count(word_t n) {
    retry_count = (int)n;
    return 1;
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

word_t system_cmd(word_t cmd) {
    return system((const char *)cmd) == 0 ? 1 : 0;
}

word_t itoa_buf(word_t n, word_t buf, word_t buflen) {
    snprintf((char *)buf, (size_t)buflen, "%ld", (long)n);
    return buf;
}

/* ---- curl keep-alive ---- */

static size_t write_cb(char *ptr, size_t size, size_t nmemb, void *userdata) {
    struct mem_buf *m = userdata;
    size_t n = size * nmemb;
    if (m->len + n + 1 > m->cap) {
        size_t ncap = m->cap ? m->cap * 2 : 8192;
        while (ncap < m->len + n + 1) ncap *= 2;
        char *p = realloc(m->data, ncap);
        if (!p) return 0;
        m->data = p;
        m->cap = ncap;
    }
    memcpy(m->data + m->len, ptr, n);
    m->len += n;
    m->data[m->len] = '\0';
    return n;
}

static int ensure_curl(void) {
    if (g_curl_ready && g_curl) return 1;
    curl_global_init(CURL_GLOBAL_DEFAULT);
    g_curl = curl_easy_init();
    if (!g_curl) return 0;
    g_hdrs = curl_slist_append(NULL, "Content-Type: application/json");
    g_hdrs = curl_slist_append(g_hdrs, "Connection: keep-alive");
    curl_easy_setopt(g_curl, CURLOPT_HTTPHEADER, g_hdrs);
    curl_easy_setopt(g_curl, CURLOPT_TCP_KEEPALIVE, 1L);
    curl_easy_setopt(g_curl, CURLOPT_TCP_KEEPIDLE, 30L);
    curl_easy_setopt(g_curl, CURLOPT_TCP_KEEPINTVL, 15L);
    curl_easy_setopt(g_curl, CURLOPT_TIMEOUT, (long)TIMEOUT_SECONDS);
    curl_easy_setopt(g_curl, CURLOPT_CONNECTTIMEOUT, 10L);
    curl_easy_setopt(g_curl, CURLOPT_FOLLOWLOCATION, 0L);
    curl_easy_setopt(g_curl, CURLOPT_NOSIGNAL, 1L);
    curl_easy_setopt(g_curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(g_curl, CURLOPT_USERAGENT, "deepiri-tombstone/2.1");
    g_curl_ready = 1;
    return 1;
}

static int http_request(const char *method, const char *path,
                        const char *body, char *out, size_t outlen) {
    char url[512];
    struct mem_buf mem = {0};
    long http_code = 0;
    CURLcode rc;

    load_host();
    if (!ensure_curl()) return -1;
    snprintf(url, sizeof(url), "http://%s%s", g_host, path);

    mem.data = malloc(8192);
    if (!mem.data) return -1;
    mem.cap = 8192;
    mem.len = 0;
    mem.data[0] = '\0';

    curl_easy_setopt(g_curl, CURLOPT_URL, url);
    curl_easy_setopt(g_curl, CURLOPT_WRITEDATA, &mem);
    curl_easy_setopt(g_curl, CURLOPT_HTTPGET, 0L);
    curl_easy_setopt(g_curl, CURLOPT_POST, 0L);
    curl_easy_setopt(g_curl, CURLOPT_CUSTOMREQUEST, NULL);
    curl_easy_setopt(g_curl, CURLOPT_POSTFIELDS, NULL);

    if (strcmp(method, "GET") == 0) {
        curl_easy_setopt(g_curl, CURLOPT_HTTPGET, 1L);
    } else if (strcmp(method, "POST") == 0) {
        curl_easy_setopt(g_curl, CURLOPT_POST, 1L);
        curl_easy_setopt(g_curl, CURLOPT_POSTFIELDS, body ? body : "");
    } else {
        curl_easy_setopt(g_curl, CURLOPT_CUSTOMREQUEST, method);
        if (body) curl_easy_setopt(g_curl, CURLOPT_POSTFIELDS, body);
    }

    rc = curl_easy_perform(g_curl);
    if (rc != CURLE_OK) {
        free(mem.data);
        return -1;
    }
    curl_easy_getinfo(g_curl, CURLINFO_RESPONSE_CODE, &http_code);
    if (http_code < 200 || http_code >= 300) {
        free(mem.data);
        return (int)-http_code;
    }
    if (mem.len >= outlen) mem.len = outlen - 1;
    memcpy(out, mem.data, mem.len);
    out[mem.len] = '\0';
    free(mem.data);
    return (int)mem.len;
}

/* ---- JSON helpers ---- */

static int json_escape(const char *in, char *out, size_t outlen) {
    size_t j = 0;
    for (size_t i = 0; in[i]; i++) {
        const char *rep = NULL;
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

/* Extract "response":"..." with escapes. Returns length or 0. */
static size_t extract_json_string_field(const char *json, const char *field,
                                        char *out, size_t outlen) {
    char key[128];
    const char *p;
    size_t j = 0;
    snprintf(key, sizeof(key), "\"%s\"", field);
    p = strstr(json, key);
    if (!p) return 0;
    p = strchr(p + strlen(key), ':');
    if (!p) return 0;
    p++;
    while (*p && isspace((unsigned char)*p)) p++;
    if (*p != '"') return 0;
    p++;
    while (*p && j + 1 < outlen) {
        if (*p == '\\' && p[1]) {
            p++;
            if (*p == 'n') out[j++] = '\n';
            else if (*p == 'r') out[j++] = '\r';
            else if (*p == 't') out[j++] = '\t';
            else if (*p == '"' || *p == '\\' || *p == '/') out[j++] = *p;
            else if (*p == 'u' && p[1] && p[2] && p[3] && p[4]) {
                /* skip unicode escapes as '?' */
                out[j++] = '?';
                p += 4;
            } else {
                out[j++] = *p;
            }
            p++;
            continue;
        }
        if (*p == '"') break;
        out[j++] = *p++;
    }
    out[j] = '\0';
    return j;
}

word_t parse_response_json(word_t raw, word_t out, word_t outlen) {
    size_t n = extract_json_string_field((const char *)raw, "response",
                                         (char *)out, (size_t)outlen);
    return (word_t)n;
}

/* ---- response cache (compatible layout with Python client) ---- */

static int cache_enabled(void) {
    const char *e = getenv("DEEPIRI_TOMBSTONE_NO_CACHE");
    if (e && (strcmp(e, "1") == 0 || strcmp(e, "true") == 0)) return 0;
    return 1;
}

static void cache_dir(char *out, size_t outlen) {
    const char *e = getenv("DEEPIRI_TOMBSTONE_CACHE_DIR");
    if (e && e[0]) {
        snprintf(out, outlen, "%s", e);
        return;
    }
    snprintf(out, outlen, "reports/cache");
}

/* SHA-256 key must match src/common/ollama_client.py cache_key():
 *   sha256(f"{endpoint}\\0{model}\\0{prompt}")
 */
static void hash_key(const char *model, const char *prompt, char *hex, size_t hexlen) {
    unsigned char dig[SHA256_DIGEST_LENGTH];
    SHA256_CTX ctx;
    const char *endpoint = "generate";
    const unsigned char nul = 0;
    size_t i;

    SHA256_Init(&ctx);
    SHA256_Update(&ctx, endpoint, strlen(endpoint));
    SHA256_Update(&ctx, &nul, 1);
    SHA256_Update(&ctx, model, strlen(model));
    SHA256_Update(&ctx, &nul, 1);
    SHA256_Update(&ctx, prompt, strlen(prompt));
    SHA256_Final(dig, &ctx);

    if (hexlen < SHA256_DIGEST_LENGTH * 2 + 1) {
        hex[0] = '\0';
        return;
    }
    for (i = 0; i < SHA256_DIGEST_LENGTH; i++)
        sprintf(hex + i * 2, "%02x", dig[i]);
    hex[SHA256_DIGEST_LENGTH * 2] = '\0';
}

static int cache_get(const char *model, const char *prompt, char *out, size_t outlen) {
    char dir[512], hex[80], path[640];
    FILE *f;
    char *file = NULL;
    long flen;
    size_t n;

    if (!cache_enabled()) return 0;
    cache_dir(dir, sizeof(dir));
    hash_key(model, prompt, hex, sizeof(hex));
    snprintf(path, sizeof(path), "%s/%c%c/%s.json", dir, hex[0], hex[1], hex);
    f = fopen(path, "r");
    if (!f) return 0;
    fseek(f, 0, SEEK_END);
    flen = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (flen <= 0 || flen > 8 * 1024 * 1024) {
        fclose(f);
        return 0;
    }
    file = malloc((size_t)flen + 1);
    if (!file) {
        fclose(f);
        return 0;
    }
    n = fread(file, 1, (size_t)flen, f);
    file[n] = '\0';
    fclose(f);
    n = extract_json_string_field(file, "response", out, outlen);
    free(file);
    return n > 0 ? 1 : 0;
}

static void cache_put(const char *model, const char *prompt, const char *response) {
    char dir[512], hex[80], path[640], tmp[660], parent[640];
    char esc_model[512], esc_resp[32768];
    FILE *f;

    if (!cache_enabled() || !response) return;
    cache_dir(dir, sizeof(dir));
    hash_key(model, prompt, hex, sizeof(hex));
    snprintf(parent, sizeof(parent), "%s/%c%c", dir, hex[0], hex[1]);
    snprintf(path, sizeof(path), "%s/%s.json", parent, hex);
    snprintf(tmp, sizeof(tmp), "%s.tmp", path);
    mkdir("reports", 0755);
    mkdir(dir, 0755);
    mkdir(parent, 0755);
    if (json_escape(model, esc_model, sizeof(esc_model)) != 0) return;
    if (json_escape(response, esc_resp, sizeof(esc_resp)) != 0) return;
    f = fopen(tmp, "w");
    if (!f) return;
    fprintf(f, "{\"model\":\"%s\",\"endpoint\":\"generate\",\"response\":\"%s\"}\n",
            esc_model, esc_resp);
    fclose(f);
    rename(tmp, path);
}

/* ---- Ollama API ---- */

word_t ollama_ping(void) {
    char buf[256];
    return http_request("GET", "/api/tags", NULL, buf, sizeof(buf)) > 0 ? 1 : 0;
}

word_t ollama_models(word_t buf, word_t buflen) {
    char raw[65536];
    int n = http_request("GET", "/api/tags", NULL, raw, sizeof(raw));
    if (n <= 0) return 0;
    /* Compact model name list from "name":"..." fields */
    {
        char *out = (char *)buf;
        size_t left = (size_t)buflen;
        const char *p = raw;
        int first = 1;
        out[0] = '\0';
        while ((p = strstr(p, "\"name\"")) != NULL && left > 2) {
            char name[256];
            size_t nl = extract_json_string_field(p, "name", name, sizeof(name));
            if (nl > 0) {
                size_t need = nl + (first ? 0 : 1) + 1;
                if (need >= left) break;
                if (!first) {
                    strcat(out, ",");
                    left--;
                }
                strcat(out, name);
                left -= nl + (first ? 0 : 0);
                first = 0;
            }
            p += 6;
        }
        return (word_t)strlen(out);
    }
}

word_t ollama_generate(word_t model, word_t prompt, word_t buf, word_t buflen) {
    char esc_model[512];
    char esc_prompt[16384];
    char json[24576];
    char raw[65536];
    int n;

    g_last_cache_hit = 0;
    /* Cache stores the *parsed* response text */
    if (cache_get((const char *)model, (const char *)prompt, (char *)buf, (size_t)buflen)) {
        g_stat_cache_hits++;
        g_last_cache_hit = 1;
        /* Wrap as minimal JSON so parse_response_json / callers still work */
        {
            char esc[32768];
            if (json_escape((const char *)buf, esc, sizeof(esc)) == 0) {
                snprintf(raw, sizeof(raw), "{\"response\":\"%s\"}", esc);
                str_copy(buf, (word_t)raw, buflen);
                return str_len(buf);
            }
        }
    }

    if (json_escape((const char *)model, esc_model, sizeof(esc_model)) != 0) return 0;
    if (json_escape((const char *)prompt, esc_prompt, sizeof(esc_prompt)) != 0) return 0;
    snprintf(json, sizeof(json),
             "{\"model\":\"%s\",\"prompt\":\"%s\",\"stream\":false}",
             esc_model, esc_prompt);

    n = http_request("POST", "/api/generate", json, raw, sizeof(raw));
    if (n <= 0) return 0;
    str_copy(buf, (word_t)raw, buflen);

    {
        char parsed[32768];
        if (extract_json_string_field(raw, "response", parsed, sizeof(parsed)) > 0)
            cache_put((const char *)model, (const char *)prompt, parsed);
    }
    return str_len(buf);
}

word_t ollama_chat(word_t model, word_t user_msg, word_t buf, word_t buflen) {
    char esc_model[512];
    char esc_msg[16384];
    char json[24576];
    char raw[65536];
    int n;

    if (json_escape((const char *)model, esc_model, sizeof(esc_model)) != 0) return 0;
    if (json_escape((const char *)user_msg, esc_msg, sizeof(esc_msg)) != 0) return 0;
    snprintf(json, sizeof(json),
             "{\"model\":\"%s\",\"messages\":[{\"role\":\"user\",\"content\":\"%s\"}],\"stream\":false}",
             esc_model, esc_msg);
    n = http_request("POST", "/api/chat", json, raw, sizeof(raw));
    if (n <= 0) return 0;
    str_copy(buf, (word_t)raw, buflen);
    return str_len(buf);
}

word_t ollama_retry_generate(word_t model, word_t prompt, word_t buf, word_t buflen) {
    int attempt;
    word_t result;
    int max = retry_count > 0 ? retry_count : MAX_RETRIES;
    for (attempt = 1; attempt <= max; attempt++) {
        result = ollama_generate(model, prompt, buf, buflen);
        if (result > 0) return result;
        if (attempt < max) {
            struct timespec ts;
            ts.tv_sec = RETRY_DELAY_MS / 1000;
            ts.tv_nsec = (RETRY_DELAY_MS % 1000) * 1000000L;
            nanosleep(&ts, NULL);
        }
    }
    return 0;
}

word_t ollama_warm(word_t model) {
    char esc_model[512];
    char json[1024];
    char raw[4096];
    if (json_escape((const char *)model, esc_model, sizeof(esc_model)) != 0) return 0;
    /* Tiny generate to load weights into VRAM */
    snprintf(json, sizeof(json),
             "{\"model\":\"%s\",\"prompt\":\"hi\",\"stream\":false,\"options\":{\"num_predict\":1}}",
             esc_model);
    return http_request("POST", "/api/generate", json, raw, sizeof(raw)) > 0 ? 1 : 0;
}

/* ---- fixtures / audit / score ---- */

static void trim(char *s) {
    size_t n = strlen(s);
    while (n > 0 && (s[n - 1] == '\n' || s[n - 1] == '\r' || s[n - 1] == ' '))
        s[--n] = '\0';
}

word_t fixture_open(word_t path) {
    if (g_fixture) fclose(g_fixture);
    g_fixture = fopen((const char *)path, "r");
    return g_fixture ? 1 : 0;
}

word_t fixture_next(word_t prompt, word_t plen, word_t keyword, word_t klen) {
    char line[4096];
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

word_t fixture_count(word_t path) {
    FILE *f = fopen((const char *)path, "r");
    char line[4096];
    long n = 0;
    if (!f) return 0;
    while (fgets(line, sizeof(line), f)) {
        trim(line);
        if (line[0] && line[0] != '#') n++;
    }
    fclose(f);
    return (word_t)n;
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
    /* Flatten newlines so ledger stays one row per case */
    char pflat[2048], rflat[2048];
    size_t i, j;
    const char *p = (const char *)prompt;
    const char *r = (const char *)response;
    for (i = j = 0; p[i] && j + 1 < sizeof(pflat); i++)
        pflat[j++] = (p[i] == '\n' || p[i] == '\r') ? ' ' : p[i];
    pflat[j] = '\0';
    for (i = j = 0; r[i] && j + 1 < sizeof(rflat); i++)
        rflat[j++] = (r[i] == '\n' || r[i] == '\r') ? ' ' : r[i];
    rflat[j] = '\0';
    snprintf((char *)buf, (size_t)buflen, "%s|%s|%s|%s|%ld|%s",
             (const char *)runid, (const char *)model, pflat, rflat,
             (long)latency, (const char *)status);
    return buf;
}

word_t run_score(word_t latency, word_t response_path) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "bin/score %ld %s", (long)latency, (const char *)response_path);
    return system(cmd) == 0 ? 1 : 0;
}

word_t run_score_args(word_t latency, word_t response_path, word_t category) {
    char cmd[1536];
    /* Category rollups only — pass/fail stats go through append_stats_line */
    snprintf(cmd, sizeof(cmd), "bin/score %ld %s '%s' >/dev/null 2>&1",
             (long)latency, (const char *)response_path, (const char *)category);
    system(cmd);
    return 1;
}

word_t run_tokenize(word_t prompt) {
    /* Cheap in-process word budget (~Forth stage). Skip process spawn. */
    const char *p = (const char *)prompt;
    long words = 0, in_word = 0;
    for (; *p; p++) {
        if (*p == ' ' || *p == '\t' || *p == '\n') {
            in_word = 0;
        } else if (!in_word) {
            in_word = 1;
            words++;
        }
    }
    if (words > 512) {
        fprintf(stderr, "TOKENIZE warn: %ld words > 512 budget\n", words);
        return 0;
    }
    return words > 0 ? words : 1;
}

word_t run_filter(word_t cmd, word_t input, word_t outpath) {
    char pipeline[8192];
    FILE *f = fopen((const char *)outpath, "w");
    if (!f) return 0;
    /* Prefer in-process parse when cmd looks like bin/parse */
    if (strstr((const char *)cmd, "parse")) {
        char out[32768];
        if (extract_json_string_field((const char *)input, "response", out, sizeof(out)) > 0) {
            fputs(out, f);
            fclose(f);
            return 1;
        }
    }
    fclose(f);
    snprintf(pipeline, sizeof(pipeline), "printf '%%s' '%s' | %s > %s",
             (const char *)input, (const char *)cmd, (const char *)outpath);
    return system(pipeline) == 0 ? 1 : 0;
}

word_t fixture_category(word_t prompt) {
    const char *p = (const char *)prompt;
    if (strstr(p, "code") || strstr(p, "function") || strstr(p, "binary search")
        || strstr(p, "quicksort") || strstr(p, "Python") || strstr(p, "algorithm"))
        return (word_t)"coding";
    if (strstr(p, "capital") || strstr(p, "history") || strstr(p, "what is")
        || strstr(p, "famous") || strstr(p, "language"))
        return (word_t)"knowledge";
    if (strstr(p, "say") || strstr(p, "respond") || strstr(p, "return")
        || strstr(p, "repeat"))
        return (word_t)"instruction";
    if (strstr(p, "if") || strstr(p, "step") || strstr(p, "think")
        || strstr(p, "reason") || strstr(p, "minutes"))
        return (word_t)"reasoning";
    if (strstr(p, "ignore") || strstr(p, "pick") || strstr(p, "how to")
        || strstr(p, "tell me"))
        return (word_t)"safety";
    if (strstr(p, "hello") || strstr(p, "hi") || strstr(p, "haiku"))
        return (word_t)"language";
    return (word_t)"general";
}

/* ---- stats + batched ledger ---- */

word_t stats_reset(void) {
    g_stat_total = g_stat_pass = g_stat_fail = 0;
    g_stat_latency_sum = g_stat_cache_hits = g_stat_bytes = 0;
    g_ledger_n = 0;
    return 1;
}

word_t stats_record(word_t passed, word_t latency_ms, word_t resp_len, word_t cache_hit) {
    g_stat_total++;
    if (passed) g_stat_pass++;
    else g_stat_fail++;
    g_stat_latency_sum += (long)latency_ms;
    g_stat_bytes += (long)resp_len;
    if (cache_hit) g_stat_cache_hits++;
    return g_stat_total;
}

word_t stats_total(void) { return (word_t)g_stat_total; }
word_t stats_pass(void) { return (word_t)g_stat_pass; }
word_t stats_fail(void) { return (word_t)g_stat_fail; }
word_t stats_cache_hits(void) { return (word_t)g_stat_cache_hits; }

word_t stats_mean_latency(void) {
    if (g_stat_total == 0) return 0;
    return (word_t)(g_stat_latency_sum / g_stat_total);
}

word_t stats_pass_rate(void) {
    if (g_stat_total == 0) return 0;
    return (word_t)((g_stat_pass * 100) / g_stat_total);
}

word_t ledger_flush(void);

word_t ledger_queue(word_t line) {
    if (g_ledger_n >= LEDGER_BATCH_MAX)
        ledger_flush();
    snprintf(g_ledger_batch[g_ledger_n], sizeof(g_ledger_batch[0]), "%s", (const char *)line);
    g_ledger_n++;
    return (word_t)g_ledger_n;
}

word_t ledger_flush(void) {
    FILE *f;
    int i;
    if (g_ledger_n == 0) return 0;
    mkdir("reports", 0755);
    f = fopen(g_ledger_path, "a");
    if (!f) return 0;
    for (i = 0; i < g_ledger_n; i++)
        fprintf(f, "%s\n", g_ledger_batch[i]);
    fclose(f);
    g_ledger_n = 0;
    return 1;
}

word_t write_summary(void) {
    FILE *f;
    mkdir("reports", 0755);
    f = fopen(g_summary_path, "w");
    if (!f) return 0;
    fprintf(f, "RUNS %ld\n", g_stat_total);
    fprintf(f, "MEAN_LATENCY_MS %ld\n",
            g_stat_total ? g_stat_latency_sum / g_stat_total : 0);
    fprintf(f, "MEAN_LENGTH %ld\n",
            g_stat_total ? g_stat_bytes / g_stat_total : 0);
    fprintf(f, "PASS_RATE_PCT %ld\n",
            g_stat_total ? (g_stat_pass * 100) / g_stat_total : 0);
    fprintf(f, "PASSES %ld\n", g_stat_pass);
    fprintf(f, "FAILURES %ld\n", g_stat_fail);
    fprintf(f, "CACHE_HITS %ld\n", g_stat_cache_hits);
    fclose(f);
    return 1;
}

word_t append_stats_line(word_t latency, word_t length, word_t passed) {
    FILE *f;
    mkdir("reports", 0755);
    f = fopen(g_stats_path, "a");
    if (!f) return 0;
    fprintf(f, "%ld %ld %ld\n", (long)latency, (long)length, (long)passed);
    fclose(f);
    return 1;
}
