"""종합 의견 첫 문단을 실제 모델로 시험한다 (서버·Spring·DB 없이). 모델이 JSON을 제대로 내는지, 가드가 얼마나 채택하는지 본다.

  python scripts/try_audit_overall_llm.py                 샘플(2026-10 더미 기대값)로 1회
  python scripts/try_audit_overall_llm.py --runs 5        같은 입력으로 5회 (채택 횟수 확인)
  python scripts/try_audit_overall_llm.py --input 파일.json   요청 본문 JSON(camelCase)을 직접 지정
  python scripts/try_audit_overall_llm.py --show-payload  모델에 준 입력도 출력

저장소 루트(app 폴더가 있는 곳)에서 실행한다. .env의 모델 설정(SCENARIO_ENGINES 등)을 그대로 쓴다.
모델 원문 출력·걸린 시간·가드 결과를 보여 준다. 키·토큰은 출력하지 않는다.
"""
from __future__ import annotations

import argparse
import json
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

SAMPLE = {
    "reportId": 2, "siteId": 1, "dateFrom": "2026-10-01", "dateTo": "2026-10-31",
    "items": [
        {"queryType": "risk_assessment_rate", "title": "위험성평가 실시율",
         "stats": {"works": 48, "written": 42, "approved": 38, "missing": 6, "rate": 87.5, "approvedRate": 79.2}},
        {"queryType": "permit_approval_statistics", "title": "허가 승인 현황",
         "stats": {"permits": 24, "requested": 24, "approved": 20, "rejected": 2, "canceled": 1, "blocked": 4, "approvalRate": 90.9}},
        {"queryType": "missing_measurements", "title": "측정값 없이 승인된 허가", "stats": {"count": 2},
         "records": [{"permitId": 11, "permitNo": "P-901", "permitType": "HOT_WORK", "missingItems": ["a"]},
                     {"permitId": 12, "permitNo": "P-902", "permitType": "HOT_WORK", "missingItems": ["a", "b"]}],
         "evidence": [{"type": "PERMIT", "id": 11}, {"type": "PERMIT", "id": 12}]},
        {"queryType": "blocked_records", "title": "차단 기록", "stats": {"count": 4},
         "records": [{"permitId": 11, "evaluationId": 5}, {"permitId": 13, "evaluationId": 6},
                     {"permitId": 14, "evaluationId": 7}, {"permitId": 15, "evaluationId": 8}],
         "evidence": [{"type": "PERMIT", "id": 11}]},
        {"queryType": "corrective_action_rate", "title": "지적사항 조치율",
         "stats": {"actions": 12, "completed": 7, "verified": 3, "open": 5, "overdue": 3, "completionRate": 58.3}},
    ],
}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--runs", type=int, default=1)
    parser.add_argument("--input", help="요청 본문 JSON 파일")
    parser.add_argument("--show-payload", action="store_true")
    args = parser.parse_args()

    from app.agent import audit_overall_llm as overall_llm
    from app.agent.audit_compose import compose_audit_report
    from app.core import get_settings
    from app.llm.llm_provider import LLMClientProvider
    from app.schemas.audit_compose import AuditComposeInput
    from app.services.audit_compose_service import AUDIT_NARRATIVE_SCENARIO

    raw_body = json.loads(Path(args.input).read_text(encoding="utf-8")) if args.input else SAMPLE
    body = AuditComposeInput.model_validate(raw_body)
    llm = LLMClientProvider.from_settings(get_settings()).get(AUDIT_NARRATIVE_SCENARIO)
    print(f"모델 엔진: {getattr(llm, 'name', type(llm).__name__)}  (시나리오 {AUDIT_NARRATIVE_SCENARIO})")
    print(f"프롬프트 {len(overall_llm.SYSTEM_PROMPT)}자, 최대 출력 {overall_llm.MAX_OUTPUT_TOKENS}토큰")

    rule_only = compose_audit_report(body).overall.draft_text
    adopted = 0
    for number in range(1, args.runs + 1):
        seen: dict[str, object] = {}

        def generator(payload):
            size = len(json.dumps(payload, ensure_ascii=False))
            if args.show_payload:
                print(f"  [모델 입력 {size}자]", json.dumps(payload, ensure_ascii=False))
            seen["payload_chars"] = size
            started = time.monotonic()
            try:
                return overall_llm.generate_overall_candidates(payload, _Recorder(llm, seen))
            finally:
                seen["seconds"] = time.monotonic() - started

        result = compose_audit_report(body, overall_generator=generator)
        codes = [v for v in result.verification if v.code.startswith("OVERALL_LLM")]
        ok = any(v.code == "OVERALL_LLM_APPLIED" for v in codes)
        adopted += ok
        usage = seen.get("usage")
        tokens = f" · 입력 {usage.input_tokens}토큰/출력 {usage.output_tokens}토큰" if usage and (usage.input_tokens or usage.output_tokens) else ""
        print(f"\n=== {number}회 · {'채택' if ok else '규칙 초안 유지'} · 모델 {seen.get('seconds', 0):.1f}초{tokens} ===")
        if "raw" in seen:
            print(f"[모델 입력 {seen.get('payload_chars', 0)}자] [모델 원문]", str(seen["raw"]).strip()[:800])
        for v in codes:
            print(f"[{v.level}] {v.code}: {v.message}")
        print("[종합 의견 첫 줄]", result.overall.draft_text.splitlines()[0])
    print(f"\n채택 {adopted}/{args.runs}회. 규칙 초안은 {len(rule_only.splitlines())}줄이며 항상 그대로 뒤에 붙는다.")
    return 0


class _Recorder:
    """모델 원문을 기록하는 얇은 감싸개 (chat만 전달)."""

    def __init__(self, llm, seen):
        self._llm, self._seen = llm, seen

    def chat(self, *args, **kwargs):
        response = self._llm.chat(*args, **kwargs)
        self._seen["raw"] = response.text
        self._seen["usage"] = getattr(response, "usage", None)
        return response


if __name__ == "__main__":
    sys.exit(main())
