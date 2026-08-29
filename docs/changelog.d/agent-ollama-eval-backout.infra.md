Ollama: shelved the 128K-context local-model evaluation after ollama
silently capped the effective context at 4K tokens on the 16GiB card
(eblume/talos#64). Reverted the evaluation config: the Qwen3.8-27B
UD-IQ3_S pull entry and the q4_0 KV cache setting. The service stays
scaled to 0 by default; the `ollama-up` / `ollama-down` tasks, the
case-insensitive model sync fix, and the 0.32.14 version bookkeeping are
kept. The local execution choice is moving to a dedicated host (Mac
Studio M5 Ultra); ringtail is being upgraded for stability, not LLM
serving.
