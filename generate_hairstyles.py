#!/usr/bin/env python3
"""Generate AI hairstyle images using Pollinations.ai (free, no API key needed)."""

import urllib.request
import urllib.parse
import ssl
import os
import time

# Bypass SSL verification (macOS Python often lacks certificates)
ssl._create_default_https_context = ssl._create_unverified_context

OUTPUT_DIR = "assets/hairstyles"

# Hairstyle definitions with detailed prompts for African hairstyles
HAIRSTYLES = [
    {
        "filename": "box_braids.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with long box braids hairstyle, medium thickness braids flowing past shoulders, neat parting, studio lighting, professional headshot, clean background, high quality fashion photography, detailed hair texture"
    },
    {
        "filename": "natural_afro.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with full voluminous natural afro hair, rounded shape, well-defined coils, studio lighting, professional headshot, clean background, high quality fashion photography, natural beauty"
    },
    {
        "filename": "skin_fade.jpg",
        "prompt": "portrait photo of a handsome young black African man with clean skin fade haircut, short textured hair on top, sharp lineup, barber fresh cut, studio lighting, professional headshot, clean background, high quality photography"
    },
    {
        "filename": "faux_locs.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with faux locs hairstyle, medium-length faux dreadlocks, neat and uniform, hanging freely, studio lighting, professional headshot, clean background, high quality fashion photography"
    },
    {
        "filename": "defined_curls.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with well-defined spiral curls hairstyle, bouncy moisturized curls, medium length, studio lighting, professional headshot, clean background, high quality fashion photography"
    },
    {
        "filename": "cornrows.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with straight-back cornrows hairstyle, braided close to scalp, neat parallel rows, studio lighting, professional headshot, clean background, high quality fashion photography"
    },
    {
        "filename": "pixie_cut.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with short pixie cut hairstyle, tapered sides, slightly longer textured top, feminine and chic, studio lighting, professional headshot, clean background, high quality fashion photography"
    },
    {
        "filename": "taper_fade.jpg",
        "prompt": "portrait photo of a handsome young black African man with taper fade haircut, gradual fade on sides, medium-length styled hair on top, clean edges, studio lighting, professional headshot, clean background, high quality photography"
    },
    {
        "filename": "twist_out.jpg",
        "prompt": "portrait photo of a beautiful young black African woman with twist-out hairstyle, elongated defined curls, voluminous and textured natural hair, studio lighting, professional headshot, clean background, high quality fashion photography"
    },
]

def download_image(prompt, filename, width=512, height=640):
    """Generate and download an image from Pollinations.ai"""
    encoded_prompt = urllib.parse.quote(prompt)
    url = f"https://image.pollinations.ai/prompt/{encoded_prompt}?width={width}&height={height}&seed={hash(filename) % 10000}&nologo=true&model=flux"

    filepath = os.path.join(OUTPUT_DIR, filename)

    print(f"  Generating: {filename}")
    print(f"  URL: {url[:100]}...")

    try:
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=120) as response:
            data = response.read()
            with open(filepath, 'wb') as f:
                f.write(data)
            size_kb = len(data) / 1024
            print(f"  Done! ({size_kb:.1f} KB)")
            return True
    except Exception as e:
        print(f"  Error: {e}")
        return False

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print(f"Generating {len(HAIRSTYLES)} hairstyle images...")
    print(f"Output directory: {OUTPUT_DIR}\n")

    success = 0
    for i, style in enumerate(HAIRSTYLES, 1):
        print(f"[{i}/{len(HAIRSTYLES)}] {style['filename']}")
        if download_image(style['prompt'], style['filename']):
            success += 1
        # Small delay between requests to be polite
        if i < len(HAIRSTYLES):
            time.sleep(2)
        print()

    print(f"\nComplete! {success}/{len(HAIRSTYLES)} images generated.")
    print(f"Images saved in: {OUTPUT_DIR}/")

if __name__ == "__main__":
    main()
