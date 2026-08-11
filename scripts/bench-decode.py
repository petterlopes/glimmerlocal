#!/usr/bin/env python3
"""Deterministic decode benchmark for local Muse Glimmer."""
from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request


def wait_health(host: str, port: int, timeout_s: int = 180) -> None:
    url = f"http://{host}:{port}/health"
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=2) as r:
                if r.status == 200:
                    return
        except Exception:
            time.sleep(1)
    raise SystemExit(f"timeout waiting for {url}")


def chat(host: str, port: int, payload: dict, timeout_s: int = 600) -> dict:
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"http://{host}:{port}/v1/chat/completions",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout_s) as r:
        return json.load(r)


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--label", default="run")
    p.add_argument("--host", default=os.environ.get("MUSE_HOST", "127.0.0.1"))
    p.add_argument("--port", type=int, default=int(os.environ.get("MUSE_PORT", "8080")))
    p.add_argument("--max-tokens", type=int, default=int(os.environ.get("BENCH_MAX_TOKENS", "128")))
    p.add_argument("--reasoning", default=os.environ.get("BENCH_REASONING", "low"))
    p.add_argument(
        "--prompt",
        default=os.environ.get(
            "BENCH_PROMPT",
            "Count from 1 to 40 as digits separated by commas. No other text.",
        ),
    )
    p.add_argument("--warmup", action="store_true", default=True)
    p.add_argument("--no-warmup", action="store_false", dest="warmup")
    args = p.parse_args()

    wait_health(args.host, args.port)

    base = {
        "model": "muse-glimmer-30B",
        "temperature": 1.0,
        "top_p": 0.95,
        "chat_template_kwargs": {"reasoning_strength": args.reasoning},
    }
    if args.warmup:
        chat(
            args.host,
            args.port,
            {
                **base,
                "messages": [{"role": "user", "content": "Reply with exactly: WARM"}],
                "max_tokens": 32,
            },
        )

    t0 = time.time()
    m = chat(
        args.host,
        args.port,
        {
            **base,
            "messages": [{"role": "user", "content": args.prompt}],
            "max_tokens": args.max_tokens,
        },
    )
    wall = time.time() - t0
    msg = m["choices"][0]["message"]
    u = m.get("usage") or {}
    ct = int(u.get("completion_tokens") or 0)
    pt = int(u.get("prompt_tokens") or 0)
    out = {
        "label": args.label,
        "wall_s": round(wall, 3),
        "completion_tokens": ct,
        "prompt_tokens": pt,
        "tok_s": round((ct / wall) if wall and ct else 0.0, 3),
        "content_preview": (msg.get("content") or "")[:100],
        "reasoning_chars": len(msg.get("reasoning_content") or ""),
    }
    print(json.dumps(out, ensure_ascii=False))


if __name__ == "__main__":
    main()
