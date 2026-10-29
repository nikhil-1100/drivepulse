"""Headless screenshots of the DrivePulse web preview using the Chrome DevTools
Protocol directly (no Playwright dependency).

Usage:
    python scripts/qa_screens.py --chrome "C:/path/to/chrome.exe" --out docs/screenshots

The script starts a throw-away headless Chrome, emulates a 390×844 phone at
2× DPR and captures the dashboard, file browser, cleanup and history screens by
dispatching real pointer events at known coordinates.
"""

from __future__ import annotations

import argparse
import asyncio
import base64
import json
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

import requests
import websockets

BASE = "http://127.0.0.1:8099/?skipIntro=1&theme=light"


class CDP:
    def __init__(self, ws) -> None:
        self.ws = ws
        self._id = 0

    async def send(self, method: str, params: dict | None = None) -> dict:
        self._id += 1
        message = {"id": self._id, "method": method, "params": params or {}}
        await self.ws.send(json.dumps(message))
        while True:
            reply = json.loads(await self.ws.recv())
            if reply.get("id") == self._id:
                if "error" in reply:
                    raise RuntimeError(f"{method}: {reply['error']}")
                return reply.get("result", {})

    async def click(self, x: float, y: float) -> None:
        for kind in ("mousePressed", "mouseReleased"):
            await self.send(
                "Input.dispatchMouseEvent",
                {
                    "type": kind,
                    "x": x,
                    "y": y,
                    "button": "left",
                    "clickCount": 1,
                },
            )
            await asyncio.sleep(0.05)


async def capture(ws_url: str, out: Path) -> None:
    async with websockets.connect(ws_url, max_size=40 * 1024 * 1024) as ws:
        cdp = CDP(ws)
        await cdp.send("Page.enable")
        await cdp.send(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": 390,
                "height": 844,
                "deviceScaleFactor": 2,
                "mobile": True,
            },
        )
        await cdp.send("Page.navigate", {"url": BASE})
        await asyncio.sleep(9)

        await cdp.send("Page.captureScreenshot", {"format": "png"})
        shot = await cdp.send("Page.captureScreenshot", {"format": "png"})
        out.mkdir(parents=True, exist_ok=True)
        (out / "dashboard-light.png").write_bytes(base64.b64decode(shot["data"]))
        print("dashboard-light.png")

        # Tap the SanDisk card (second storage card).
        await cdp.click(280, 300)
        await asyncio.sleep(2.5)
        shot = await cdp.send("Page.captureScreenshot", {"format": "png"})
        (out / "browse-files.png").write_bytes(base64.b64decode(shot["data"]))
        print("browse-files.png")

        await cdp.send("Page.navigate", {"url": BASE})
        await asyncio.sleep(5)
        # Quick actions: Clean up is the sixth tile, third row/column on mobile.
        await cdp.click(350, 680)
        await asyncio.sleep(2.5)
        shot = await cdp.send("Page.captureScreenshot", {"format": "png"})
        (out / "cleanup.png").write_bytes(base64.b64decode(shot["data"]))
        print("cleanup.png")

        await cdp.send("Page.navigate", {"url": BASE})
        await asyncio.sleep(5)
        # History tab, right side of the bottom nav.
        await cdp.click(330, 795)
        await asyncio.sleep(2)
        shot = await cdp.send("Page.captureScreenshot", {"format": "png"})
        (out / "history.png").write_bytes(base64.b64decode(shot["data"]))
        print("history.png")

        # Wide desktop layout.
        await cdp.send(
            "Emulation.setDeviceMetricsOverride",
            {
                "width": 1280,
                "height": 900,
                "deviceScaleFactor": 1,
                "mobile": False,
            },
        )
        await cdp.send("Page.navigate", {"url": BASE})
        await asyncio.sleep(6)
        shot = await cdp.send("Page.captureScreenshot", {"format": "png"})
        (out / "dashboard-wide.png").write_bytes(base64.b64decode(shot["data"]))
        print("dashboard-wide.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--chrome", required=True, help="Path to chrome.exe")
    parser.add_argument("--out", default="docs/screenshots")
    parser.add_argument("--port", type=int, default=9333)
    args = parser.parse_args()

    profile = tempfile.mkdtemp(prefix="drivepulse-cdp-")
    chrome = subprocess.Popen(
        [
            args.chrome,
            "--headless=new",
            "--no-sandbox",
            "--disable-gpu",
            "--hide-scrollbars",
            "--use-gl=swiftshader",
            f"--remote-debugging-port={args.port}",
            f"--user-data-dir={profile}",
            "about:blank",
        ],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    try:
        target = None
        for _ in range(40):
            time.sleep(0.25)
            try:
                pages = requests.get(
                    f"http://127.0.0.1:{args.port}/json/list", timeout=1
                ).json()
            except Exception:
                continue
            for page in pages:
                if page.get("type") == "page":
                    target = page
                    break
            if target:
                break
        if target is None:
            raise RuntimeError("Chrome did not expose a page target")
        asyncio.run(capture(target["webSocketDebuggerUrl"], Path(args.out)))
    finally:
        chrome.terminate()
        try:
            chrome.wait(timeout=5)
        except subprocess.TimeoutExpired:
            chrome.kill()
        shutil.rmtree(profile, ignore_errors=True)


if __name__ == "__main__":
    main()
