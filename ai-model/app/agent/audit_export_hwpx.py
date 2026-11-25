"""감사 대응 보고서를 한글(HWPX) 문서로 만든다 (B). 계산 계층: FastAPI·DB·LLM을 모른다.

화면의 "인쇄·PDF 저장"(React `audit-reports.css` 인쇄 블록)과 같은 내용·순서로 만든다.
  제목 → 현장·기간·만든 사람 → 종합 의견(비어 있으면 빈 칸) → 항목마다 [이름, 수치 표, 요약, 근거 기록 줄]
항목의 "근거 기록 0건" 줄은 인쇄처럼 뺀다(0건이면서 일부만 담긴 것도 아닐 때).

`python-hwpx`는 함수 안에서 불러온다. 설치되지 않아도 서버는 기동하고, 이 기능만 `HwpxUnavailableError`가 된다.
숫자·문장은 받은 값 그대로다. 라벨(한글 이름)만 붙인다. 모르는 수치 이름은 건너뛴다(화면에 영어 코드를 보이지 않기 위해).
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from app.schemas.audit_export import AuditExportInput, AuditExportItem

__all__ = [
    "HWPX_MEDIA_TYPE",
    "HwpxBuildError",
    "HwpxUnavailableError",
    "STAT_LABELS",
    "build_audit_hwpx",
    "clean_text",
    "evidence_line",
    "stat_pairs",
]

HWPX_MEDIA_TYPE = "application/hwp+zip"

# React `utils/audit-report-model.js` 의 STAT_LABELS 와 같은 표다. 둘 중 하나를 바꾸면 같이 바꾼다.
STAT_LABELS: dict[str, str] = {
    "count": "건수",
    "works": "작업", "written": "평가 작성", "approved": "승인", "missing": "미작성", "rate": "실시율", "approvedRate": "승인율",
    "permits": "허가", "requested": "승인 요청", "rejected": "반려", "canceled": "취소", "blocked": "차단", "approvalRate": "승인률",
    "actions": "조치", "completed": "완료", "verified": "확인 완료", "open": "미완료", "overdue": "기한 지남", "completionRate": "조치율",
}

# A4(210 x 297mm), 화면 인쇄(@page audit-report)와 같은 여백
_MARGIN_LR_MM = 14
_MARGIN_TB_MM = 15
_CONTENT_WIDTH = 51590  # (210 - 14 - 14)mm 를 HWPUNIT(1mm = 7200/25.4)로
_BLANK_BOX_HEIGHT = 5000  # 빈 종합 의견 칸 높이(약 17.6mm, 인쇄의 5em)
_COLUMNS_PER_ROW = 7
# 수치 표 한 행 높이(HWPUNIT, 약 7mm). 정하지 않으면 1mm로 저장돼 한글에서 표가 눌린다.
_STAT_ROW_HEIGHT = 2000

# XML 1.0 에 쓸 수 없는 제어 문자
_CONTROL = re.compile(r"[\x00-\x08\x0b\x0c\x0e-\x1f\ufffe\uffff]")


class HwpxUnavailableError(RuntimeError):
    """python-hwpx 가 설치되어 있지 않다 (환경 문제)."""


class HwpxBuildError(RuntimeError):
    """문서를 만들거나 검증하지 못했다."""


def clean_text(value: str | None) -> str:
    """제어 문자를 지우고 줄바꿈을 \\n 으로 맞춘다."""
    if not value:
        return ""
    return _CONTROL.sub("", value.replace("\r\n", "\n").replace("\r", "\n"))


def stat_pairs(stats: dict[str, Any]) -> list[tuple[str, str]]:
    """[(한글 이름, 표시값)]. 모르는 이름·숫자가 아닌 값은 건너뛴다. 비율은 %, 값이 없으면 -."""
    pairs: list[tuple[str, str]] = []
    for key, value in stats.items():
        label = STAT_LABELS.get(key)
        if label is None:
            continue
        if value is None or value == "":
            pairs.append((label, "-"))
        elif isinstance(value, (dict, list)):
            continue
        elif key.lower().endswith("rate"):
            pairs.append((label, f"{value}%"))
        else:
            pairs.append((label, str(value)))
    return pairs


def evidence_line(item: AuditExportItem) -> str | None:
    """인쇄처럼 근거 기록이 0건이고 일부만 담긴 것도 아니면 줄을 만들지 않는다."""
    count = item.evidence_total()
    if count == 0 and not item.truncated:
        return None
    line = f"근거 기록 {count}건"
    if item.truncated:
        # total 이 없으면(null) 건수를 쓰지 않는다 ("전체 None건" 방지)
        line += f" · 전체 {item.total}건 중 일부만 담김" if item.total is not None else " · 일부만 담김"
    return line


def _lines(text: str | None) -> list[str]:
    """줄 단위로 나눈다. 앞뒤의 빈 줄은 버리고, 공백뿐이면 줄이 없다."""
    value = clean_text(text)
    return value.strip("\n").split("\n") if value.strip() else []


def _paragraphs(doc: Any, text: str | None, char: str) -> None:
    for line in _lines(text):
        doc.add_paragraph(line, char_pr_id_ref=char)


def _blank_box(doc: Any, char: str) -> None:
    table = doc.add_table(1, 1, width=_CONTENT_WIDTH, char_pr_id_ref=char)
    table.set_borders(border_width_mm=0.12, color="#999999")
    table.set_row_height(0, _BLANK_BOX_HEIGHT)


def _stats_table(doc: Any, pairs: list[tuple[str, str]], small: str, strong: str) -> None:
    chunks = [pairs[i:i + _COLUMNS_PER_ROW] for i in range(0, len(pairs), _COLUMNS_PER_ROW)]
    columns = min(len(pairs), _COLUMNS_PER_ROW)
    # 칸 너비는 본문 너비 ÷ 7 로 고정한다. 칸이 적은 표(건수 하나 등)가 본문 너비 전체로 늘어나지 않게.
    table = doc.add_table(2 * len(chunks), columns, width=columns * (_CONTENT_WIDTH // _COLUMNS_PER_ROW), char_pr_id_ref=small)
    for index, chunk in enumerate(chunks):
        for col, (label, value) in enumerate(chunk):
            table.set_cell_text(2 * index, col, label)
            table.set_cell_text(2 * index + 1, col, value)
            for paragraph in table.cell(2 * index, col).paragraphs:
                paragraph.char_pr_id_ref = small
            for paragraph in table.cell(2 * index + 1, col).paragraphs:
                paragraph.char_pr_id_ref = strong
    table.set_borders(border_width_mm=0.12, color="#999999")
    table.set_column_widths([1] * columns)
    table.set_row_heights([_STAT_ROW_HEIGHT] * table.row_count)


def build_audit_hwpx(report: AuditExportInput, *, now: datetime | None = None) -> bytes:
    """보고서 한 건을 HWPX 파일 바이트로 만든다. `now`를 주면 같은 입력에서 같은 바이트가 나온다(시험용)."""
    try:
        from hwpx import HwpxDocument
    except ImportError as exc:
        raise HwpxUnavailableError("python-hwpx 가 설치되어 있지 않습니다.") from exc

    try:
        doc = HwpxDocument.new(seed=report.report_id, now=now)
        doc.page.setup(
            paper_size="A4",
            margin_left_mm=_MARGIN_LR_MM,
            margin_right_mm=_MARGIN_LR_MM,
            margin_top_mm=_MARGIN_TB_MM,
            margin_bottom_mm=_MARGIN_TB_MM,
        )
        styles = doc.styles
        title_run = styles.ensure_run(bold=True, size=18)
        heading_run = styles.ensure_run(bold=True, size=13)
        label_run = styles.ensure_run(bold=True, size=11)
        muted_run = styles.ensure_run(size=9, color="#444444")
        body_run = styles.ensure_run(size=10)
        strong_run = styles.ensure_run(bold=True, size=10)

        title = clean_text(report.title).strip() or f"감사 대응 보고서 #{report.report_id}"
        meta = " · ".join(
            part for part in (
                clean_text(report.site_name).strip(),
                f"{report.date_from} ~ {report.date_to}",
                f"만든 사람 {clean_text(report.created_by_name).strip() or '-'}",
            ) if part
        )
        doc.add_paragraph(title, char_pr_id_ref=title_run)
        doc.add_paragraph(meta, char_pr_id_ref=muted_run)
        doc.add_paragraph("", char_pr_id_ref=body_run)

        doc.add_paragraph("종합 의견", char_pr_id_ref=label_run)
        if _lines(report.summary):
            _paragraphs(doc, report.summary, body_run)
        else:
            _blank_box(doc, body_run)
        doc.add_paragraph("", char_pr_id_ref=body_run)

        for item in report.items:
            doc.add_paragraph(clean_text(item.title).strip() or clean_text(item.query_type), char_pr_id_ref=heading_run)
            pairs = stat_pairs(item.stats)
            if pairs:
                _stats_table(doc, pairs, muted_run, strong_run)
            doc.add_paragraph("요약", char_pr_id_ref=label_run)
            _paragraphs(doc, item.summary, body_run)
            line = evidence_line(item)
            if line:
                doc.add_paragraph(line, char_pr_id_ref=muted_run)
            doc.add_paragraph("", char_pr_id_ref=body_run)

        doc.parts.set_document_metadata(title=title, creator=clean_text(report.created_by_name).strip() or None)
        result = doc.validate()
        if result.issues:
            raise HwpxBuildError("만든 문서가 HWPX 검증을 통과하지 못했습니다.")
        return doc.to_bytes()
    except (HwpxBuildError, HwpxUnavailableError):
        raise
    except Exception as exc:  # 라이브러리 내부 오류. 원문은 로그에서만 본다(서비스가 남김).
        raise HwpxBuildError(f"HWPX 문서를 만들지 못했습니다 ({type(exc).__name__}).") from exc
