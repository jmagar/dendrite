# TEI

Use Hugging Face Text Embeddings Inference for health checks, embeddings,
sparse embeddings, reranking, tokenization, and OpenAI-compatible embeddings.

## Configuration

Set `tei_url` and optional sensitive `tei_auth_header` in Claude plugin settings
or Gemini extension settings. The SessionStart/ConfigChange hook writes:

```bash
${XDG_CONFIG_HOME:-~/.config}/lab-tei/config.env
```

The generated file is mode `600` and is sourced by the skill helper before the
legacy `~/.lab/.env` fallback.
