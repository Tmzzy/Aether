"""
Tunnel Hub 配置

控制 worker 是否通过 aether-hub 转发 tunnel 帧。

Hub 是可选的独立服务。默认关闭；仅在显式配置 TUNNEL_HUB_URL 时启用。
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from urllib.parse import quote

_DEFAULT_HUB_CONNECT_TIMEOUT_SECONDS = 5.0


@dataclass(frozen=True)
class HubConfig:
    enabled: bool
    url: str
    connect_timeout_seconds: float

    @property
    def local_relay_base_url(self) -> str:
        return f"{self.url.rstrip('/')}/local/relay"

    def local_relay_url(self, node_id: str) -> str:
        return f"{self.local_relay_base_url}/{quote(node_id, safe='')}"


_hub_config: HubConfig | None = None


def get_hub_config() -> HubConfig:
    """读取 Hub 配置（进程内缓存）。"""
    global _hub_config
    if _hub_config is not None:
        return _hub_config

    hub_url = os.getenv("TUNNEL_HUB_URL", "").strip()
    connect_timeout = float(
        os.getenv("TUNNEL_HUB_CONNECT_TIMEOUT_SECONDS", str(_DEFAULT_HUB_CONNECT_TIMEOUT_SECONDS))
    )
    _hub_config = HubConfig(
        enabled=bool(hub_url),
        url=hub_url,
        connect_timeout_seconds=connect_timeout,
    )
    return _hub_config


def reset_hub_config_cache() -> None:
    """测试或热更新场景下清理配置缓存。"""
    global _hub_config
    _hub_config = None
