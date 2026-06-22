#ifndef OLLAMA_BRIDGE_H
#define OLLAMA_BRIDGE_H

typedef long word_t;

word_t ollama_ping(void);
word_t ollama_generate(word_t model, word_t prompt, word_t buf, word_t buflen);
word_t ollama_chat(word_t model, word_t user_msg, word_t buf, word_t buflen);
word_t run_filter(word_t cmd, word_t input, word_t outpath);
word_t time_ms(void);
word_t read_file(word_t path, word_t buf, word_t buflen);
word_t write_file(word_t path, word_t content);
word_t getenv_str(word_t name, word_t buf, word_t buflen);
word_t str_len(word_t s);
word_t str_copy(word_t dst, word_t src, word_t maxlen);
word_t format_run_id(word_t buf, word_t buflen);
word_t get_cmd(word_t buf, word_t buflen);
word_t get_arg1(word_t buf, word_t buflen);
word_t get_arg2(word_t buf, word_t buflen);
void tombstone_set_args(int argc, char **argv);
word_t system_cmd(word_t cmd);
word_t fixture_open(word_t path);
word_t fixture_next(word_t prompt, word_t plen, word_t keyword, word_t klen);
word_t fixture_close(void);
word_t run_score(word_t latency, word_t response_path);
word_t run_score_args(word_t latency, word_t response_path, word_t category);
word_t run_tokenize(word_t prompt);
word_t resp_buf(void);
word_t parsed_buf(void);
word_t prompt_buf(void);
word_t keyword_buf(void);
word_t audit_buf(void);
word_t runid_buf(void);
word_t status_buf(void);
word_t model_buf(void);
word_t fixture_buf(void);
word_t cmd_buf(void);
word_t arg1_buf(void);
word_t arg2_buf(void);
word_t format_audit(word_t buf, word_t buflen, word_t runid, word_t model,
                    word_t prompt, word_t response, word_t latency, word_t status);
word_t set_retry_count(word_t n);
word_t ollama_retry_generate(word_t model, word_t prompt, word_t buf, word_t buflen);
word_t ollama_models(word_t buf, word_t buflen);
word_t fixture_category(word_t prompt);

#endif
