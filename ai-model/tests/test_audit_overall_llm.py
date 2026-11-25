"""종합 의견 첫 문단 LLM(audit_overall_llm) 시험. 실제 모델 없이 가짜 모델로 규칙 가드와 연결을 확인한다."""

from __future__ import annotations

import ast
import copy
import json
import re
from pathlib import Path

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.agent import audit_overall_llm as overall_llm
from app.agent.audit_compose import compose_audit_report
from app.core import get_settings
from app.exceptions import LLMError
from app.llm.llm_base import LLMClient
from app.llm.llm_types import LLMResponse
from app.schemas.audit_compose import AuditComposeInput
from app.services import audit_compose_service as service

BODY = {
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

GOOD = [
    "점검 기간 중 작업 48건, 작업허가 24건, 개선조치 12건을 조회함.",
    "확인 필요 항목은 위험성평가 기록이 없는 작업 6건, 측정값 없이 승인된 허가 2건, 기한이 지난 개선조치 3건임.",
    "작업허가는 24건 중 승인 20건, 반려 2건, 차단 4건이며 규칙 차단 기록 4건과 함께 현황 참고 항목임.",
    "아차사고 접수 현황과 조치 연결 현황은 조회하지 못해 확인하지 못함.",
]


def body(**over):
    data = copy.deepcopy(BODY)
    data.update(over)
    return AuditComposeInput.model_validate(data)


class Gen:
    """가짜 생성기: 받은 입력을 기록하고 정해 둔 후보를 돌려준다."""

    def __init__(self, candidates=None, error: Exception | None = None):
        self.candidates, self.error, self.payloads = candidates, error, []

    def __call__(self, payload):
        self.payloads.append(payload)
        if self.error:
            raise self.error
        return list(self.candidates)


def run(candidates=None, error=None, **over):
    gen = Gen(candidates if candidates is not None else GOOD, error)
    result = compose_audit_report(body(**over), overall_generator=gen)
    return result, gen


def codes(result):
    return [v.code for v in result.verification]


def rule_draft():
    return compose_audit_report(body()).overall.draft_text


# ---------------------------------------------------------------- 끄면 변경 전과 같음


def test_without_generator_nothing_changes():
    plain = compose_audit_report(body())
    explicit = compose_audit_report(body(), overall_generator=None)
    a, b = plain.model_dump(by_alias=True), explicit.model_dump(by_alias=True)
    a["meta"].pop("generatedAt"), b["meta"].pop("generatedAt")
    assert a == b
    assert not any(code.startswith("OVERALL_LLM") for code in codes(plain))
    assert plain.overall.draft_text.startswith("점검 기간은 2026-10-01부터")


def test_module_switch_off_changes_nothing(monkeypatch):
    monkeypatch.setattr(overall_llm, "OVERALL_LLM", False)
    result, gen = run()
    assert gen.payloads == []
    assert result.overall.draft_text == rule_draft()
    assert not any(code.startswith("OVERALL_LLM") for code in codes(result))


def test_draft_text_switch_off_skips_model(monkeypatch):
    from app.agent import audit_compose

    monkeypatch.setattr(audit_compose, "DRAFT_TEXT", False)
    result, gen = run()
    assert gen.payloads == []
    assert result.overall.draft_text == ""


# ---------------------------------------------------------------- 채택


def test_good_paragraph_goes_first_and_rule_draft_is_kept_when_pruning_is_off(monkeypatch):
    monkeypatch.setattr(overall_llm, "PRUNE_COVERED", False)  # v2 동작: 겹쳐도 규칙 초안은 통째로 둔다
    result, gen = run()
    draft = result.overall.draft_text
    assert draft.startswith(" ".join(GOOD) + "\n")
    assert draft.endswith(rule_draft())
    assert "OVERALL_LLM_APPLIED" in codes(result)
    assert len(gen.payloads) == 1


def test_only_overall_is_touched():
    base = compose_audit_report(body()).model_dump(by_alias=True)
    result, _ = run()
    out = result.model_dump(by_alias=True)
    for data in (base, out):
        data["meta"].pop("generatedAt")
    base["overall"]["draftText"] = out["overall"]["draftText"] = ""
    base["verification"] = [v for v in base["verification"]]
    out["verification"] = [v for v in out["verification"] if not v["code"].startswith("OVERALL_LLM")]
    assert base == out


def test_iso_dates_inside_the_period_are_allowed():
    cand = ["2026-10-01부터 2026-10-31까지 작업 48건을 조회함.", *GOOD[1:]]
    result, _ = run(cand)
    assert "OVERALL_LLM_APPLIED" in codes(result)


# ---------------------------------------------------------------- 가드


@pytest.mark.parametrize(
    "bad, why",
    [
        (["기준에 부적정하며 위반 사례가 있음.", *GOOD[1:]], "평가어"),
        ([*GOOD[:3], "확인하지 못한 항목은 즉시 조치해야 함."], "권고"),
        (["대부분의 항목이 양호함.", *GOOD[1:]], "판단"),
        ([GOOD[0].replace("48", "49"), *GOOD[1:]], "없는 숫자"),
        ([GOOD[0], "확인 필요 항목은 위험성평가 기록이 없는 작업 6건, 측정값 없이 승인된 허가 2건임.", *GOOD[2:]], "확인 필요 건수 누락(3건)"),
        ([*GOOD[:2], "작업허가는 현황 참고 항목임.", GOOD[3]], "현황 참고 건수 누락(4건)"),
        ([*GOOD[:3], "아차사고 항목은 별도 항목임."], "확인하지 못한 항목 언급 누락"),
        (["2026-11-05에 점검함.", *GOOD[1:]], "기간 밖 날짜"),
        (["10월 3일에 점검함.", *GOOD[1:]], "한글 날짜"),
        (["작업 48건 중 확인 필요 6건, 2건, 3건, 현황 참고 24건, 4건이며 아차사고는 확인하지 못함."], "문장 1개(나머지는 모두 올바름)"),
        ([*GOOD, "개선조치는 12건임."], "문장 5개(나머지는 모두 올바름)"),
        (["점검 기간 중 작업 48건을 조회합니다.", *GOOD[1:]], "보고서체 아님"),
        ([GOOD[0], "확인 필요 항목은 " + "가" * 130 + " 6건 2건 3건임.", *GOOD[2:]], "길이"),
    ],
)
def test_guard_rejects_and_keeps_rule_draft(bad, why):
    result, _ = run(bad)
    assert result.overall.draft_text == rule_draft(), why
    assert "OVERALL_LLM_REPLACED" in codes(result), why
    assert "OVERALL_LLM_APPLIED" not in codes(result), why


def test_failure_message_does_not_echo_candidate_text():
    result, _ = run(["기준에 부적정하며 위반 사례가 있음.", *GOOD[1:]])
    messages = " ".join(v.message for v in result.verification)
    assert "부적정" not in messages and "위반 사례" not in messages


def test_model_error_falls_back_to_rule_draft():
    result, _ = run(error=LLMError("boom", engine="AUDIT_REPORT"))
    assert result.overall.draft_text == rule_draft()
    assert "OVERALL_LLM_FALLBACK" in codes(result)


def test_non_list_candidates_fall_back():
    result = compose_audit_report(body(), overall_generator=lambda payload: "문자열")  # type: ignore[arg-type,return-value]
    assert "OVERALL_LLM_FALLBACK" in codes(result)
    assert result.overall.draft_text == rule_draft()


def test_all_unavailable_skips_model():
    items = [{"queryType": "risk_assessment_rate", "title": "x", "stats": {"works": "bad"}}]
    result, gen = run(items=items)
    assert gen.payloads == []
    assert result.overall.draft_text == compose_audit_report(body(items=items)).overall.draft_text


def test_rate_written_as_integer_is_allowed():
    payload = {"reviewNeeded": [], "x": 100.0}
    assert "100" in overall_llm._allowed_numbers(payload)


# ---------------------------------------------------------------- 모델에 주는 입력

def test_payload_is_small_and_has_only_checked_values():
    _, gen = run()
    payload = gen.payloads[0]
    assert payload["period"] == {"from": "2026-10-01", "to": "2026-10-31"}
    assert payload["counts"] == {"works": 48, "permits": 24, "correctiveActions": 12}
    assert [r["count"] for r in payload["reviewNeeded"]] == [6, 2, 3]
    assert payload["unavailable"] == ["아차사고 접수 현황", "아차사고 조치 연결 현황"]
    assert len(payload["reference"]) == 2
    text = json.dumps(payload, ensure_ascii=False)
    assert "P-901" not in text and "제36조" not in text  # 기록 본문·법 조항은 주지 않는다
    assert "groups" not in payload and "stateLabel" not in text  # 항목 요약 표는 주지 않는다 (입력이 길면 느리다)
    assert len(text) < 700  # v1 입력은 약 1,700자였다
    assert set(payload) == {"period", "counts", "reviewNeeded", "reference", "unavailable", "links"}


@pytest.mark.parametrize(
    "cands, expect",
    [
        ([GOOD[0], GOOD[1], "작업허가는 현황 참고 항목임.", GOOD[3]], "현황 참고"),
        ([*GOOD[:3], "아차사고 항목은 별도 항목임."], "확인하지 못한 항목"),
        ([GOOD[0], "확인 필요 항목은 위험성평가 기록이 없는 작업 6건임.", *GOOD[2:]], "확인 필요 항목의 건수"),
    ],
)
def test_reason_names_the_missing_part(cands, expect):
    result, _ = run(cands)
    reasons = " ".join(v.message for v in result.verification if v.code == "OVERALL_LLM_REPLACED")
    assert expect in reasons


def test_roles_not_required_when_input_has_none():
    payload = {"reviewNeeded": [{"count": 6, "text": "x"}], "reference": [], "unavailable": [], "links": []}
    ok = ["확인 필요 항목은 위험성평가 기록이 없는 작업 6건임.", "그 밖의 확인 필요 항목은 없음."]
    assert overall_llm.check_paragraph(ok, payload=payload, date_from="2026-10-01", date_to="2026-10-31") is None


def test_prompt_example_numbers_are_not_in_the_real_input():
    # 예시 숫자(31·9·5)가 베껴져도 실제 입력에 없으면 가드가 버린다 (입력에 없는 숫자)
    result, _ = run(["이번 점검에서 작업 31건, 작업허가 9건, 개선조치 5건의 기록을 확인함.", *GOOD[1:]])
    assert "OVERALL_LLM_REPLACED" in codes(result)


# ---------------------------------------------------------------- 모델 호출 부분


class FakeLLM(LLMClient):
    name = "fake-overall"

    def __init__(self, text):
        super().__init__(None)
        self.text, self.calls = text, []

    def chat(self, messages, *, system="", tools=None, max_tokens=None):
        self.calls.append({"messages": messages, "system": system, "max_tokens": max_tokens})
        return LLMResponse(text=self.text)


def test_generate_parses_json_with_fence_and_think():
    raw = '<think>생각</think>\n```json\n' + json.dumps({"paragraph": GOOD}, ensure_ascii=False) + "\n```"
    llm = FakeLLM(raw)
    assert overall_llm.generate_overall_candidates({"a": 1}, llm) == GOOD
    assert llm.calls[0]["max_tokens"] == overall_llm.MAX_OUTPUT_TOKENS
    assert llm.calls[0]["system"] == overall_llm.SYSTEM_PROMPT


@pytest.mark.parametrize("raw", ["", "그냥 문장", '{"sentences": ["a"]}', '{"paragraph": []}', '{"paragraph": [1]}', '{"paragraph": "a"}'])
def test_generate_rejects_bad_shapes(raw):
    with pytest.raises(LLMError):
        overall_llm.generate_overall_candidates({}, FakeLLM(raw))


# ---------------------------------------------------------------- 서비스


def test_service_does_not_touch_model_when_both_off():
    def boom():
        raise AssertionError("모델을 얻으면 안 됨")

    out = service.compose_report(body(), narrative_llm_enabled=False, get_llm=boom)
    assert out.data.overall.draft_text == rule_draft()


def test_service_overall_enabled_uses_model():
    llm = FakeLLM(json.dumps({"paragraph": GOOD}, ensure_ascii=False))
    out = service.compose_report(body(), narrative_llm_enabled=False, get_llm=lambda: llm, overall_llm_enabled=True)
    assert out.data.overall.draft_text.startswith(GOOD[0])
    assert len(llm.calls) == 1  # 항목 문장 LLM은 꺼져 있어 종합 문단 한 번만


def test_service_model_setup_error_still_builds_report():
    def broken():
        raise RuntimeError("설정 오류")

    out = service.compose_report(body(), narrative_llm_enabled=False, get_llm=broken, overall_llm_enabled=True)
    assert out.data.overall.draft_text == rule_draft()


def test_service_narrative_default_is_unchanged():
    llm = FakeLLM(json.dumps({"paragraph": GOOD}, ensure_ascii=False))
    out = service.compose_report(body(), narrative_llm_enabled=False, get_llm=lambda: llm)  # overall_llm_enabled 기본값
    assert llm.calls == [] and out.data.overall.draft_text == rule_draft()


# ---------------------------------------------------------------- 설정·라우터


@pytest.fixture
def client(monkeypatch):
    def make(env: str | None):
        if env is None:
            monkeypatch.delenv("AUDIT_OVERALL_LLM", raising=False)
        else:
            monkeypatch.setenv("AUDIT_OVERALL_LLM", env)
        monkeypatch.delenv("AUDIT_NARRATIVE_LLM", raising=False)
        monkeypatch.setenv("CHECK_RULES_TOOL", "MOCK")  # 코드 기본값(SPRING)에 기대지 않는다
        monkeypatch.setenv("MSDS_TOOL", "MOCK")
        get_settings.cache_clear()
        from app.api.v1.agent.audit_compose import router

        app = FastAPI()
        app.include_router(router)
        llm = FakeLLM(json.dumps({"paragraph": GOOD}, ensure_ascii=False))

        class Provider:
            def get(self, scenario):
                assert scenario == "audit_query"
                return llm

        app.state.llm_provider = Provider()
        return TestClient(app), llm

    yield make
    get_settings.cache_clear()


def post(tc):
    return tc.post("/api/v1/agent/audit-report", json=BODY).json()["data"]["overall"]["draftText"]


def test_unset_env_follows_the_setting_default_through_router(client):
    # 코드 기본값(config.py 의 audit_overall_llm)이 켬이든 끔이든 라우터는 설정값을 그대로 따른다 (T40).
    tc, llm = client(None)
    enabled = get_settings().audit_overall_llm
    assert isinstance(enabled, bool)
    text = post(tc)
    assert len(llm.calls) == (1 if enabled else 0)
    if enabled:
        assert text.startswith(GOOD[0])
    else:
        assert text == rule_draft()


def test_setting_true_turns_it_on_through_router(client):
    tc, llm = client("true")
    assert get_settings().audit_overall_llm is True
    assert post(tc).startswith(GOOD[0])
    assert len(llm.calls) == 1


def test_setting_accepts_uppercase_env_and_false(client):
    tc, llm = client("false")
    assert post(tc) == rule_draft() and llm.calls == []


# ---------------------------------------------------------------- 경계 (D 파일 무관)


def test_module_does_not_import_d_narrative_or_report_modules():
    source = Path(overall_llm.__file__).read_text(encoding="utf-8")
    imported = {n.module for n in ast.walk(ast.parse(source)) if isinstance(n, ast.ImportFrom) and n.module}
    imported |= {a.name for n in ast.walk(ast.parse(source)) if isinstance(n, ast.Import) for a in n.names}
    assert "app.agent.audit_compose" not in imported  # 순환 import 방지: 접두어는 호출하는 쪽이 넘긴다
    assert "app.agent.audit_narrative" not in imported
    assert "app.agent.audit_report" not in imported
    assert "app.schemas.audit_report" not in imported


# ---------------------------------------------------------------- v3: 문단과 겹치는 규칙 초안 줄 빼기

from types import SimpleNamespace  # noqa: E402

PREFIXES = ("확인 필요: ", "현황 참고: ")
REVIEW_LINES = ["위험성평가 기록이 없는 작업 6건", "측정값 없이 승인된 허가 2건", "기한이 지난 개선조치 3건"]


def _first_int(text: str) -> int:
    found = re.search(r"\d+", text)
    return int(found.group()) if found else 0


def fake_overall(review=REVIEW_LINES, reference=("작업허가 24건 중 승인 20건, 반려 2건이며, 규칙 판정으로 차단된 허가는 4건임.",), extra=()):
    lines = ["점검 기간은 2026-10-01부터 2026-10-31까지이며, 조회한 기록은 작업 48건임."]
    lines += list(extra)
    lines += [PREFIXES[0] + r for r in review] + [PREFIXES[1] + r for r in reference]
    return SimpleNamespace(
        review_needed=[SimpleNamespace(text=r, count=_first_int(r)) for r in review],
        reference=[SimpleNamespace(text=r) for r in reference],
        draft_text="\n".join(lines),
    )


def test_prune_drops_review_lines_the_paragraph_already_says():
    result, _ = run()
    draft = result.overall.draft_text
    assert not any(line.startswith("확인 필요: ") for line in draft.split("\n"))
    assert "점검 기간은 2026-10-01부터" in draft  # 문단에 없는 정보(기간)는 남는다
    assert "위험성평가·작업허가: 확인 필요 1개 항목" in draft  # 묶음별 줄은 남는다
    assert "측정값 없이 승인된 허가 2건 중 같은 기간 규칙 차단 기록이 있는 허가는 1건임." in draft  # 연결 줄은 남는다
    assert "규칙 판정으로 차단된 허가 기록 4건임." not in draft  # 문단의 '규칙 차단 기록 4건'과 같은 내용
    assert "OVERALL_LLM_APPLIED" in codes(result)


def test_prune_keeps_a_reference_line_whose_wording_the_paragraph_does_not_repeat():
    # GOOD은 '차단 4건'이라고 쓰고 줄은 '규칙 판정으로 차단된 허가는 4건' → 같은 쌍이 아니므로 줄을 남긴다
    result, _ = run()
    assert "현황 참고: 작업허가 24건 중 승인 20건, 반려 2건이며, 규칙 판정으로 차단된 허가는 4건임." in result.overall.draft_text


def test_prune_drops_reference_line_when_paragraph_repeats_new_wording():
    cand = [*GOOD[:2], "작업허가는 24건 중 승인 20건, 반려 2건이며 규칙 판정으로 차단된 허가는 4건으로 현황 참고 항목임.", GOOD[3]]
    result, _ = run(cand)
    draft = result.overall.draft_text
    assert "현황 참고: 작업허가 24건 중" not in draft
    assert "4줄은 뺌" in " ".join(v.message for v in result.verification if v.code == "OVERALL_LLM_APPLIED")


def test_prune_never_touches_structured_fields():
    plain = compose_audit_report(body()).overall
    result, _ = run()
    assert result.overall.review_needed == plain.review_needed
    assert result.overall.reference == plain.reference
    assert result.overall.lines == plain.lines
    assert result.overall.links == plain.links
    assert result.overall.human_tasks == plain.human_tasks


def test_prune_off_switch_and_missing_prefixes_keep_everything(monkeypatch):
    overall = fake_overall()
    before = overall.draft_text
    paragraph = " ".join(GOOD)
    # 접두어를 안 주면(옛 호출) 아무것도 안 뺀다
    summary = SimpleNamespace(groups=[SimpleNamespace(rows=[SimpleNamespace(state="REVIEW", area="a")])])
    overall.counts = SimpleNamespace(works=48, permits=24, corrective_actions=12)
    overall.links = []
    notes = []
    ok = overall_llm.apply_overall(overall, summary, generator=lambda p: list(GOOD), date_from="2026-10-01", date_to="2026-10-31",
                                   note=lambda c, s, m: notes.append(c))
    assert ok and overall.draft_text == paragraph + "\n" + before
    # 스위치를 꺼도 접두어를 줘도 안 뺀다
    overall2 = fake_overall()
    overall2.counts, overall2.links = overall.counts, []
    monkeypatch.setattr(overall_llm, "PRUNE_COVERED", False)
    overall_llm.apply_overall(overall2, summary, generator=lambda p: list(GOOD), date_from="2026-10-01", date_to="2026-10-31",
                              note=lambda c, s, m: None, covered_prefixes=PREFIXES)
    assert overall2.draft_text == paragraph + "\n" + before


def test_prune_same_number_for_another_item_does_not_count():
    # 문단이 '반려 2건'만 말하고 '측정값 없이 승인된 허가 2건'은 빠뜨려도, 숫자 2만으로는 줄을 빼지 않는다
    paragraph = "작업 6건, 개선조치 3건, 반려 2건을 확인함."
    rest, dropped = overall_llm.prune_covered_lines(fake_overall(), paragraph, PREFIXES)
    assert "확인 필요: 측정값 없이 승인된 허가 2건" in rest
    assert "확인 필요: 위험성평가 기록이 없는 작업 6건" not in rest and "확인 필요: 기한이 지난 개선조치 3건" not in rest
    assert dropped == 2


def test_prune_ignores_particles_and_commas():
    overall = fake_overall(review=[], reference=("작업허가 1,200건 중 승인 20건임.",))
    rest, dropped = overall_llm.prune_covered_lines(overall, "작업허가는 1200건 중 승인 20건임.", PREFIXES)
    assert dropped == 1 and "현황 참고" not in rest


def test_prune_keeps_lines_without_counts_and_other_lines():
    overall = fake_overall(review=["위험성평가 실시"], reference=(), extra=["그 밖의 안전관리 기록: 확인 필요 2개 항목, 현황 참고 1개 항목임."])
    rest, dropped = overall_llm.prune_covered_lines(overall, "위험성평가 실시 항목과 확인 필요 2개 항목, 현황 참고 1개 항목을 봄.", PREFIXES)
    assert dropped == 0 and rest == overall.draft_text  # 숫자 쌍이 없는 줄·후보가 아닌 줄은 안 뺀다


def test_failed_paragraph_never_prunes():
    result, _ = run(["기준에 부적정하며 위반 사례가 있음.", *GOOD[1:]])
    assert result.overall.draft_text == rule_draft()


# ---------------------------------------------------------------- v3: 차단 건수를 승인·반려와 따로 쓴다


def test_permit_reference_line_separates_blocked_count():
    text = rule_draft()
    assert "현황 참고: 작업허가 24건 중 승인 20건, 반려 2건이며, 규칙 판정으로 차단된 허가는 4건임." in text
    assert "반려 2건, 차단 4건" not in text


def test_permit_reference_old_wording_comes_back_when_switched_off(monkeypatch):
    from app.agent import audit_compose

    monkeypatch.setattr(audit_compose, "REFERENCE_BLOCK_SEPARATE", False)
    assert "현황 참고: 작업허가 24건 중 승인 20건, 반려 2건, 차단 4건임." in rule_draft()


def test_model_sees_the_new_wording_and_prompt_example_mirrors_it():
    _, gen = run()
    assert any("규칙 판정으로 차단된 허가는 4건" in line for line in gen.payloads[0]["reference"])
    prompt = overall_llm.SYSTEM_PROMPT
    assert "규칙 판정으로 차단된 허가는 1건" in prompt  # 예시도 새 문구
    assert "차단 1건" not in prompt  # 옛 문구 예시가 남아 있으면 모델이 승인·반려와 나란히 쓴다
    assert "나란히 세지 말고" in prompt
