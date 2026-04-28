# Model Catalog

All models available through the NinjaTech LiteLLM gateway.

**Gateway URL**: `https://model-gateway.public.beta.myninja.ai`  
**Auth**: Bearer token from `/root/.claude/settings.json`

---

## Chat / Text Models

These models accept chat completion requests via `/v1/chat/completions`.

| Alias | Full Model ID | Provider | Best For | Verified |
|-------|---------------|----------|----------|----------|
| `claude-opus` | `claude-opus-4-6` | Anthropic | Complex reasoning, long documents | ✅ |
| `claude-sonnet` | `claude-sonnet-4-5-20250929` | Anthropic | Balanced quality/speed | ✅ |
| `claude-haiku` | `claude-haiku-4-5-20251001` | Anthropic | Fast responses, simple tasks | ✅ |
| `gpt-5` | `openai/openai/gpt-5.2` | OpenAI | General purpose, coding | ✅ |
| `gemini-pro` | `google/gemini/gemini-3-pro-preview` | Google | Multimodal, long context | ✅ |
| `ninja-fast` | `ninja-cline-fast` | NinjaTech | Quick agent tasks | ✅ |
| `ninja-standard` | `ninja-cline-standard` | NinjaTech | Standard agent tasks | ✅ |
| `ninja-complex` | `ninja-cline-complex` | NinjaTech | Complex agent tasks | ✅ |

### Choosing a Chat Model

- **Need highest quality?** → `claude-opus` or `gpt-5`
- **Need speed?** → `claude-haiku` or `ninja-fast`
- **Balanced?** → `claude-sonnet` (recommended default)
- **Agent tasks?** → `ninja-complex` (optimized for Cline/agent workflows)

---

## Image Generation Models

These models accept image generation requests via `/v1/images/generations`.

| Alias | Full Model ID | Provider | Verified |
|-------|---------------|----------|----------|
| `gpt-image` | `openai/openai/gpt-image-1.5` | OpenAI | ✅ (intermittent) |
| `gemini-image` | `google/gemini/gemini-3-pro-image-preview` | Google | ✅ |

### Image Sizes

All image models support these sizes:
- `1024x1024` — Square
- `1024x1536` — Portrait
- `1536x1024` — Landscape

### Notes

- The gateway returns a **URL** to the generated image (not base64)
- `gpt-image` may experience intermittent connection errors — retry or use `gemini-image` as fallback
- `gemini-image` is currently the most reliable option

---

## Video Generation Models

These models use the async video workflow via `/v1/videos`.

| Alias | Full Model ID | Provider | Quality | Speed | Verified |
|-------|---------------|----------|---------|-------|----------|
| `sora` | `openai/openai/sora-2` | OpenAI | Standard | ~90s | ✅ |
| `sora-pro` | `openai/openai/sora-2-pro` | OpenAI | High | ~120s | ✅ |

### Video Sizes

- `1280x720` — Landscape (16:9)
- `720x1280` — Portrait (9:16)

### Video Parameters

- **Max duration**: 8 seconds
- **Generation time**: 60-120 seconds typically
- **Output format**: MP4

### Video Workflow

Video generation is **asynchronous** (3-step process):
1. `POST /v1/videos` → Submit job, get `video_id`
2. `GET /v1/videos/{video_id}` → Poll status (queued → in_progress → completed)
3. `GET /v1/videos/{video_id}/content` → Download MP4

**Important**: Status and content endpoints require the header `custom-llm-provider: openai`.

---

## Embedding Models

These models accept embedding requests via `/v1/embeddings`.

| Alias | Full Model ID | Provider | Dimensions | Verified |
|-------|---------------|----------|------------|----------|
| `embed-small` | `openai/openai/text-embedding-3-small` | OpenAI | 1,536 | ✅ |
| `embed-large` | `openai/openai/text-embedding-3-large` | OpenAI | 3,072 | ✅ |

### Choosing an Embedding Model

- **`embed-small`** — Good for most use cases, lower cost, 1536 dimensions
- **`embed-large`** — Higher accuracy, better for semantic search, 3072 dimensions

### Use Cases

- Semantic search and retrieval
- Document similarity comparison
- Clustering and classification
- RAG (Retrieval-Augmented Generation)

---

## Model Aliases

The utility library supports short aliases. Use `resolve_model()` to convert:

```python
from utils.litellm_client import resolve_model

resolve_model("claude-sonnet")  # → "claude-sonnet-4-5-20250929"
resolve_model("gpt-5")          # → "openai/openai/gpt-5.2"
resolve_model("sora")           # → "openai/openai/sora-2"
resolve_model("embed-small")    # → "openai/openai/text-embedding-3-small"

# Full IDs are passed through unchanged
resolve_model("claude-opus-4-6")  # → "claude-opus-4-6"
```

---

## Rate Limits & Best Practices

1. **Retry on transient errors** — Gateway may return 500 for temporary issues
2. **Use appropriate models** — Don't use `claude-opus` for simple tasks
3. **Batch embeddings** — Use `embed_batch()` instead of multiple `embed()` calls
4. **Video polling** — Use 5-second intervals, don't poll too aggressively
5. **Image fallback** — If `gpt-image` fails, try `gemini-image`