package com.example.backend.audit.service;

import com.example.backend.agent.client.AgentCallException;
import com.example.backend.agent.client.AgentClient;
import com.example.backend.agent.client.AgentFile;
import com.example.backend.agent.client.AgentReply;
import com.example.backend.audit.dto.AuditReportResponse;
import com.example.backend.audit.dto.CreateAuditReportRequest;
import com.example.backend.audit.dto.UpdateAuditReportRequest;
import com.example.backend.audit.entity.AuditReport;
import com.example.backend.audit.entity.AuditReportStatus;
import com.example.backend.audit.repository.AuditReportRepository;
import com.example.backend.common.exception.BusinessException;
import com.example.backend.common.exception.ErrorCode;
import com.example.backend.history.entity.AccessAction;
import com.example.backend.history.entity.RecordAccessLog;
import com.example.backend.history.repository.RecordAccessLogRepository;
import com.example.backend.site.entity.Site;
import com.example.backend.site.entity.SiteMode;
import com.example.backend.site.repository.SiteRepository;
import com.example.backend.user.entity.User;
import com.example.backend.user.repository.UserRepository;
import jakarta.persistence.EntityManager;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.PageRequest;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.transaction.annotation.Transactional;
import tools.jackson.databind.json.JsonMapper;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doAnswer;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * 감사 대응 보고서: AI 서버가 구성기 응답을 줄 때 (11/20). 만들기 → 요약 → 검토 필요 + 항목 요약 + 원본(compose_json, V12) 저장,
 * 상세 응답의 composeResult, 종합 의견 초안(overall.draftText) 채우기, HWPX 내려받기.
 * AI 서버는 Mockito 로 대신한다 (받은 reportId·siteId 를 meta 에 그대로 담는 구성기 응답). 실제 DB, 끝나면 롤백.
 */
@SpringBootTest
@Transactional
@DisplayName("감사 대응 보고서 구성기 응답 연결 (실제 DB)")
class AuditReportComposeDbTest {

    @MockitoBean AgentClient agentClient;
    @Autowired AuditReportService service;
    @Autowired AuditReportRepository reportRepository;
    @Autowired UserRepository userRepository;
    @Autowired SiteRepository siteRepository;
    @Autowired JsonMapper jsonMapper;
    @Autowired EntityManager em;
    @Autowired RecordAccessLogRepository accessLogRepository;

    private Long adminId;
    private Long siteId;

    @BeforeEach
    void setUp() {
        String tag = UUID.randomUUID().toString().substring(0, 8);
        adminId = userRepository.save(User.bootstrapAdmin("arc-" + tag + "@example.com", "HASH", LocalDateTime.now())).getId();
        siteId = siteRepository.save(new Site("구성기현장-" + tag, SiteMode.VERIFY)).getId();
    }

    private void composeReply(boolean sameReport) {
        composeReply(sameReport, null);
    }

    /** draftText: 종합 의견 초안 (null 이면 응답에 넣지 않는다) */
    private void composeReply(boolean sameReport, String draftText) {
        String overall = draftText == null ? "{\"lines\": []}"
                : "{\"lines\": [], \"draftText\": " + jsonMapper.writeValueAsString(draftText) + "}";
        // doAnswer: 같은 테스트에서 다시 정해도 이전 Answer 가 불리지 않게 한다
        doAnswer(call -> {
            Map<?, ?> body = call.getArgument(0);
            long reportId = ((Number) body.get("reportId")).longValue() + (sameReport ? 0 : 1);
            long site = ((Number) body.get("siteId")).longValue();
            return new AgentReply(jsonMapper.readTree("""
                    {"formType": "AUDIT_REPORT", "schemaVersion": "v1", "status": "INCOMPLETE",
                     "meta": {"reportId": %d, "siteId": %d},
                     "groups": [{"no": "1", "seq": 1, "area": "차단",
                                 "items": [{"queryType": "blocked_records", "sentences": [{"text": "차단 기록 0건임."}]}]}],
                     "overall": %s, "verification": []}
                    """.formatted(reportId, site, overall)));
        }).when(agentClient).auditReport(any());
    }

    private AuditReportResponse createAndSummarize() {
        LocalDate today = LocalDate.now();
        AuditReportResponse created = service.create(adminId, siteId,
                new CreateAuditReportRequest(today.minusDays(7), today, List.of("blocked_records", "risk_assessment_rate")));
        service.runSummary(created.reportId());   // 커밋 뒤 리스너가 하는 일 (테스트는 롤백이라 직접)
        em.flush();
        em.clear();
        return service.get(adminId, siteId, created.reportId());
    }

    @Test
    @DisplayName("구성기 응답: 검토 필요, 항목 요약에 문장, 검증 없음, 원본을 compose_json 에 저장")
    void savesCompose() {
        composeReply(true);
        AuditReportResponse r = createAndSummarize();

        assertThat(r.status()).isEqualTo(AuditReportStatus.REVIEW_REQUIRED);
        assertThat(r.statusLabel()).isEqualTo("검토 필요");
        assertThat(r.overallVerification()).isNull();
        assertThat(r.failureReason()).isNull();
        assertThat(r.items().get(1).path("queryType").asString()).isEqualTo("blocked_records");
        assertThat(r.items().get(1).path("summary").asString()).isEqualTo("차단 기록 0건임.");
        assertThat(r.items().get(1).path("verification").isNull()).isTrue();
        AuditReport saved = reportRepository.findById(r.reportId()).orElseThrow();
        assertThat(jsonMapper.readTree(saved.getComposeJson()).path("status").asString()).isEqualTo("INCOMPLETE");
        // 상세 응답에 원본(composeResult)을 싣고, 목록에는 싣지 않는다
        assertThat(r.composeResult().path("formType").asString()).isEqualTo("AUDIT_REPORT");
        assertThat(service.list(adminId, siteId)).singleElement().satisfies(x -> assertThat(x.composeResult()).isNull());
    }

    @Test
    @DisplayName("다른 보고서의 응답이면 요약 실패, 원본 저장 안 함, 다시 요약 가능")
    void mismatchFails() {
        composeReply(false);
        AuditReportResponse r = createAndSummarize();

        assertThat(r.status()).isEqualTo(AuditReportStatus.FAILED);
        assertThat(r.failureReason()).isEqualTo("AI 서버 응답이 요청과 맞지 않습니다.");
        assertThat(r.summaryRetryable()).isTrue();
        assertThat(reportRepository.findById(r.reportId()).orElseThrow().getComposeJson()).isNull();
        assertThat(r.composeResult()).isNull();
    }

    @Test
    @DisplayName("초안 없는 구성기 응답이면 종합 의견은 비어 있다")
    void noDraftKeepsSummaryEmpty() {
        composeReply(true);
        assertThat(createAndSummarize().summary()).isNull();
    }

    @Test
    @DisplayName("종합 의견이 비어 있으면 overall.draftText 를 넣는다")
    void fillsDraftOpinion() {
        composeReply(true, "점검 기간은 2026-10-01부터 2026-10-31까지임.\n확인 필요: 차단 1건");
        AuditReportResponse r = createAndSummarize();

        assertThat(r.status()).isEqualTo(AuditReportStatus.REVIEW_REQUIRED);
        assertThat(r.summary()).isEqualTo("점검 기간은 2026-10-01부터 2026-10-31까지임.\n확인 필요: 차단 1건");
        assertThat(r.composeResult().path("overall").path("draftText").asString()).isEqualTo(r.summary());
    }

    @Test
    @DisplayName("사람이 쓴 종합 의견은 다시 요약해도 초안으로 덮어쓰지 않는다")
    void keepsHumanOpinion() {
        composeReply(false);                       // 첫 요약은 실패
        AuditReportResponse failed = createAndSummarize();
        assertThat(failed.status()).isEqualTo(AuditReportStatus.FAILED);
        AuditReportResponse edited = service.update(adminId, siteId, failed.reportId(),
                new UpdateAuditReportRequest(failed.title(), "사람이 쓴 의견", List.of(), failed.lockVersion()));
        service.retrySummary(adminId, siteId, edited.reportId());

        composeReply(true, "점검 기간은 …");      // 다시 요약: 초안이 와도
        service.runSummary(edited.reportId());
        em.flush();
        em.clear();

        AuditReportResponse r = service.get(adminId, siteId, edited.reportId());
        assertThat(r.status()).isEqualTo(AuditReportStatus.REVIEW_REQUIRED);
        assertThat(r.summary()).isEqualTo("사람이 쓴 의견");
    }

    @Test
    @DisplayName("HWPX 내려받기: 저장된 값을 AI 서버로 보내고 받은 파일을 그대로, 열람 기록 EXPORT")
    @SuppressWarnings("unchecked")
    void exportsHwpx() {
        composeReply(true, "점검 기간은 …");
        AuditReportResponse r = createAndSummarize();
        byte[] bytes = {0x50, 0x4b, 0x03, 0x04};
        when(agentClient.auditReportExport(any())).thenReturn(new AgentFile(bytes, "application/hwp+zip"));

        AuditReportService.ExportFile file = service.export(adminId, siteId, r.reportId(), "hwpx");

        assertThat(file.content()).isEqualTo(bytes);
        assertThat(file.fileName()).isEqualTo(r.title() + ".hwpx");
        ArgumentCaptor<Map<String, Object>> sent = ArgumentCaptor.forClass(Map.class);
        verify(agentClient).auditReportExport(sent.capture());
        Map<String, Object> body = sent.getValue();
        assertThat(body).containsEntry("format", "HWPX").containsEntry("reportId", r.reportId())
                .containsEntry("title", r.title()).containsEntry("summary", "점검 기간은 …")
                .containsEntry("dateFrom", r.dateFrom().toString()).containsEntry("dateTo", r.dateTo().toString())
                .doesNotContainKey("composeResult");
        assertThat((String) body.get("siteName")).startsWith("구성기현장-");
        List<Map<String, Object>> items = (List<Map<String, Object>>) body.get("items");
        assertThat(items).extracting(m -> m.get("queryType")).containsExactly("risk_assessment_rate", "blocked_records");
        assertThat(items.get(1)).containsEntry("summary", "차단 기록 0건임.").containsKeys("stats", "evidenceCount", "truncated", "total")
                .doesNotContainKeys("records", "evidence", "verification");
        assertThat(accessLogRepository.findBySiteIdOrderByCreatedAtDescIdDesc(siteId, PageRequest.of(0, 1)).getContent())
                .singleElement().satisfies(log -> {
                    assertThat(log.getAction()).isEqualTo(AccessAction.EXPORT);
                    assertThat(log.getResourceId()).isEqualTo(r.reportId());
                });
    }

    @Test
    @DisplayName("HWPX 내려받기: 요약 중·요약 실패는 409, 형식이 hwpx 가 아니면 400 (AI 서버를 부르지 않는다)")
    void exportRejects() {
        LocalDate today = LocalDate.now();
        AuditReportResponse generating = service.create(adminId, siteId,
                new CreateAuditReportRequest(today.minusDays(7), today, List.of("blocked_records")));
        assertThatThrownBy(() -> service.export(adminId, siteId, generating.reportId(), "hwpx"))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.AUDIT_REPORT_NOT_READY));

        composeReply(false);
        AuditReportResponse failed = createAndSummarize();
        assertThatThrownBy(() -> service.export(adminId, siteId, failed.reportId(), "hwpx"))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.AUDIT_REPORT_NOT_READY));
        assertThatThrownBy(() -> service.export(adminId, siteId, failed.reportId(), "pdf"))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_REQUEST));
        assertThatThrownBy(() -> service.export(adminId, siteId, failed.reportId(), null))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.INVALID_REQUEST));
        verify(agentClient, never()).auditReportExport(any());
    }

    @Test
    @DisplayName("HWPX 내려받기: AI 서버에 못 닿으면 503, 변환 실패면 502. 열람 기록은 남기지 않는다")
    void exportAgentErrors() {
        composeReply(true);
        AuditReportResponse r = createAndSummarize();

        doThrow(new AgentCallException("AI_UNAVAILABLE", "연결 실패", null)).when(agentClient).auditReportExport(any());
        assertThatThrownBy(() -> service.export(adminId, siteId, r.reportId(), "hwpx"))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.AUDIT_EXPORT_UNAVAILABLE));

        doThrow(new AgentCallException("BAD_GATEWAY", "변환 실패", null)).when(agentClient).auditReportExport(any());
        assertThatThrownBy(() -> service.export(adminId, siteId, r.reportId(), "hwpx"))
                .isInstanceOfSatisfying(BusinessException.class,
                        e -> assertThat(e.getErrorCode()).isEqualTo(ErrorCode.AUDIT_EXPORT_FAILED));
        assertThat(accessLogRepository.findBySiteIdOrderByCreatedAtDescIdDesc(siteId, PageRequest.of(0, 10)).getContent())
                .noneMatch(log -> log.getAction() == AccessAction.EXPORT);
    }
}
