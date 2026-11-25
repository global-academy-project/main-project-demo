"""감사 대응 보고서 내려받기 서비스. FastAPI를 모른다 (Request, Response 없음).

변환 실패를 서버 오류 응답으로 바꾼다. 응답 코드는 기존 바깥 코드만 쓴다(error_catalog.ExternalCode).
  - 라이브러리가 없다 → 503 SERVICE_UNAVAILABLE (환경 문제)
  - 문서를 만들지 못했다 → 502 BAD_GATEWAY (원문은 로그에만 남기고 응답에는 고정 문구만)
"""

from __future__ import annotations

import logging
from datetime import datetime
from urllib.parse import quote

from app.agent.audit_export_hwpx import (
    HWPX_MEDIA_TYPE,
    HwpxBuildError,
    HwpxUnavailableError,
    build_audit_hwpx,
    clean_text,
)
from app.exceptions import BusinessError
from app.exceptions.error_catalog import ExternalCode
from app.schemas.audit_export import AuditExportInput

__all__ = ["HWPX_MEDIA_TYPE", "content_disposition", "export_report"]

logger = logging.getLogger(__name__)

_FALLBACK_NAME = "audit-report"
_BAD_FILENAME = str.maketrans({c: "_" for c in '\\/:*?"<>|\r\n\t'})


def content_disposition(report: AuditExportInput) -> str:
    """내려받기 헤더. 한글 이름은 filename*(UTF-8), 못 읽는 곳을 위해 영문 이름도 같이 준다."""
    name = clean_text(report.title).strip().translate(_BAD_FILENAME)[:100] or f"{_FALLBACK_NAME}-{report.report_id}"
    return f"attachment; filename=\"{_FALLBACK_NAME}-{report.report_id}.hwpx\"; filename*=UTF-8''{quote(name + '.hwpx')}"


def export_report(body: AuditExportInput, *, now: datetime | None = None) -> bytes:
    try:
        return build_audit_hwpx(body, now=now)
    except HwpxUnavailableError as exc:
        logger.error("HWPX 변환 라이브러리를 쓸 수 없음 (%s)", type(exc).__name__)
        raise BusinessError(
            code=ExternalCode.SERVICE_UNAVAILABLE,
            message="HWPX 파일을 만들 수 없는 환경입니다.",
            status_code=503,
        ) from exc
    except HwpxBuildError as exc:
        logger.error("HWPX 변환 실패: %s", exc)
        raise BusinessError(
            code=ExternalCode.BAD_GATEWAY,
            message="HWPX 파일을 만들지 못했습니다.",
            status_code=502,
        ) from exc
