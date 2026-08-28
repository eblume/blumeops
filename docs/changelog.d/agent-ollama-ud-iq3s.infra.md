Ollama: added the 12GB Qwen3.8-27B UD-IQ3_S quant (fully GPU-resident at
128K context with q4_0 KV cache) as a declaratively pulled model, case-
insensitive model matching in the sync sidecar for mixed-case hf.co refs,
and `mise run ollama-up` / `mise run ollama-down` to scale the service on
demand for evaluation windows. Part of eblume/talos#64.
