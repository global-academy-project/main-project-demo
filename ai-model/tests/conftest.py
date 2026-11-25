"""시험 공통 환경 (11/17 B, 11/22 고정판).

시험 결과가 개발 PC의 환경변수·`.env`·작업 폴더 안의 `out/`·`data/` 폴더에 따라 달라지지 않게, 시험마다
아래를 먼저 고정한다. 다른 값이 필요한 시험은 자기 안에서 monkeypatch.setenv/delenv 나 Settings(...) 인자로
바꾼다 (이 고정보다 나중에 돌아서 이긴다).

1. 설정이 읽는 환경변수를 모두 지운다.
   - `Settings`·`RagEnvironmentSettings`·`EmbeddingServerSettings` 등 BaseSettings 하위 클래스의 모든 필드 이름
   - 앱 코드가 os.getenv 로 직접 읽는 이름 (EXTRA_ENV_NAMES)
   그 다음 TEST_ENV 값을 넣는다.
2. `.env` 파일을 읽지 않는다. 설정 클래스의 env_file 을 시험 동안 None 으로 둔다 (작업 폴더에 .env 가 있어도 무관).
   `Settings(_env_file=경로)` 처럼 시험이 직접 넘긴 값은 그대로 동작한다.
   **`.env` 읽기 자체를 시험하는 시험**(자기 tmp 폴더에 .env 를 쓰고 읽는다)은 `@pytest.mark.reads_dotenv` 를 붙인다. 그 시험은 env_file 을
   끄지 않는다 (환경변수 지우기는 그대로). 지금은 test_rag_configuration.py::test_dotenv_loading_and_environment_priority 하나뿐이다.
3. 적재 폴더(LOCAL_CHUNK_ROOT·LOCAL_CHUNK_DIR·LOCAL_VECTOR_DIR)는 시험마다 새로 만든, 없는 폴더를 가리킨다.
   코드 기본값(`out`, `out/law`, `data/vectors`)은 작업 폴더 기준 상대경로라서, 저장소에 out/ 이 있느냐에 따라 결과가
   갈렸다. 이제 out/ 이 있든 없든 같다. 이 값을 쓰는 시험은 자기 tmp_path 로 다시 정한다.
4. 앞뒤로 get_settings 캐시와 도구 레지스트리(agent_deps.get_tool_registry) 캐시를 비운다 (앞 시험의 설정이 남지 않게).
- 작업 폴더는 바꾸지 않는다: 저장소 루트를 작업 폴더로 기대하는 시험(별도 파이썬 실행 등)이 있다.

TEST_ENV 값:
- MSDS_TOOL=MOCK: 공단 API(키 필요)를 부르지 않는다. NETWORK_ENV=OPEN, CHECK_RULES_TOOL=MOCK: 기본값이 없는 필수 설정이다.
- LLM_PRELOAD=false: `with TestClient(app)`가 기동 때 실제 모델을 읽지 않게.
"""

from __future__ import annotations

import sys

import pytest
from pydantic_settings import BaseSettings

from app.core import get_settings

TEST_ENV = {
    "MSDS_TOOL": "MOCK",
    "NETWORK_ENV": "OPEN",
    "CHECK_RULES_TOOL": "MOCK",
    "LLM_PRELOAD": "false",
}

# 설정 클래스 필드가 아니라 앱 코드가 직접 읽는 환경변수 (app/ingest/*, app/publicdata/msds.py)
EXTRA_ENV_NAMES = (
    "KOSHA_MSDS_SERVICE_KEY",
    "KB_INGEST_API_TOKEN",
    "KB_INGEST_URL",
    "QDRANT_API_KEY",
    "LOCAL_CHUNK_ROOT",
    "LOCAL_CHUNK_DIR",
    "LOCAL_VECTOR_DIR",
)
# 시험이 없는 폴더를 가리키게 할 이름 → 임시 폴더 아래 이름 (폴더는 만들지 않는다)
PINNED_DIRS = {
    "LOCAL_CHUNK_ROOT": "chunk_root",
    "LOCAL_CHUNK_DIR": "chunk_dir",
    "LOCAL_VECTOR_DIR": "vector_dir",
}


def _settings_classes() -> list[type[BaseSettings]]:
    """앱의 BaseSettings 하위 클래스 전부 (RAG 설정은 처음 쓸 때 읽히므로 여기서 먼저 불러 둔다)."""
    try:
        import app.rag.config  # noqa: F401
    except Exception:  # RAG 부품이 없는 저장소여도 나머지 시험은 돈다
        pass
    found: list[type[BaseSettings]] = []
    todo = list(BaseSettings.__subclasses__())
    while todo:
        cls = todo.pop()
        if cls in found:
            continue
        found.append(cls)
        todo.extend(cls.__subclasses__())
    return [cls for cls in found if cls.__module__.split(".")[0] == "app"]


def _env_names(classes: list[type[BaseSettings]]) -> set[str]:
    names = set(EXTRA_ENV_NAMES)
    for cls in classes:
        for field_name, field in cls.model_fields.items():
            names.add(field_name.upper())
            alias = field.validation_alias
            if isinstance(alias, str):
                names.add(alias.upper())
    return names


def pytest_configure(config):
    config.addinivalue_line("markers", "reads_dotenv: .env 읽기 자체를 시험한다 (conftest 가 env_file 을 끄지 않는다)")


def _clear_caches() -> None:
    get_settings.cache_clear()
    deps = sys.modules.get("app.agent.agent_deps")
    if deps is not None and hasattr(deps, "get_tool_registry"):
        deps.get_tool_registry.cache_clear()


@pytest.fixture(autouse=True)
def _test_settings_env(request, monkeypatch, tmp_path_factory):
    import os

    classes = _settings_classes()
    wanted = _env_names(classes)
    for name in list(os.environ):  # Windows 는 대소문자를 가리지 않으므로 이름을 대문자로 맞춰 비교한다
        if name.upper() in wanted:
            monkeypatch.delenv(name, raising=False)
    if request.node.get_closest_marker("reads_dotenv") is None:
        for cls in classes:
            monkeypatch.setitem(cls.model_config, "env_file", None)
    pinned = tmp_path_factory.mktemp("pinned_dirs")
    for name, folder in PINNED_DIRS.items():
        monkeypatch.setenv(name, str(pinned / folder))
    for name, value in TEST_ENV.items():
        monkeypatch.setenv(name, value)
    _clear_caches()
    yield
    _clear_caches()
