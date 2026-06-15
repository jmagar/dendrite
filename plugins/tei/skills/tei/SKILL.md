---
name: tei
description: "Use when the user wants to call Hugging Face Text Embeddings Inference (TEI) to check health or model info, generate embeddings, create sparse embeddings, rerank candidate texts, tokenize input, or use the OpenAI-compatible embeddings endpoint. Trigger phrases include \"embed this text\", \"convert to a vector\", \"rerank these results\", \"what model is my TEI server running\", \"tokenize this sentence\", and \"check TEI health\"."
---

# TEI

Hugging Face Text Embeddings Inference server: embed text, rerank candidates, and tokenize input through the TEI HTTP API.

## How to call it

Prefer `scripts/tei-api.sh` for common TEI requests. It resolves `TEI_URL` from
the environment or `~/.lab/.env` and exposes `health`, `info`, `embed`,
`embed-batch`, `sparse`, `rerank`, `tokenize`, and `openai-embed`.

Use the TEI base URL from the runtime environment or plugin/lab configuration. If `TEI_URL` is not already exported, read it from the configured lab env file without editing that file:

```bash
TEI_URL=${TEI_URL:-$(grep -E '^TEI_URL=' ~/.lab/.env 2>/dev/null | cut -d= -f2-)}
test -n "$TEI_URL" || echo "TEI_URL is not configured"
```

TEI often runs unauthenticated on trusted networks. If the deployment is behind auth, use the configured header from plugin/server settings; do not put real tokens in examples or committed files.

## Common operations

| Intent | Request |
|---|---|
| Health | `curl -sS "$TEI_URL/health" -w '\nHTTP %{http_code}\n'` |
| Loaded model / runtime info | `curl -sS "$TEI_URL/info"` |
| Embed text | `curl -sS -X POST "$TEI_URL/embed" -H 'Content-Type: application/json' -d '{"inputs":"hello world"}'` |
| Embed (batch) | `curl -sS -X POST "$TEI_URL/embed" -H 'Content-Type: application/json' -d '{"inputs":["a","b"]}'` |
| Sparse embeddings (SPLADE) | `curl -sS -X POST "$TEI_URL/embed_sparse" -H 'Content-Type: application/json' -d '{"inputs":"hello"}'` |
| Rerank against a query | `curl -sS -X POST "$TEI_URL/rerank" -H 'Content-Type: application/json' -d '{"query":"fruit","texts":["apple","car"]}'` |
| Tokenize | `curl -sS -X POST "$TEI_URL/tokenize" -H 'Content-Type: application/json' -d '{"inputs":"hello world"}'` |
| OpenAI-compatible embeddings | `curl -sS -X POST "$TEI_URL/v1/embeddings" -H 'Content-Type: application/json' -d '{"input":"hello","model":"tei"}'` |

`/embed` and `/rerank` depend on the loaded model: an **embedding** model serves `/embed` (and `/rerank` returns a `424 model is not a re-ranker` error), while a **reranker** model serves `/rerank`. Check `/info` to see which is loaded. `/rerank` accepts at most 100 texts per call - split larger batches across requests.

Full API reference: <https://huggingface.github.io/text-embeddings-inference/>

## Configuration

Verify the resolved URL before making model calls:

```bash
curl -sS "$TEI_URL/health" -w '\nHTTP %{http_code}\n'
```

## When NOT to use this skill

- The user wants to *store or search* vectors - that's the `qdrant` skill.
- The phrase is a "teach/team" typo, or the Text Encoding Initiative XML standard - not this skill.
