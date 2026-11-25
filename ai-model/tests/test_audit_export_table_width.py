"""HWPX 수치 표 너비: 칸 수 × (본문 너비 ÷ 7). 1칸 표가 본문 전체로 늘어나지 않는다 (apply_audit_export_fix_v3)."""
import io
import re
import zipfile

import pytest

pytest.importorskip("hwpx")

from app.agent.audit_export_hwpx import _COLUMNS_PER_ROW, _CONTENT_WIDTH
from app.schemas.audit_export import AuditExportInput
from app.services.audit_export_service import export_report

COLUMN = _CONTENT_WIDTH // _COLUMNS_PER_ROW


def _stat_tables(stats_list):
    body = AuditExportInput.model_validate({
        "format": "HWPX", "reportId": 9, "title": "감사 대응 보고서", "siteName": "공장",
        "dateFrom": "2026-10-01", "dateTo": "2026-10-31", "createdByName": "관리자", "summary": "의견",
        "items": [{"queryType": "q", "title": f"항목 {i}", "stats": s, "summary": "요약"} for i, s in enumerate(stats_list)],
    })
    with zipfile.ZipFile(io.BytesIO(export_report(body))) as z:
        xml = z.read("Contents/section0.xml").decode("utf-8")
    return re.findall(r"<hp:tbl .*?</hp:tbl>", xml, flags=re.S)  # 종합 의견이 있으면 빈 칸 표가 없다


def _table_width(table):
    return int(re.search(r'<hp:sz width="(\d+)"', table).group(1))


def _cell_widths(table):
    return [int(w) for w in re.findall(r'<hp:cellSz width="(\d+)"', table)]


def test_one_column_table_is_narrow():
    (table,) = _stat_tables([{"count": 4}])
    assert _table_width(table) == COLUMN
    assert set(_cell_widths(table)) == {COLUMN}


def test_widths_follow_column_count():
    six = {"works": 48, "written": 42, "approved": 38, "missing": 6, "rate": 87.5, "approvedRate": 79.2}
    eight = {"permits": 24, "requested": 24, "approved": 20, "rejected": 2, "canceled": 1, "blocked": 4, "approvalRate": 90.9, "count": 1}
    t6, t8 = _stat_tables([six, eight])
    assert _table_width(t6) == 6 * COLUMN
    assert set(_cell_widths(t6)) == {COLUMN}
    # 8개는 7칸씩 두 줄: 본문 전체 너비(전과 같음)
    assert _table_width(t8) == _COLUMNS_PER_ROW * COLUMN == _CONTENT_WIDTH
    assert set(_cell_widths(t8)) == {COLUMN}
