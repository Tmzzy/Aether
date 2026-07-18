from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def test_frontend_codex_config_advertises_websocket_support() -> None:
    content = (ROOT / "frontend/src/views/public/home-config.ts").read_text(encoding="utf-8")

    assert 'wire_api = "responses"' in content
    assert "supports_websockets = true" in content
