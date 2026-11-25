"""감사 대응 보고서 HWPX 내려받기 (audit_export_hwpx_v1) 시험.

python-hwpx 가 있어야 만들기 시험이 돈다(없으면 건너뜀). 설치 안 된 환경의 동작은 따로 시험한다.
주소 등록 시험은 main.py·config.py 에 패치(apply_audit_export_hwpx_v1.py)가 적용된 상태를 전제로 한다.
"""

from __future__ import annotations

import datetime
import io
import sys
import zipfile

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.agent.audit_export_hwpx import (
    HWPX_MEDIA_TYPE,
    HwpxUnavailableError,
    build_audit_hwpx,
    clean_text,
    evidence_line,
    stat_pairs,
)
from app.api.v1.agent.audit_export import router
from app.exceptions import BusinessError
from app.handlers import business_error_handler
from app.schemas.audit_export import AuditExportInput, AuditExportItem

hwpx = pytest.importorskip("hwpx", reason="python-hwpx 가 설치되어 있어야 한다")

NOW = datetime.datetime(2026, 11, 22, 16, 0, 0)


def sample(**overrides):
    body = {
        "reportId": 6,
        "title": "감사 대응 보고서 2026-10-01 ~ 2026-10-31",
        "siteName": "현장 A",
        "dateFrom": "2026-10-01",
        "dateTo": "2026-10-31",
        "createdByName": "관리자",
        "summary": "종합 의견 첫 줄\n둘째 줄",
        "items": [
            {
                "queryType": "RISK", "title": "위험성평가 실시율",
                "stats": {"works": 48, "written": 42, "approved": 38, "missing": 6, "rate": 87.5, "approvedRate": 79.2},
                "summary": "작업 48건 중 42건(87.5%)임.\n미작성은 6건임.", "evidence": [],
            },
            {
                "queryType": "PERMIT", "title": "작업허가 승인 현황",
                "stats": {"permits": 24, "approved": 20, "approvalRate": 90.9},
                "summary": "허가 24건임.", "evidenceCount": 12, "truncated": True, "total": 30,
            },
        ],
    }
    body.update(overrides)
    return AuditExportInput.model_validate(body)


def build(**overrides):
    return build_audit_hwpx(sample(**overrides), now=NOW)



def _open(data: bytes):
    import tempfile
    import os
    with tempfile.NamedTemporaryFile(suffix=".hwpx", delete=False) as handle:
        handle.write(data)
        name = handle.name
    try:
        return hwpx.HwpxDocument.open(name)
    finally:
        os.unlink(name)


def tables(doc):
    return [[[t.cell(r, c).text for c in range(t.column_count)] for r in range(t.row_count)] for t in doc.tables]


# ---------------------------------------------------------------- 수치·근거 줄


def test_stat_pairs_labels_order_percent_and_skips():
    pairs = stat_pairs({"works": 48, "rate": 87.5, "approvalRate": None, "missing": "", "junk": 1, "nested": {"a": 1}, "completionRate": 58.3})
    assert pairs == [("작업", "48"), ("실시율", "87.5%"), ("승인률", "-"), ("미작성", "-"), ("조치율", "58.3%")]


def test_stat_pairs_zero_is_zero_not_missing():
    assert stat_pairs({"blocked": 0, "rate": 0}) == [("차단", "0"), ("실시율", "0%")]


@pytest.mark.parametrize(
    ("item", "expected"),
    [
        ({}, None),
        ({"evidence": []}, None),
        ({"evidenceCount": 0, "truncated": False}, None),
        ({"evidenceCount": 3}, "근거 기록 3건"),
        ({"evidence": [{}, {}]}, "근거 기록 2건"),
        ({"evidenceCount": 0, "truncated": True, "total": 40}, "근거 기록 0건 · 전체 40건 중 일부만 담김"),
        ({"evidenceCount": 12, "truncated": True, "total": 30}, "근거 기록 12건 · 전체 30건 중 일부만 담김"),
        ({"evidenceCount": 2, "evidence": [{}]}, "근거 기록 2건"),
    ],
)
def test_evidence_line_follows_print_rule(item, expected):
    assert evidence_line(AuditExportItem.model_validate(item)) == expected


def test_clean_text_removes_control_chars_and_normalizes_newlines():
    assert clean_text("a\x00b\x07c\r\nd\re\tf") == "abc\nd\ne\tf"
    assert clean_text("a\x0bb\x0cc\x1fd\ufffee\uffff f") == "abcde f"
    assert clean_text("한\x08글\x0e") == "한글"
    assert clean_text(None) == ""


# ---------------------------------------------------------------- 문서 만들기


def test_file_is_hwpx_zip_with_stored_mimetype_first():
    data = build()
    archive = zipfile.ZipFile(io.BytesIO(data))
    first = archive.infolist()[0]
    assert first.filename == "mimetype" and first.compress_type == zipfile.ZIP_STORED
    assert archive.read("mimetype") == b"application/hwp+zip"
    assert {"Contents/header.xml", "Contents/section0.xml"} <= set(archive.namelist())


def test_content_order_matches_print_layout():
    doc = _open(build())
    texts = [p.text for p in doc.paragraphs if p.text]
    assert texts == [
        "감사 대응 보고서 2026-10-01 ~ 2026-10-31",
        "현장 A · 2026-10-01 ~ 2026-10-31 · 만든 사람 관리자",
        "종합 의견",
        "종합 의견 첫 줄",
        "둘째 줄",
        "위험성평가 실시율",
        "요약",
        "작업 48건 중 42건(87.5%)임.",
        "미작성은 6건임.",
        "작업허가 승인 현황",
        "요약",
        "허가 24건임.",
        "근거 기록 12건 · 전체 30건 중 일부만 담김",
    ]


def test_stat_tables_have_label_and_value_rows():
    assert tables(_open(build())) == [
        [["작업", "평가 작성", "승인", "미작성", "실시율", "승인율"], ["48", "42", "38", "6", "87.5%", "79.2%"]],
        [["허가", "승인", "승인률"], ["24", "20", "90.9%"]],
    ]


def test_zero_evidence_line_is_left_out():
    texts = [p.text for p in _open(build()).paragraphs]
    assert "근거 기록 0건" not in texts


def test_empty_summary_prints_blank_box():
    doc = _open(build(summary=None))
    assert tables(doc)[0] == [[""]]
    assert len(doc.tables) == 3
    doc2 = _open(build(summary="   \n "))
    assert tables(doc2)[0] == [[""]]
    # 종합 의견이 있으면 빈 칸은 없다
    assert len(_open(build()).tables) == 2


def test_missing_creator_and_site_are_handled():
    texts = [p.text for p in _open(build(createdByName=None, siteName="")).paragraphs if p.text]
    assert texts[1] == "2026-10-01 ~ 2026-10-31 · 만든 사람 -"


def test_blank_title_uses_report_number():
    texts = [p.text for p in _open(build(title="  ")).paragraphs if p.text]
    assert texts[0] == "감사 대응 보고서 #6"


def test_special_characters_are_escaped_and_controls_removed():
    data = build(summary="<법정> & \"의무\" '임'\x07끝")
    xml = zipfile.ZipFile(io.BytesIO(data)).read("Contents/section0.xml").decode("utf-8")
    assert "&lt;법정&gt; &amp;" in xml
    assert "\x07" not in xml
    assert any("<법정> & \"의무\" '임'끝" == p.text for p in _open(data).paragraphs)
    assert "끝" in xml


def test_many_stats_wrap_into_rows_of_seven():
    stats = {k: i for i, k in enumerate(["count", "works", "written", "approved", "missing", "rate", "approvedRate", "permits", "requested"], 1)}
    body = sample()
    body.items[0].stats = stats
    doc = _open(build_audit_hwpx(body, now=NOW))
    first = tables(doc)[0]
    assert len(first) == 4 and len(first[0]) == 7
    assert first[0][:2] == ["건수", "작업"] and first[2][:2] == ["허가", "승인 요청"]


def test_unknown_stats_only_item_has_no_table_but_keeps_text():
    body = sample()
    body.items[1].stats = {"junk": 1}
    doc = _open(build_audit_hwpx(body, now=NOW))
    assert len(doc.tables) == 1
    assert "허가 24건임." in [p.text for p in doc.paragraphs]


def test_same_input_gives_same_bytes():
    assert build() == build()


def test_library_missing_is_a_typed_error(monkeypatch):
    monkeypatch.setitem(sys.modules, "hwpx", None)
    with pytest.raises(HwpxUnavailableError):
        build()


# ---------------------------------------------------------------- 요청 검증


@pytest.mark.parametrize(
    "override",
    [
        {"dateFrom": "2026-10-32"},
        {"dateFrom": "2026-11-01", "dateTo": "2026-10-01"},
        {"items": []},
        {"reportId": 0},
        {"format": "PDF"},
        {"summary": "가" * 20_001},
    ],
)
def test_invalid_requests_are_rejected(override):
    with pytest.raises(Exception):
        sample(**override)


def test_unknown_fields_are_ignored():
    body = sample(lockVersion=3, statusLabel="검토 필요")
    assert body.report_id == 6


# ---------------------------------------------------------------- 라우터


def make_client():
    app = FastAPI()
    app.add_exception_handler(BusinessError, business_error_handler)
    app.include_router(router)
    return TestClient(app, raise_server_exceptions=False)


def payload():
    return sample().model_dump(by_alias=True, mode="json")


def test_route_returns_file_not_json_envelope():
    response = make_client().post("/api/v1/agent/audit-report/export", json=payload())
    assert response.status_code == 200
    assert response.headers["content-type"] == HWPX_MEDIA_TYPE
    assert response.content[:2] == b"PK"
    disposition = response.headers["content-disposition"]
    assert disposition.startswith("attachment;") and "filename*=UTF-8''" in disposition
    assert ".hwpx" in disposition


def test_route_filename_is_safe_for_header():
    body = payload()
    body["title"] = '보고서/2026:10 "시험"\n줄바꿈'
    disposition = make_client().post("/api/v1/agent/audit-report/export", json=body).headers["content-disposition"]
    assert "\n" not in disposition and "/" not in disposition.split("filename*=")[1]


def test_route_validation_error_uses_error_envelope():
    body = payload()
    body["dateFrom"] = "bad"
    response = make_client().post("/api/v1/agent/audit-report/export", json=body)
    assert response.status_code == 422


def test_route_503_when_library_is_missing(monkeypatch):
    monkeypatch.setitem(sys.modules, "hwpx", None)
    response = make_client().post("/api/v1/agent/audit-report/export", json=payload())
    assert response.status_code == 503
    assert response.json()["success"] is False
    assert response.json()["error"]["code"] == "SERVICE_UNAVAILABLE"


def test_route_502_when_build_fails(monkeypatch):
    from app.agent.audit_export_hwpx import HwpxBuildError
    import app.services.audit_export_service as service

    def boom(body, *, now=None):
        raise HwpxBuildError("내부 원문 (비밀)")

    monkeypatch.setattr(service, "build_audit_hwpx", boom)
    response = make_client().post("/api/v1/agent/audit-report/export", json=payload())
    assert response.status_code == 502
    assert response.json()["error"]["code"] == "BAD_GATEWAY"
    assert "비밀" not in response.text


# ---------------------------------------------------------------- 등록·스위치 (패치 적용 상태)


def _env(monkeypatch, **extra):
    from app.core import get_settings
    monkeypatch.setenv("CHECK_RULES_TOOL", "MOCK")
    monkeypatch.setenv("MSDS_TOOL", "MOCK")
    monkeypatch.setenv("LLM_PRELOAD", "false")
    monkeypatch.setenv("SCENARIO_ENGINES", '{"default": {"engine": "FAKE"}}')
    for key, value in extra.items():
        monkeypatch.setenv(key, value)
    get_settings.cache_clear()
    return get_settings


def test_route_is_registered_by_default(monkeypatch):
    get_settings = _env(monkeypatch)
    from app.main import create_app
    try:
        paths = set(create_app().openapi()["paths"])
        assert "/api/v1/agent/audit-report/export" in paths
        assert "/api/v1/agent/audit-report" in paths  # 기존 구성기 주소는 그대로
    finally:
        get_settings.cache_clear()


def test_switch_off_removes_only_the_new_route(monkeypatch):
    get_settings = _env(monkeypatch, AUDIT_EXPORT_HWPX="false")
    from app.main import create_app
    try:
        paths = set(create_app().openapi()["paths"])
        assert "/api/v1/agent/audit-report/export" not in paths
        assert "/api/v1/agent/audit-report" in paths
    finally:
        get_settings.cache_clear()
