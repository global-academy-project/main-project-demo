"""감사 대응 보고서 종합 의견 첫 문단 (모델 후보 + 규칙 가드, B).

종합 내역(`overall`)의 규칙 초안(`draft_text`) 맨 앞에 모델이 쓴 2~4문장 문단을 한 줄 얹는다.
모델은 후보만 쓰고, 채택 여부는 이 모듈의 규칙만 정한다. 실패하면 규칙 초안이 그대로 나간다
(초안은 비지 않는다). 항목별 문장(`audit_narrative*.py`)과는 별개이며 서로 부르지 않는다.

모델이 보는 것(작게 준다): 기간, 점검 범위 건수, 확인 필요 목록, 현황 참고 문장, 확인하지 못한 항목 이름, 연결 문장.
          기록 본문·법 조항·허가 번호·항목 요약 표는 주지 않는다 (입력이 길수록 CPU에서 오래 걸린다).
문단의 역할: ① 범위 ② 확인 필요 ③ 현황 참고 ④ 확인하지 못한 항목 (해당 내용이 입력에 있을 때만).
가드가 막는 것
  1. 평가어·판단·권고   위반·부적정 같은 말(narrative_guard.BANNED_WORDS)과 이 모듈의 EXTRA_BANNED_WORDS.
  2. 날짜               입력 기간 밖 ISO 날짜, '10월'·'2026년' 같은 한글 날짜 표현.
  3. 숫자               모델에 준 입력에 없는 숫자.
  4. 핵심 값 누락       확인 필요 항목의 건수, 현황 참고 문장의 첫 숫자(대상 건수)가 문단에 하나라도 빠지면 버린다.
  5. 확인하지 못한 항목  입력에 있으면 '확인하지 못함' 같은 언급이 있어야 한다.
  6. 모양               문장 수 2~4, 문장 길이 제한, 보고서체(~임/~함/~없음) 종결.
채택하면 verification에 `OVERALL_LLM_APPLIED`(INFO), 버리면 `OVERALL_LLM_REPLACED`·`OVERALL_LLM_FALLBACK`(WARN)을 남긴다.

문단을 채택하면 규칙 초안에서 문단과 겹치는 줄만 뺀다(`PRUNE_COVERED`, v3).
  뺄 줄  `확인 필요:`·`현황 참고:` 줄 가운데 줄 안의 (낱말, 숫자) 쌍이 모두 문단에도 있는 줄. 숫자만 같으면 빼지 않는다.
  둘 것  점검 기간·조회 기록 줄, 묶음별 줄, 연결 줄 (문단에 없는 정보). 구조화 필드(reviewNeeded·reference)는 그대로.

끄기: 설정 `AUDIT_OVERALL_LLM=false`(기본은 켜짐, config.py `audit_overall_llm = True`) 또는 이 모듈의 `OVERALL_LLM = False`. 끄면 응답이 변경 전과 같다.
평가어·권고어 목록과 문장 수·길이 값은 임시값이다. 안전 담당과 확정한다.
"""

from __future__ import annotations

import json
import re
from collections.abc import Callable, Sequence
from typing import Any

from app.agent import audit_narrative_guard as narrative_guard
from app.agent.audit_compose_check import fmt, numbers_in
from app.agent.evidence_collector.textutil import extract_json_object
from app.exceptions import LLMError
from app.llm.llm_base import LLMClient
from app.llm.llm_types import Message

__all__ = [
    "EXTRA_BANNED_WORDS",
    "OVERALL_LLM",
    "OverallGenerator",
    "UNAVAILABLE_PHRASES",
    "PRUNE_COVERED",
    "apply_overall",
    "build_payload",
    "check_paragraph",
    "generate_overall_candidates",
    "prune_covered_lines",
]

OVERALL_LLM = True  # False면 이 모듈은 아무것도 하지 않는다 (설정 스위치와 별개인 코드 쪽 끄기)
MAX_OUTPUT_TOKENS = 400  # 4문장 JSON이면 충분하다. 줄이면 CPU에서 생성 시간이 준다
MIN_SENTENCES = 2
MAX_SENTENCES = 4
MAX_SENTENCE_CHARS = 120
REQUIRE_REPORT_STYLE = True  # 문장이 ~임/~함/~됨/~음. 으로 끝나야 한다
PRUNE_COVERED = True  # False면 문단과 겹쳐도 규칙 초안을 그대로 둔다 (v2 동작)

# 임시값: 평가·판단·권고·막연한 정도 표현. 구성기는 기록이 어떤 상태인지만 서술한다.
EXTRA_BANNED_WORDS: tuple[str, ...] = (
    "해야", "권고", "권장", "바람직", "시급", "즉시", "양호", "우수", "철저", "소홀",
    "안전하", "대부분", "대체로", "다수", "일부", "여러", "많은", "적은",
)

# 확인하지 못한 항목을 말하는 표현 (입력에 확인 불가 항목이 있으면 이 중 하나가 문단에 있어야 한다)
UNAVAILABLE_PHRASES: tuple[str, ...] = ("확인하지 못", "조회하지 못", "확인 불가")

_STYLE_END = re.compile(r"[임함됨음]\.$")
_FACT = re.compile(r"([가-힣]+)\s*(\d[\d,]*(?:\.\d+)?)\s*(?:건|개|%)")

OverallGenerator = Callable[[dict[str, Any]], list[str]]

SYSTEM_PROMPT = """너는 감사 대응 보고서의 '종합 의견' 첫 문단을 쓰는 작성기다.
입력 JSON의 값만 사용해 서로 다른 내용의 문장 3~4개를 쓴다. 입력에 해당 내용이 있을 때만 쓴다.

문장 구성:
1. 조회한 기록 건수 (counts)
2. 확인 필요 항목 전부와 각 건수 (reviewNeeded)
3. 현황 참고 항목의 대상 건수와 처리 건수 (reference)
4. 확인하지 못한 항목 (unavailable)

규칙:
- 입력에 있는 숫자만 쓴다. 계산하거나 반올림하거나 새 숫자를 만들지 않는다.
- 평가·판단·권고를 하지 않는다. 위반, 부적정, 미흡, 양호, ~해야 한다 같은 말을 쓰지 않는다. 기록이 어떤 상태인지만 쓴다.
- 입력에 없는 날짜·기록·원인을 쓰지 않는다.
- 문장은 '~임', '~함', '~없음'으로 끝나는 보고서체로 쓰고, 한 문장은 100자 이내로 쓴다.
- 차단 건수는 승인·반려와 나란히 세지 말고, 입력의 표현 그대로 따로 쓴다.
- JSON 객체 하나만 출력한다: {"paragraph": ["문장", "문장"]}

예 (숫자와 항목은 예시일 뿐이다):
입력: {"counts": {"works": 31, "permits": 9, "correctiveActions": 5}, "reviewNeeded": [{"count": 3, "text": "위험성평가 기록이 없는 작업 3건"}], "reference": ["작업허가 9건 중 승인 7건, 반려 1건이며, 규칙 판정으로 차단된 허가는 1건임."], "unavailable": ["아차사고 접수 현황"]}
출력: {"paragraph": ["이번 점검에서 작업 31건, 작업허가 9건, 개선조치 5건의 기록을 확인함.", "기록 보완 여부를 살펴볼 항목은 위험성평가 기록이 없는 작업 3건임.", "작업허가는 9건 중 승인 7건, 반려 1건이며 규칙 판정으로 차단된 허가는 1건으로 현황 참고 항목임.", "아차사고 접수 현황은 확인하지 못함."]}
"""


def build_payload(overall: Any, summary: Any, date_from: str, date_to: str) -> dict[str, Any]:
    """모델에 줄 입력. 구성기가 이미 숫자 대조를 마친 값만, 짧게 담는다."""
    counts = overall.counts
    unavailable: list[str] = []
    for group in summary.groups:
        for row in group.rows:
            if row.state == "UNAVAILABLE" and row.area not in unavailable:
                unavailable.append(row.area)
    return {
        "period": {"from": date_from, "to": date_to},
        "counts": {
            "works": counts.works,
            "permits": counts.permits,
            "correctiveActions": counts.corrective_actions,
        },
        "reviewNeeded": [{"count": r.count, "text": r.text} for r in overall.review_needed],
        "reference": [line.text for line in overall.reference],
        "unavailable": unavailable,
        "links": [line.text for line in overall.links],
    }


def generate_overall_candidates(payload: dict[str, Any], llm: LLMClient) -> list[str]:
    """모델에게 문단 후보를 받는다. 후보만 돌려주고 채택하지 않는다."""
    response = llm.chat(
        [Message(role="user", content=json.dumps(payload, ensure_ascii=False))],
        system=SYSTEM_PROMPT,
        max_tokens=MAX_OUTPUT_TOKENS,
    )
    output = extract_json_object(response.text or "")
    if not isinstance(output, dict) or not isinstance(output.get("paragraph"), list):
        raise LLMError("종합 의견 문단 후보 응답 형식이 올바르지 않습니다.", engine="AUDIT_REPORT")
    sentences = output["paragraph"]
    if not sentences or any(not isinstance(s, str) or not s.strip() for s in sentences):
        raise LLMError("종합 의견 문단 후보가 비어 있거나 올바르지 않습니다.", engine="AUDIT_REPORT")
    return [s.strip() for s in sentences]


def _allowed_numbers(payload: dict[str, Any]) -> set[str]:
    """모델에 준 입력에 나온 숫자. 12.0처럼 쓴 값은 12도 허용한다."""
    found = set(numbers_in(json.dumps(payload, ensure_ascii=False)))
    return found | {n[:-2] for n in found if n.endswith(".0")}


def check_paragraph(
    candidates: Sequence[str], *, payload: dict[str, Any], date_from: str, date_to: str
) -> tuple[str, str] | None:
    """문제가 있으면 (verification 코드, 사유), 없으면 None. 사유에 후보 원문은 싣지 않는다."""
    if not MIN_SENTENCES <= len(candidates) <= MAX_SENTENCES:
        return "OVERALL_LLM_REPLACED", "문장 수가 맞지 않아 규칙 초안을 유지함"
    if any(not isinstance(s, str) or not s.strip() or len(s.strip()) > MAX_SENTENCE_CHARS for s in candidates):
        return "OVERALL_LLM_REPLACED", "문장 길이가 맞지 않아 규칙 초안을 유지함"
    texts = [s.strip() for s in candidates]
    joined = " ".join(texts)
    if narrative_guard.banned_words_in(joined) or any(word in joined for word in EXTRA_BANNED_WORDS):
        return "OVERALL_LLM_REPLACED", "평가·권고 표현이 있어 규칙 초안을 유지함"
    if narrative_guard.date_problems(joined, {date_from, date_to}):
        return "OVERALL_LLM_REPLACED", "입력에 없는 날짜가 있어 규칙 초안을 유지함"
    got = numbers_in(joined)
    allowed = _allowed_numbers(payload)
    if any(number not in allowed for number in got):
        return "OVERALL_LLM_REPLACED", "문장 속 숫자가 입력과 달라 규칙 초안을 유지함"
    review_required = {fmt(item["count"]) for item in payload["reviewNeeded"]}
    if review_required - set(got):
        return "OVERALL_LLM_REPLACED", "확인 필요 항목의 건수가 빠져 규칙 초안을 유지함"
    reference_required = {number for line in payload["reference"] for number in numbers_in(line)[:1]}
    if reference_required - set(got):
        return "OVERALL_LLM_REPLACED", "현황 참고 항목의 건수가 빠져 규칙 초안을 유지함"
    if payload["unavailable"] and not any(phrase in joined for phrase in UNAVAILABLE_PHRASES):
        return "OVERALL_LLM_REPLACED", "확인하지 못한 항목의 언급이 빠져 규칙 초안을 유지함"
    if REQUIRE_REPORT_STYLE and any(not _STYLE_END.search(s) for s in texts):
        return "OVERALL_LLM_REPLACED", "보고서체 종결이 아니어서 규칙 초안을 유지함"
    return None


def _fact_keys(text: str) -> set[tuple[str, str]]:
    """'작업 6건', '승인 20건', '90.9%' 같은 (낱말 앞 두 글자, 숫자) 쌍. 조사('작업허가는')가 달라도 같은 쌍으로 본다."""
    keys: set[tuple[str, str]] = set()
    for word, number in _FACT.findall(text):
        keys.add((word[:2], number.replace(",", "")))
    return keys


def prune_covered_lines(overall: Any, paragraph: str, prefixes: tuple[str, str]) -> tuple[str, int]:
    """규칙 초안에서 문단과 겹치는 `확인 필요:`·`현황 참고:` 줄만 뺀다. (남은 초안, 뺀 줄 수)를 돌려준다.

    뺄 수 있는 줄: 줄 안의 (낱말, 숫자) 쌍이 하나 이상 있고 그 쌍이 모두 문단에도 있는 줄.
    숫자만 같은 줄(다른 항목의 같은 숫자)은 빼지 않는다. 그 밖의 줄(점검 기간·묶음별·연결 줄)은 그대로 둔다.
    """
    review_prefix, reference_prefix = prefixes
    candidates = {(review_prefix + r.text).strip() for r in overall.review_needed}
    candidates |= {(reference_prefix + line.text).strip() for line in overall.reference}
    in_paragraph = _fact_keys(paragraph)
    kept: list[str] = []
    dropped = 0
    for line in overall.draft_text.split("\n"):
        keys = _fact_keys(line) if line.strip() in candidates else set()
        if keys and keys <= in_paragraph:
            dropped += 1
            continue
        kept.append(line)
    return "\n".join(kept), dropped


def apply_overall(
    overall: Any,
    summary: Any,
    *,
    generator: OverallGenerator,
    date_from: str,
    date_to: str,
    note: Callable[[str, str, str], None],
    covered_prefixes: tuple[str, str] | None = None,
) -> bool:
    """가드를 통과한 문단을 규칙 초안 맨 앞에 얹는다. 채택하면 True. 실패는 모두 규칙 초안 유지.

    covered_prefixes = (확인 필요 줄 접두어, 현황 참고 줄 접두어). 주면 문단이 같은 내용을 이미 담은 줄만 규칙 초안에서 뺀다.
    """
    if not OVERALL_LLM or not overall.draft_text:
        return False  # 초안이 꺼져 있으면(DRAFT_TEXT=False) 문단도 만들지 않는다
    if not any(row.state != "UNAVAILABLE" for group in summary.groups for row in group.rows):
        return False  # 확인한 항목이 하나도 없으면 쓸 내용이 없다
    payload = build_payload(overall, summary, date_from, date_to)
    try:
        candidates = generator(payload)
        if not isinstance(candidates, list):
            raise ValueError("후보 형식이 올바르지 않음")
    except Exception as exc:  # 모델 오류·형식 오류 모두 규칙 초안으로 계속한다
        note("OVERALL_LLM_FALLBACK", "WARN", f"종합 의견: 문단 생성 실패, 규칙 초안을 사용함 ({type(exc).__name__})")
        return False
    problem = check_paragraph(candidates, payload=payload, date_from=date_from, date_to=date_to)
    if problem is not None:
        code, reason = problem
        note(code, "WARN", f"종합 의견: {reason}")
        return False
    paragraph = " ".join(s.strip() for s in candidates)
    rest, dropped = overall.draft_text, 0
    if PRUNE_COVERED and covered_prefixes is not None:
        rest, dropped = prune_covered_lines(overall, paragraph, covered_prefixes)
    overall.draft_text = paragraph + "\n" + rest
    message = "종합 의견 첫 문단을 모델 후보로 작성함 (규칙 가드 통과)"
    if dropped:
        message += f", 문단이 같은 내용을 담은 규칙 초안 {dropped}줄은 뺌"
    note("OVERALL_LLM_APPLIED", "INFO", message)
    return True
