package com.example.backend.agent.client;

/**
 * AI 서버(에이전트) 호출. app.agent.client 로 구현을 고른다 (mock | fastapi).
 * 실패는 AgentCallException. 오래 걸리므로 트랜잭션 밖(커밋 후 비동기)에서만 부른다.
 */
public interface AgentClient {

    AgentReply workRegister(WorkRegisterCall call);

    /** 기록 질문 (RECORD_QUERY). 응답 모양은 RecordQueryData */
    AgentReply recordQuery(RecordQueryCall call);

    /**
     * 감사보고서 요약·수치 검증 (ai-model POST /api/v1/agent/audit-report).
     * body 는 ai-model AuditReportInput 모양 (reportId, siteId, dateFrom, dateTo, items[{queryType, title, stats, records, evidence}]).
     * 응답 data 는 구성기 응답 (formType=AUDIT_REPORT, schemaVersion, status COMPLETE·INCOMPLETE, meta{reportId, siteId, …},
     * groups[].items[{queryType, sentences[{text}], …}], overall, verification) 또는 옛 응답(가짜 AI 서버:
     * status, items[{queryType, title, summary, verification}], overallVerification). 읽기는 AuditReportService.readReply
     */
    AgentReply auditReport(java.util.Map<String, Object> body);

    /**
     * 감사 대응 보고서 HWPX 파일 만들기 (ai-model POST /api/v1/agent/audit-report/export, B 「HWPX 내려받기」 11/22).
     * body 는 ai-model AuditExportInput 모양 (format=HWPX, reportId, title, siteName, dateFrom, dateTo, createdByName, summary,
     * items[{queryType, title, stats, summary, evidenceCount, truncated, total}]). 저장된 보고서 값을 보내고 집계·요약은 다시 하지 않는다.
     * 성공은 파일 바이트 그대로(봉투 없음), 실패는 JSON 오류 봉투 → AgentCallException
     */
    AgentFile auditReportExport(java.util.Map<String, Object> body);

    /**
     * 아차사고 태그 제안 (ai-model POST /api/v1/agent/near-miss-tag, 시나리오 C).
     * 응답 data 는 NearMissTagResponse (tags[{axis, value, confidence}], taggingSource, taggingVersion, model).
     * 모델 호출이 실패해도 AI 서버는 규칙 태그로 성공 응답한다 (taggingSource near_miss_rules, model null. A 11/18 결정)
     */
    AgentReply nearMissTag(NearMissTagCall call);
}
