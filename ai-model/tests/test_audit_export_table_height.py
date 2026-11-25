"""HWPX 수치 표의 행 높이가 1mm로 저장되지 않는다 (apply_audit_export_fix_v2)."""
import io
import re
import zipfile

import pytest

pytest.importorskip("hwpx")

from app.schemas.audit_export import AuditExportInput
from app.services.audit_export_service import export_report


def _section(stats_list):
    body = AuditExportInput.model_validate({
        "format": "HWPX", "reportId": 9, "title": "감사 대응 보고서", "siteName": "공장",
        "dateFrom": "2026-10-01", "dateTo": "2026-10-31", "createdByName": "관리자", "summary": None,
        "items": [{"queryType": "q", "title": f"항목 {i}", "stats": s, "summary": "요약"} for i, s in enumerate(stats_list)],
    })
    with zipfile.ZipFile(io.BytesIO(export_report(body))) as z:
        return z.read("Contents/section0.xml").decode("utf-8")


def _tables(xml):
    return re.findall(r"<hp:tbl .*?</hp:tbl>", xml, flags=re.S)


def test_stat_rows_are_not_squashed():
    xml = _section([
        {"works": 48, "written": 42, "approved": 38, "missing": 6, "rate": 87.5, "approvedRate": 79.2},
        # 8개 → 7칸씩 두 줄(4행)
        {"permits": 24, "requested": 24, "approved": 20, "rejected": 2, "canceled": 1, "blocked": 4, "approvalRate": 90.9, "count": 1},
    ])
    tables = _tables(xml)
    stat_tables = tables[1:]  # 첫 표는 빈 종합 의견 칸
    assert len(stat_tables) == 2
    for table in stat_tables:
        heights = [int(h) for h in re.findall(r'<hp:cellSz width="\d+" height="(\d+)"', table)]
        assert heights and min(heights) >= 2000
    rows = [int(r) for r in re.findall(r'rowCnt="(\d+)"', stat_tables[1])]
    assert rows == [4]


def test_blank_opinion_box_unchanged():
    tables = _tables(_section([{"count": 1}]))
    heights = {int(h) for h in re.findall(r'<hp:cellSz width="\d+" height="(\d+)"', tables[0])}
    assert heights == {5000}
