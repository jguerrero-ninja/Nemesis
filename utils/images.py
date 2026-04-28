"""
Image Generation Utilities
===========================

Generate images from text prompts using GPT Image 1.5 or Gemini Image.

Supported models:
    - gpt-image (openai/openai/gpt-image-1.5)
    - gemini-image (google/gemini/gemini-3-pro-image-preview)

Valid sizes: "1024x1024", "1024x1536", "1536x1024"

Usage:
    from utils.images import generate_image

    # Simple generation
    path = generate_image("A sunset over mountains")

    # With options
    path = generate_image(
        prompt="A robot ninja in a bamboo forest",
        model="gemini-image",
        size="1536x1024",
        output="ninja.png",
    )
"""

import base64
import requests
from pathlib import Path

from utils.litellm_client import get_headers, api_url, resolve_model

# Valid sizes for image generation
VALID_SIZES = ["1024x1024", "1024x1536", "1536x1024"]

# Default model for image generation
# gemini-image is recommended — gpt-image has intermittent 500 gateway errors
DEFAULT_IMAGE_MODEL = "gemini-image"


def generate_image(
    prompt: str,
    model: str = DEFAULT_IMAGE_MODEL,
    size: str = "1024x1024",
    output: str = "generated_image.png",
    n: int = 1,
    timeout: int = 120,
) -> str:
    """
    Generate an image from a text prompt.

    Args:
        prompt:  Text description of the desired image.
        model:   Model alias or full ID. Options: "gpt-image", "gemini-image".
        size:    Image dimensions. One of: "1024x1024", "1024x1536", "1536x1024".
        output:  Output file path for the generated image.
        n:       Number of images to generate (only first is saved).
        timeout: Request timeout in seconds.

    Returns:
        Path to the saved image file.

    Raises:
        ValueError: If size is not valid.
        RuntimeError: If the API returns an error.

    Examples:
        >>> generate_image("A cat sitting on a windowsill")
        'generated_image.png'

        >>> generate_image("Logo design", model="gemini-image", size="1024x1024")
        'generated_image.png'
    """
    if size not in VALID_SIZES:
        raise ValueError(f"Invalid size '{size}'. Must be one of: {VALID_SIZES}")

    model_id = resolve_model(model)

    payload = {
        "model": model_id,
        "prompt": prompt,
        "n": n,
        "size": size,
    }

    r = requests.post(
        api_url("/v1/images/generations"),
        headers=get_headers(),
        json=payload,
        timeout=timeout,
    )

    if r.status_code != 200:
        error = r.json().get("error", {}).get("message", r.text[:300])
        raise RuntimeError(f"Image generation failed ({r.status_code}): {error}")

    data = r.json()

    if "data" not in data or len(data["data"]) == 0:
        raise RuntimeError(f"No image data in response: {data}")

    item = data["data"][0]

    # Gateway returns a URL to the generated image
    if item.get("url"):
        img_r = requests.get(item["url"], timeout=60)
        if img_r.status_code != 200:
            raise RuntimeError(f"Failed to download image: {img_r.status_code}")
        Path(output).write_bytes(img_r.content)
        return output

    # Fallback: base64 encoded image
    if item.get("b64_json"):
        img_data = base64.b64decode(item["b64_json"])
        Path(output).write_bytes(img_data)
        return output

    raise RuntimeError(f"Response has no url or b64_json: {item}")


def generate_images(
    prompt: str,
    model: str = DEFAULT_IMAGE_MODEL,
    size: str = "1024x1024",
    n: int = 2,
    output_dir: str = ".",
    prefix: str = "image",
    timeout: int = 180,
) -> list[str]:
    """
    Generate multiple images from a single prompt.

    Args:
        prompt:     Text description of the desired images.
        model:      Model alias or full ID.
        size:       Image dimensions.
        n:          Number of images to generate (1-4).
        output_dir: Directory to save images.
        prefix:     Filename prefix (files named {prefix}_1.png, etc.).
        timeout:    Request timeout in seconds.

    Returns:
        List of paths to saved image files.

    Example:
        >>> paths = generate_images("Variations of a sunset", n=3)
        ['image_1.png', 'image_2.png', 'image_3.png']
    """
    if size not in VALID_SIZES:
        raise ValueError(f"Invalid size '{size}'. Must be one of: {VALID_SIZES}")

    model_id = resolve_model(model)
    Path(output_dir).mkdir(parents=True, exist_ok=True)

    payload = {
        "model": model_id,
        "prompt": prompt,
        "n": n,
        "size": size,
    }

    r = requests.post(
        api_url("/v1/images/generations"),
        headers=get_headers(),
        json=payload,
        timeout=timeout,
    )

    if r.status_code != 200:
        error = r.json().get("error", {}).get("message", r.text[:300])
        raise RuntimeError(f"Image generation failed ({r.status_code}): {error}")

    data = r.json()
    saved = []

    for i, item in enumerate(data.get("data", []), 1):
        out_path = str(Path(output_dir) / f"{prefix}_{i}.png")

        if item.get("url"):
            img_r = requests.get(item["url"], timeout=60)
            if img_r.status_code == 200:
                Path(out_path).write_bytes(img_r.content)
                saved.append(out_path)
        elif item.get("b64_json"):
            img_data = base64.b64decode(item["b64_json"])
            Path(out_path).write_bytes(img_data)
            saved.append(out_path)

    return saved


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    import os

    print("=== Image Generation Utility Test ===\n")

    print("1. Generate image with default model (gpt-image):")
    try:
        path = generate_image(
            "A simple red circle on a white background, minimal",
            output="/tmp/test_image.png",
        )
        size = os.path.getsize(path)
        print(f"   ✅ Saved to {path} ({size:,} bytes)\n")
        os.remove(path)
    except Exception as e:
        print(f"   ⚠️  gpt-image error (may be transient): {e}\n")

    print("2. Generate image with gemini-image:")
    try:
        path = generate_image(
            "A simple blue square on a white background, minimal",
            model="gemini-image",
            output="/tmp/test_gemini.png",
        )
        size = os.path.getsize(path)
        print(f"   ✅ Saved to {path} ({size:,} bytes)\n")
        os.remove(path)
    except Exception as e:
        print(f"   ❌ Error: {e}\n")

    print("✅ Image tests complete!")