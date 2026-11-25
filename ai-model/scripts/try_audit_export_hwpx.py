"""감사 대응 보고서 HWPX 만들기 확인 (서버 없이 변환기만 실행). B.

사용: python scripts/try_audit_export_hwpx.py [--input 요청.json] [--out 파일.hwpx]
  --input  Spring이 보낼 요청 본문(JSON, camelCase). 없으면 2026-10 더미 데이터 모양의 예시를 쓴다.
  --out    저장할 파일 (기본 audit-report-sample.hwpx)
저장한 파일을 한글(또는 HWPX를 여는 뷰어)로 열어 PDF와 비교한다. 만든 시간과 크기를 출력한다.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

SAMPLE = {
    "reportId": 6,
    "title": "감사 대응 보고서 2026-10-01 ~ 2026-10-31",
    "siteName": "시연 현장",
    "dateFrom": "2026-10-01",
    "dateTo": "2026-10-31",
    "createdByName": "관리자",
    "summary": None,
    "items": [
        {
            "queryType": "RISK_ASSESSMENT_RATE", "title": "위험성평가 실시율",
            "stats": {"works": 48, "written": 42, "approved": 38, "missing": 6, "rate": 87.5, "approvedRate": 79.2},
            "summary": "위험성평가는 산업안전보건법 제36조에 따른 법정 의무 사항으로, 작업별 작성·승인 기록을 확인함.\n"
                       "해당 기간 작업 48건 중 위험성평가를 작성한 작업은 42건(87.5%), 승인된 작업은 38건(79.2%)임.\n"
                       "위험성평가 기록이 없는 작업은 6건임.",
            "evidenceCount": 0,
        },
        {
            "queryType": "PERMIT_APPROVAL", "title": "작업허가 승인 현황",
            "stats": {"permits": 24, "requested": 24, "approved": 20, "rejected": 2, "canceled": 1, "blocked": 4, "approvalRate": 90.9},
            "summary": "작업허가는 사내 절차로, 승인 요청·승인·반려·차단 기록을 확인함.\n"
                       "해당 기간 작업허가 24건에 대한 승인 요청은 24건이며, 승인 20건, 반려 2건, 취소 1건임.\n"
                       "승인률(승인÷(승인+반려))은 90.9%임.\n규칙 판정으로 차단된 허가는 4건임.",
            "evidenceCount": 0,
        },
        {
            "queryType": "CORRECTIVE_RATE", "title": "지적사항 조치율",
            "stats": {"actions": 12, "completed": 7, "verified": 5, "open": 5, "overdue": 3, "completionRate": 58.3},
            "summary": "개선조치 이행은 사내 절차로, 등록된 조치의 완료·검증 현황을 확인함.\n"
                       "해당 기간 등록된 개선조치(취소 제외) 12건 중 완료(검증 포함) 7건(58.3%), 검증 완료 5건임.\n"
                       "미완료 개선조치는 5건이며 이 중 기한이 지난 조치는 3건임.",
            "evidenceCount": 12,
        },
    ],
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input")
    parser.add_argument("--out", default="audit-report-sample.hwpx")
    args = parser.parse_args()

    from app.agent.audit_export_hwpx import HwpxUnavailableError
    from app.schemas.audit_export import AuditExportInput
    from app.services.audit_export_service import export_report

    raw = json.loads(Path(args.input).read_text(encoding="utf-8")) if args.input else SAMPLE
    body = AuditExportInput.model_validate(raw)
    started = time.perf_counter()
    try:
        data = export_report(body)
    except Exception as exc:  # BusinessError 등: 원인 종류만 보인다
        print(f"실패: {type(exc).__name__}: {getattr(exc, 'message', exc)}")
        return 1
    elapsed = (time.perf_counter() - started) * 1000
    Path(args.out).write_bytes(data)
    print(f"만들었습니다: {args.out} ({len(data):,} bytes, {elapsed:.0f} ms)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
