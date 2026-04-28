# LiteLLM Gateway Guide

Complete guide for agents to use AI models through the NinjaTech LiteLLM gateway.

---

## Table of Contents

1. [Overview](#overview)
2. [Configuration](#configuration)
3. [Utility Library](#utility-library)
4. [Chat Completions](#chat-completions)
5. [Image Generation](#image-generation)
6. [Video Generation](#video-generation)
7. [Embeddings](#embeddings)
8. [Raw API Access](#raw-api-access)
9. [Error Handling](#error-handling)
10. [Building Custom Utilities](#building-custom-utilities)

---

## Overview

The NinjaTech LiteLLM gateway provides a unified OpenAI-compatible API for accessing models from multiple providers (Anthropic, OpenAI, Google, NinjaTech). All requests go through a single base URL with a single API key.

**Gateway URL**: `https://model-gateway.public.beta.myninja.ai`  
**Protocol**: OpenAI-compatible REST API  
**Auth**: Bearer token  

### Available Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | Chat / text generation |
| `/v1/images/generations` | POST | Image generation |
| `/v1/videos` | POST | Video generation (submit) |
| `/v1/videos/{id}` | GET | Video status (poll) |
| `/v1/videos/{id}/content` | GET | Video download |
| `/v1/embeddings` | POST | Text embeddings |

### Available Models

See [MODELS.md](MODELS.md) for the complete model catalog with aliases, capabilities, and parameters.

---

## Configuration

### Settings File

Credentials are stored in `/root/.claude/settings.json`:

```json
{
    "env": {
        "ANTHROPIC_AUTH_TOKEN": "sk-your-api-key",
        "ANTHROPIC_BASE_URL": "https://model-gateway.public.beta.myninja.ai",
        "ANTHROPIC_MODEL": "ninja-cline-complex"
    }
}
```

The utility library reads this file automatically. No manual configuration needed.

### Environment Variable Overrides

You can override settings with environment variables:

```bash
export LITELLM_API_KEY="sk-different-key"
export LITELLM_BASE_URL="https://different-gateway.example.com"
```

### Verifying Configuration

```python
from utils.litellm_client import get_config

cfg = get_config()
print(f"Gateway: {cfg['base_url']}")
print(f"Key:     {cfg['api_key'][:10]}...")
print(f"Default: {cfg['default_model']}")
print(f"Source:  {cfg['source']}")
```

Or from the command line:

```bash
cd /workspace/phantom
python -m utils.litellm_client
```

---

## Utility Library

The `utils/` package provides ready-to-use functions for all model types.

### Package Structure

```
utils/
├── __init__.py          # Package init
├── litellm_client.py    # Core config, auth, model aliases
├── chat.py              # Chat completions (text generation)
├── images.py            # Image generation
├── video.py             # Video generation (async workflow)
└── embeddings.py        # Text embeddings
```

### Quick Import Reference

```python
# Chat
from utils.chat import chat, chat_messages, chat_stream, chat_json

# Images
from utils.images import generate_image, generate_images

# Video
from utils.video import generate_video, submit_video, poll_video, download_video

# Embeddings
from utils.embeddings import embed, embed_batch, cosine_similarity

# Config & models
from utils.litellm_client import get_config, resolve_model, MODELS
```

---

## Chat Completions

### Simple One-Shot

```python
from utils.chat import chat

# Default model (from settings.json)
answer = chat("What is the capital of France?")
print(answer)  # "Paris"

# Specific model
answer = chat("Explain quantum computing in one sentence", model="claude-opus")

# With system prompt
answer = chat(
    "What should I cook tonight?",
    model="gpt-5",
    system="You are a professional chef. Be creative and concise.",
)
```

### Full Message History

```python
from utils.chat import chat_messages

response = chat_messages([
    {"role": "system", "content": "You are a Python expert."},
    {"role": "user", "content": "How do I read a CSV file?"},
    {"role": "assistant", "content": "You can use pandas: pd.read_csv('file.csv')"},
    {"role": "user", "content": "What about without pandas?"},
])
print(response)
```

### Streaming

```python
from utils.chat import chat_stream

for chunk in chat_stream("Tell me a short story about a robot"):
    print(chunk, end="", flush=True)
print()  # newline at end
```

### JSON Mode

```python
from utils.chat import chat_json

# Returns a parsed Python dict
data = chat_json("List 3 programming languages with their year of creation")
print(data)
# {"languages": [{"name": "Python", "year": 1991}, ...]}

# With additional system instructions
data = chat_json(
    "Analyze the sentiment of: 'I love this product!'",
    system="You are a sentiment analysis engine.",
    model="claude-haiku",
)
print(data)
# {"sentiment": "positive", "confidence": 0.95}
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | str | required | The user message |
| `model` | str | config default | Model alias or full ID |
| `system` | str | None | System prompt |
| `max_tokens` | int | 4096 | Max response tokens |
| `temperature` | float | 0.7 | Randomness (0.0-1.0) |
| `timeout` | int | 120 | Request timeout (seconds) |

---

## Image Generation

### Basic Usage

```python
from utils.images import generate_image

# Default model and size
path = generate_image("A sunset over mountain peaks, oil painting style")
print(f"Saved to: {path}")  # "generated_image.png"

# With options
path = generate_image(
    prompt="A futuristic city skyline at night, neon lights",
    model="gemini-image",       # or "gpt-image"
    size="1536x1024",           # landscape
    output="city_skyline.png",
)
```

### Multiple Images

```python
from utils.images import generate_images

paths = generate_images(
    prompt="Variations of a logo for a tech startup",
    n=3,
    output_dir="logos/",
    prefix="logo",
)
print(paths)  # ["logos/logo_1.png", "logos/logo_2.png", "logos/logo_3.png"]
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | str | required | Image description |
| `model` | str | `"gpt-image"` | `"gpt-image"` or `"gemini-image"` |
| `size` | str | `"1024x1024"` | `"1024x1024"`, `"1024x1536"`, `"1536x1024"` |
| `output` | str | `"generated_image.png"` | Output file path |
| `n` | int | 1 | Number of images |
| `timeout` | int | 120 | Request timeout (seconds) |

### Tips

- **`gemini-image` is more reliable** — Use it as the primary model
- **`gpt-image` may have transient errors** — Retry or fall back to gemini
- Images are downloaded from a URL returned by the gateway
- Supported output formats: PNG (default based on extension)

---

## Video Generation

Video generation is **asynchronous** — it takes 60-120 seconds to complete.

### All-in-One (Recommended)

```python
from utils.video import generate_video

# Simple usage — handles submit, poll, and download
path = generate_video("A cat playing with a ball of yarn in a sunny garden")
print(f"Saved to: {path}")  # "generated_video.mp4"

# With options
path = generate_video(
    prompt="Aerial drone shot of a coastline at golden hour, cinematic",
    model="sora-pro",        # higher quality
    size="1280x720",         # landscape
    seconds=8,               # max duration
    output="coastline.mp4",
    max_wait=300,            # 5 min timeout
)
```

### Step-by-Step (More Control)

```python
from utils.video import submit_video, check_video_status, poll_video, download_video

# Step 1: Submit
video_id = submit_video(
    "A robot walking through a forest",
    model="sora",
    size="1280x720",
    seconds=8,
)
print(f"Submitted: {video_id}")

# Step 2: Check status (single check)
info = check_video_status(video_id)
print(f"Status: {info['status']}")  # "queued", "in_progress", "completed"

# Step 2b: Or poll until done (blocking)
status = poll_video(video_id, interval=5, max_wait=300)
print(f"Final status: {status}")  # "completed"

# Step 3: Download
path = download_video(video_id, output="robot_forest.mp4")
print(f"Saved to: {path}")
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `prompt` | str | required | Video description |
| `model` | str | `"sora"` | `"sora"` or `"sora-pro"` |
| `size` | str | `"1280x720"` | `"1280x720"` (landscape) or `"720x1280"` (portrait) |
| `seconds` | int | 8 | Duration (max 8) |
| `output` | str | `"generated_video.mp4"` | Output file path |
| `max_wait` | int | 300 | Max poll time (seconds) |
| `verbose` | bool | True | Print progress |

### Video Workflow Diagram

```
submit_video()          poll_video()              download_video()
     │                       │                          │
     ▼                       ▼                          ▼
POST /v1/videos  ──►  GET /v1/videos/{id}  ──►  GET /v1/videos/{id}/content
     │                       │                          │
     ▼                       ▼                          ▼
 video_id            queued → in_progress         MP4 file bytes
                     → completed
```

### Tips

- **`sora` is faster**, `sora-pro` is higher quality
- Generation typically takes **60-120 seconds**
- Max duration is **8 seconds**
- The `custom-llm-provider: openai` header is required for status/content endpoints (handled automatically by the utilities)
- Output format is always **MP4**

---

## Embeddings

### Single Text

```python
from utils.embeddings import embed

vector = embed("Hello world")
print(f"Dimensions: {len(vector)}")  # 1536

# Higher-dimensional model
vector = embed("Hello world", model="embed-large")
print(f"Dimensions: {len(vector)}")  # 3072
```

### Batch Embedding

```python
from utils.embeddings import embed_batch

texts = ["cat", "dog", "fish", "car", "bicycle"]
vectors = embed_batch(texts)
print(f"{len(vectors)} vectors, {len(vectors[0])} dimensions each")
```

### Similarity Comparison

```python
from utils.embeddings import embed, cosine_similarity

v1 = embed("machine learning")
v2 = embed("artificial intelligence")
v3 = embed("cooking recipes")

sim_close = cosine_similarity(v1, v2)
sim_far = cosine_similarity(v1, v3)

print(f"ML ↔ AI:      {sim_close:.4f}")  # ~0.85
print(f"ML ↔ cooking: {sim_far:.4f}")    # ~0.15
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `text` | str | required | Text to embed |
| `texts` | list[str] | required | Texts to embed (batch) |
| `model` | str | `"embed-small"` | `"embed-small"` (1536d) or `"embed-large"` (3072d) |
| `timeout` | int | 30 | Request timeout (seconds) |

### Use Cases

- **Semantic search**: Embed queries and documents, find nearest neighbors
- **Document similarity**: Compare documents by cosine similarity
- **Clustering**: Group similar texts together
- **RAG**: Retrieve relevant context for chat completions

---

## Raw API Access

If you need to make custom API calls beyond what the utilities provide:

### Using the Client Helpers

```python
from utils.litellm_client import get_headers, api_url, resolve_model
import requests

# Build URL and headers automatically
url = api_url("/v1/chat/completions")
headers = get_headers()

# Make custom request
r = requests.post(url, headers=headers, json={
    "model": resolve_model("claude-sonnet"),
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100,
    "temperature": 0.5,
    "top_p": 0.9,  # custom parameter
})

data = r.json()
print(data["choices"][0]["message"]["content"])
```

### Using curl

```bash
# List models
curl -s -H "Authorization: Bearer $API_KEY" \
  "https://model-gateway.public.beta.myninja.ai/v1/models" | jq .

# Chat completion
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "https://model-gateway.public.beta.myninja.ai/v1/chat/completions" \
  -d '{
    "model": "claude-sonnet-4-5-20250929",
    "messages": [{"role": "user", "content": "Hello"}],
    "max_tokens": 100
  }'

# Image generation
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "https://model-gateway.public.beta.myninja.ai/v1/images/generations" \
  -d '{
    "model": "google/gemini/gemini-3-pro-image-preview",
    "prompt": "A sunset",
    "size": "1024x1024"
  }'

# Video generation (submit)
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "https://model-gateway.public.beta.myninja.ai/v1/videos" \
  -d '{
    "model": "openai/openai/sora-2",
    "prompt": "A bouncing ball",
    "seconds": "8",
    "size": "1280x720"
  }'

# Video status (poll) — note the custom-llm-provider header
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "custom-llm-provider: openai" \
  "https://model-gateway.public.beta.myninja.ai/v1/videos/{VIDEO_ID}"

# Video download
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "custom-llm-provider: openai" \
  "https://model-gateway.public.beta.myninja.ai/v1/videos/{VIDEO_ID}/content" \
  --output video.mp4

# Embeddings
curl -s -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "https://model-gateway.public.beta.myninja.ai/v1/embeddings" \
  -d '{
    "model": "openai/openai/text-embedding-3-small",
    "input": "Hello world"
  }'
```

---

## Error Handling

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| `500 APIConnectionError` | Transient gateway issue | Retry after a few seconds |
| `400 Invalid size` | Wrong image/video dimensions | Check valid sizes in MODELS.md |
| `404 Model not found` | Wrong model ID or endpoint | Use aliases or check MODELS.md |
| `503 No available capacity` | Model overloaded | Retry later or use different model |
| `401 Unauthorized` | Invalid API key | Check settings.json |

### Retry Pattern

```python
import time
from utils.chat import chat

def chat_with_retry(prompt, model="claude-sonnet", max_retries=3):
    """Chat with automatic retry on transient errors."""
    for attempt in range(max_retries):
        try:
            return chat(prompt, model=model)
        except RuntimeError as e:
            if attempt < max_retries - 1 and ("500" in str(e) or "503" in str(e)):
                wait = 2 ** attempt  # exponential backoff: 1s, 2s, 4s
                print(f"Retry {attempt + 1}/{max_retries} in {wait}s...")
                time.sleep(wait)
            else:
                raise

answer = chat_with_retry("What is 2+2?")
```

### Image Generation with Fallback

```python
from utils.images import generate_image

def generate_image_reliable(prompt, **kwargs):
    """Try gpt-image first, fall back to gemini-image."""
    try:
        return generate_image(prompt, model="gpt-image", **kwargs)
    except RuntimeError:
        print("gpt-image failed, falling back to gemini-image...")
        return generate_image(prompt, model="gemini-image", **kwargs)

path = generate_image_reliable("A beautiful landscape")
```

---

## Building Custom Utilities

### Pattern: Wrap an Existing Utility

```python
"""Custom utility for generating product descriptions."""

from utils.chat import chat_json

def generate_product_description(product_name: str, features: list[str]) -> dict:
    """Generate a marketing description for a product."""
    prompt = f"""Create a product description for "{product_name}" with these features:
    {', '.join(features)}
    
    Return JSON with keys: tagline, description, bullet_points"""
    
    return chat_json(prompt, model="claude-sonnet")

# Usage
result = generate_product_description("SuperWidget", ["fast", "lightweight", "durable"])
print(result["tagline"])
```

### Pattern: Combine Multiple Utilities

```python
"""Custom utility for creating illustrated blog posts."""

from utils.chat import chat
from utils.images import generate_image

def create_illustrated_post(topic: str) -> dict:
    """Generate a blog post with a matching illustration."""
    
    # Generate the text
    post = chat(
        f"Write a short blog post about: {topic}",
        model="claude-sonnet",
        system="Write engaging, concise blog posts. 2-3 paragraphs.",
    )
    
    # Generate a matching image
    image_prompt = chat(
        f"Describe a single image that would illustrate this blog post: {post[:500]}",
        model="claude-haiku",
        system="Describe an image in one detailed sentence. No text in the image.",
    )
    
    image_path = generate_image(image_prompt, model="gemini-image")
    
    return {"text": post, "image": image_path, "image_prompt": image_prompt}

result = create_illustrated_post("The future of AI")
```

### Pattern: Semantic Search

```python
"""Simple semantic search using embeddings."""

from utils.embeddings import embed, embed_batch, cosine_similarity

class SemanticSearch:
    def __init__(self, documents: list[str]):
        self.documents = documents
        self.vectors = embed_batch(documents)
    
    def search(self, query: str, top_k: int = 3) -> list[tuple[str, float]]:
        """Find the most relevant documents for a query."""
        query_vec = embed(query)
        scores = [
            (doc, cosine_similarity(query_vec, vec))
            for doc, vec in zip(self.documents, self.vectors)
        ]
        scores.sort(key=lambda x: x[1], reverse=True)
        return scores[:top_k]

# Usage
docs = [
    "Python is a programming language",
    "Cats are popular pets",
    "Machine learning uses neural networks",
    "The weather is sunny today",
]
search = SemanticSearch(docs)
results = search.search("AI and deep learning")
for doc, score in results:
    print(f"  {score:.4f}: {doc}")
```

### Pattern: New API Endpoint

If the gateway adds a new endpoint, here's how to create a utility for it:

```python
"""Template for a new utility module."""

import requests
from utils.litellm_client import get_headers, api_url, resolve_model

def my_new_function(param1: str, model: str = "default-model") -> dict:
    """
    Description of what this function does.
    
    Args:
        param1: Description.
        model:  Model alias or full ID.
    
    Returns:
        Description of return value.
    """
    model_id = resolve_model(model)
    
    r = requests.post(
        api_url("/v1/new-endpoint"),
        headers=get_headers(),
        json={
            "model": model_id,
            "param1": param1,
        },
        timeout=60,
    )
    
    if r.status_code != 200:
        error = r.json().get("error", {}).get("message", r.text[:300])
        raise RuntimeError(f"Request failed ({r.status_code}): {error}")
    
    return r.json()
```

The key building blocks from `litellm_client.py` are:
- **`get_headers()`** — Returns auth headers
- **`api_url(path)`** — Builds full URL from relative path
- **`resolve_model(alias)`** — Converts short alias to full model ID
- **`get_config()`** — Returns API key, base URL, default model

---

## Running Self-Tests

Each utility module has a built-in self-test:

```bash
cd /workspace/phantom

# Test configuration
python -m utils.litellm_client

# Test chat (fast, ~5s)
python -m utils.chat

# Test embeddings (fast, ~5s)
python -m utils.embeddings

# Test images (~30s, uses API credits)
python -m utils.images

# Test video (~120s, uses API credits)
python -m utils.video
```

---

## Quick Reference

### One-Liners

```python
# Chat
from utils.chat import chat; print(chat("Hello!"))

# Image
from utils.images import generate_image; generate_image("A sunset")

# Video
from utils.video import generate_video; generate_video("A bouncing ball")

# Embedding
from utils.embeddings import embed; print(len(embed("Hello")))

# Similarity
from utils.embeddings import embed, cosine_similarity
print(cosine_similarity(embed("cat"), embed("dog")))
```

### Model Quick Reference

```
CHAT:   claude-opus | claude-sonnet | claude-haiku | gpt-5 | gemini-pro | ninja-fast
IMAGE:  gpt-image | gemini-image
VIDEO:  sora | sora-pro
EMBED:  embed-small | embed-large
```