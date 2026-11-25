package com.example.backend.audit.service;

import com.example.backend.audit.entity.AuditReportStatus;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;
import tools.jackson.databind.node.ArrayNode;

import static org.assertj.core.api.Assertions.assertThat;

/** 감사 대응 보고서 AI 응답 읽기: 구성기 응답(새)·옛 응답 (B 「summarize 수정 안내」, 11/20) */
@DisplayName("감사 대응 보고서 AI 응답 읽기")
class AuditReportReplyTest {

    private final JsonMapper jsonMapper = JsonMapper.builder().build();

    /** 서버가 저장한 항목 2개 (집계는 서버 값) */
    private ArrayNode items() {
        return (ArrayNode) jsonMapper.readTree("""
                [{"queryType": "risk_assessment_rate", "title": "위험성평가 실시율", "summary": "", "verification": null,
                  "stats": {"works": 3, "written": 2, "rate": 66.7}, "total": 3, "truncated": false, "records": [], "evidence": []},
                 {"queryType": "blocked_records", "title": "차단 기록", "summary": "", "verification": null,
                  "stats": {"count": 0}, "total": 0, "truncated": false, "records": [], "evidence": []}]
                """);
    }

    /** ai-model 구성기 응답 (일부). 아차사고 항목은 서버가 보내지 않은 queryType */
    private JsonNode compose(long reportId, long siteId, String status) {
        return jsonMapper.readTree("""
                {"formType": "AUDIT_REPORT", "schemaVersion": "v1", "status": "%s",
                 "meta": {"reportId": %d, "siteId": %d, "dateFrom": "2026-10-01", "dateTo": "2026-10-31"},
                 "groups": [
                   {"no": "1", "seq": 1, "area": "작업 전 위험성평가",
                    "items": [{"seq": 1, "queryType": "risk_assessment_rate", "state": "REVIEW", "stateLabel": "확인 필요",
                               "sentences": [{"text": "작업 3건 중 2건에 위험성평가가 작성됨.", "evidence": []},
                                             {"text": "  ", "evidence": []},
                                             {"text": "실시율은 66.7%%임.", "evidence": []}]}]},
                   {"no": "2", "seq": 2, "area": "아차사고",
                    "items": [{"seq": 2, "queryType": "near_miss_receipt", "state": "UNAVAILABLE", "stateLabel": "확인 불가",
                               "sentences": [{"text": "조회 항목이 아직 없음.", "evidence": []}]}]}],
                 "overall": {"lines": ["확인 필요 1건"]}, "verification": []}
                """.formatted(status, reportId, siteId));
    }

    @Test
    @DisplayName("구성기 응답: 보고서가 맞으면 항목 요약에 문장(빈 문장 제외)을 넣고, 검증은 null, 상태는 검토 필요, 원본 저장")
    void composed() {
        AuditReportService.Summary s = AuditReportService.readReply(7L, 3L, items(), compose(7, 3, "COMPLETE"), jsonMapper);

        assertThat(s.status()).isEqualTo(AuditReportStatus.REVIEW_REQUIRED);
        assertThat(s.overall()).isNull();
        assertThat(s.failure()).isNull();
        assertThat(s.items().get(0).path("summary").asString()).isEqualTo("작업 3건 중 2건에 위험성평가가 작성됨.\n실시율은 66.7%임.");
        assertThat(s.items().get(0).path("verification").isNull()).isTrue();
        assertThat(s.items().get(0).path("stats").path("rate").asDouble()).isEqualTo(66.7);   // 집계는 서버 값 그대로
        assertThat(s.items().get(1).path("summary").asString()).isEmpty();                  // 짝이 없으면 그대로
        assertThat(s.items()).hasSize(2);                                                    // 아차사고 항목은 더하지 않는다
        JsonNode saved = jsonMapper.readTree(s.compose());
        assertThat(saved.path("formType").asString()).isEqualTo("AUDIT_REPORT");
        assertThat(saved.path("groups").size()).isEqualTo(2);                                // 원본은 아차사고 항목까지 그대로
    }

    @Test
    @DisplayName("구성기 응답 INCOMPLETE(확인 불가 항목 있음)도 실패가 아니라 검토 필요")
    void incompleteIsNotFailure() {
        AuditReportService.Summary s = AuditReportService.readReply(7L, 3L, items(), compose(7, 3, "INCOMPLETE"), jsonMapper);
        assertThat(s.status()).isEqualTo(AuditReportStatus.REVIEW_REQUIRED);
        assertThat(s.compose()).isNotNull();
    }

    @Test
    @DisplayName("구성기 응답이 다른 보고서·다른 현장·다른 형식·다른 판이면 요약 실패, 요약·원본은 남기지 않음")
    void mismatch() {
        for (JsonNode wrong : new JsonNode[]{compose(8, 3, "COMPLETE"), compose(7, 4, "COMPLETE"),
                jsonMapper.readTree(compose(7, 3, "COMPLETE").toString().replace("\"v1\"", "\"v2\"")),
                jsonMapper.readTree(compose(7, 3, "COMPLETE").toString().replace("\"AUDIT_REPORT\"", "\"OTHER\""))}) {
            AuditReportService.Summary s = AuditReportService.readReply(7L, 3L, items(), wrong, jsonMapper);
            assertThat(s.status()).isEqualTo(AuditReportStatus.FAILED);
            assertThat(s.failure()).isEqualTo("AI 서버 응답이 요청과 맞지 않습니다.");
            assertThat(s.compose()).isNull();
            assertThat(s.items().get(0).path("summary").asString()).isEmpty();
        }
    }

    @Test
    @DisplayName("옛 응답(formType 없음, 가짜 AI 서버): 항목별 요약·검증, DRAFT, 전체 검증 PASS, 원본 저장 안 함")
    void legacy() {
        JsonNode legacy = jsonMapper.readTree("""
                {"reportId": 7, "siteId": 3, "status": "DRAFT", "overallVerification": "PASS",
                 "items": [{"queryType": "risk_assessment_rate", "summary": "옛 요약",
                            "verification": {"status": "MATCH", "mismatches": []}}]}
                """);
        AuditReportService.Summary s = AuditReportService.readReply(7L, 3L, items(), legacy, jsonMapper);
        assertThat(s.status()).isEqualTo(AuditReportStatus.DRAFT);
        assertThat(s.overall()).isEqualTo("PASS");
        assertThat(s.compose()).isNull();
        assertThat(s.items().get(0).path("summary").asString()).isEqualTo("옛 요약");
        assertThat(s.items().get(0).path("verification").path("status").asString()).isEqualTo("MATCH");

        JsonNode unknown = jsonMapper.readTree("{\"status\": \"COMPLETE\", \"items\": []}");   // formType 없는 모르는 상태
        AuditReportService.Summary f = AuditReportService.readReply(7L, 3L, items(), unknown, jsonMapper);
        assertThat(f.status()).isEqualTo(AuditReportStatus.FAILED);
        assertThat(f.failure()).isEqualTo("AI 요약이 완료되지 않았습니다.");
    }

    @Test
    @DisplayName("종합 의견 초안: overall.draftText 를 앞뒤 공백 없이 꺼낸다")
    void opinionOf() {
        String compose = """
                {"formType": "AUDIT_REPORT", "overall": {"lines": ["점검 기간은 2026-10-01부터"], "draftText": "  점검 기간은 2026-10-01부터 2026-10-31까지임.\\n확인 필요: 차단 1건  "}}
                """;
        assertThat(AuditReportService.opinionOf(compose, jsonMapper))
                .isEqualTo("점검 기간은 2026-10-01부터 2026-10-31까지임.\n확인 필요: 차단 1건");
    }

    @Test
    @DisplayName("종합 의견 초안이 없음·빈 문자열·문자열 아님·너무 김·JSON 깨짐·원본 없음이면 null (예외 없음)")
    void opinionOfMissing() {
        assertThat(AuditReportService.opinionOf(null, jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf(" ", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"lines\": []}}", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"draftText\": \"   \"}}", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"draftText\": null}}", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"draftText\": 12}}", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"draftText\": {\"a\": 1}}}", jsonMapper)).isNull();
        String tooLong = "가".repeat(AuditReportService.OPINION_MAX + 1);
        assertThat(AuditReportService.opinionOf("{\"overall\": {\"draftText\": \"" + tooLong + "\"}}", jsonMapper)).isNull();
        assertThat(AuditReportService.opinionOf("{\"overall\": ", jsonMapper)).isNull();
    }

    @Test
    @DisplayName("내려받기 파일 이름: 제목.hwpx, 못 쓰는 글자는 _, 빈 제목은 audit-report-{id}.hwpx")
    void fileName() {
        assertThat(AuditReportService.fileName("감사 대응 보고서 2026-10-01 ~ 2026-10-31", 6L))
                .isEqualTo("감사 대응 보고서 2026-10-01 ~ 2026-10-31.hwpx");
        assertThat(AuditReportService.fileName("a/b:c*d?\"e<f>g|h\\i", 6L)).isEqualTo("a_b_c_d__e_f_g_h_i.hwpx");
        assertThat(AuditReportService.fileName("  ", 6L)).isEqualTo("audit-report-6.hwpx");
        assertThat(AuditReportService.fileName(null, 6L)).isEqualTo("audit-report-6.hwpx");
    }
}
