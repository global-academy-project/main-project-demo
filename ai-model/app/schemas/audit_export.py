"""감사 대응 보고서 내려받기(HWPX) 요청 계약 (B 소유).

Spring이 저장된 보고서 값을 그대로 보낸다 (상세 응답 `GET .../audit-reports/{id}`와 같은 이름의 필드).
응답은 JSON이 아니라 파일 바이트다. 모르는 필드는 무시한다.
"""

from __future__ import annotations

from datetime import date
from typing import Any, Literal

from pydantic import Field, field_validator, model_validator

from .base_schemas import CamelModel

# 화면의 수정 한도(20,000자)와 같다.
MAX_TEXT = 20_000
MAX_ITEMS = 20


class AuditExportItem(CamelModel):
    """보고서 항목 하나. 요약은 사람이 고친 저장값이다."""

    query_type: str = ""
    title: str = Field(default="", max_length=200)
    stats: dict[str, Any] = Field(default_factory=dict)
    summary: str | None = Field(default=None, max_length=MAX_TEXT)
    # 근거 기록 수: 숫자(evidenceCount)로 받거나 목록(evidence)으로 받는다. 둘 다 없으면 0건.
    evidence_count: int | None = Field(default=None, strict=True, ge=0)
    evidence: list[Any] | None = None
    truncated: bool | None = None
    total: int | None = Field(default=None, strict=True, ge=0)

    def evidence_total(self) -> int:
        if self.evidence_count is not None:
            return self.evidence_count
        return len(self.evidence) if self.evidence is not None else 0


class AuditExportInput(CamelModel):
    format: Literal["HWPX"] = "HWPX"
    report_id: int = Field(strict=True, gt=0)
    title: str = Field(default="", max_length=200)
    site_name: str = Field(default="", max_length=200)
    date_from: str = Field(min_length=10, max_length=10)
    date_to: str = Field(min_length=10, max_length=10)
    created_by_name: str | None = Field(default=None, max_length=100)
    summary: str | None = Field(default=None, max_length=MAX_TEXT)
    items: list[AuditExportItem] = Field(min_length=1, max_length=MAX_ITEMS)

    @field_validator("date_from", "date_to")
    @classmethod
    def valid_date(cls, value: str) -> str:
        try:
            date.fromisoformat(value)
        except ValueError as exc:
            raise ValueError("날짜는 YYYY-MM-DD 형식이어야 합니다.") from exc
        return value

    @model_validator(mode="after")
    def valid_period(self) -> "AuditExportInput":
        if self.date_from > self.date_to:
            raise ValueError("조회 시작일은 종료일보다 늦을 수 없습니다.")
        return self
