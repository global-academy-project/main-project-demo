"""HWPX 근거 기록 줄: total 이 null 이어도 "None건"이 나오지 않는다 (apply_audit_export_fix_v1)."""
import pytest

from app.agent.audit_export_hwpx import evidence_line
from app.schemas.audit_export import AuditExportInput, AuditExportItem


def _item(**kw):
    return AuditExportItem.model_validate(kw)


def test_truncated_without_total_has_no_none():
    line = evidence_line(_item(evidenceCount=100, truncated=True, total=None))
    assert line == "근거 기록 100건 · 일부만 담김"
    assert "None" not in line


def test_truncated_with_total_unchanged():
    assert evidence_line(_item(evidenceCount=100, truncated=True, total=130)) == "근거 기록 100건 · 전체 130건 중 일부만 담김"


def test_zero_not_truncated_has_no_line():
    assert evidence_line(_item(evidenceCount=0, truncated=None, total=None)) is None
    assert evidence_line(_item(evidenceCount=3, truncated=False, total=3)) == "근거 기록 3건"


def test_spring_shaped_body_builds_file():
    """Spring이 보내는 모양(소문자 queryType, null 섞음)으로 파일이 만들어진다."""
    pytest.importorskip("hwpx")
    from app.services.audit_export_service import export_report

    body = AuditExportInput.model_validate({
        "format": "HWPX", "reportId": 7, "title": "감사 대응 보고서", "siteName": "",
        "dateFrom": "2026-10-01", "dateTo": "2026-10-31", "createdByName": None, "summary": None,
        "items": [
            {"queryType": "corrective_action_rate", "title": "지적사항 조치율",
             "stats": {"actions": 0, "completionRate": None}, "summary": None,
             "evidenceCount": 100, "truncated": True, "total": None},
        ],
    })
    content = export_report(body)
    assert content[:2] == b"PK"
