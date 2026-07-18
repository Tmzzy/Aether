from __future__ import annotations

import pytest

from src.services.proxy_node.hub_config import get_hub_config, reset_hub_config_cache


@pytest.fixture(autouse=True)
def reset_config_cache() -> None:
    reset_hub_config_cache()
    yield
    reset_hub_config_cache()


def test_hub_is_disabled_without_explicit_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TUNNEL_HUB_URL", raising=False)

    config = get_hub_config()

    assert config.enabled is False
    assert config.url == ""


def test_hub_uses_explicit_url(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TUNNEL_HUB_URL", "https://hub.example.com/")
    monkeypatch.setenv("TUNNEL_HUB_CONNECT_TIMEOUT_SECONDS", "7.5")

    config = get_hub_config()

    assert config.enabled is True
    assert config.local_relay_url("node/1") == "https://hub.example.com/local/relay/node%2F1"
    assert config.connect_timeout_seconds == 7.5
