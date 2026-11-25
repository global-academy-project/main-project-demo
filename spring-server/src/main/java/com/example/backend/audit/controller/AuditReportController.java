package com.example.backend.audit.controller;

import com.example.backend.audit.dto.AuditReportResponse;
import com.example.backend.audit.dto.CreateAuditReportRequest;
import com.example.backend.audit.dto.UpdateAuditReportRequest;
import com.example.backend.audit.service.AuditReportService;
import com.example.backend.common.response.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * 감사보고서 (현장 관리자 이상): 목록·만들기(집계, 커밋 뒤 AI 요약)·상세·고치기·다시 요약·삭제(숨김).
 * 출력은 화면 인쇄, 또는 HWPX 내려받기(export: 파일 바이트 그대로, 실패는 JSON 오류 봉투)
 */
@RestController
@RequestMapping("/api/v1/sites/{siteId}/audit-reports")
public class AuditReportController {

    private final AuditReportService service;

    public AuditReportController(AuditReportService service) {
        this.service = service;
    }

    @GetMapping
    public ApiResponse<List<AuditReportResponse>> list(@AuthenticationPrincipal Long userId, @PathVariable Long siteId) {
        return ApiResponse.ok(service.list(userId, siteId));
    }

    /** 만들기: 집계를 저장하고 바로 돌려준다 (status=GENERATING). AI 요약은 커밋 뒤 따로 하고, 화면은 상세를 다시 조회한다 */
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public ApiResponse<AuditReportResponse> create(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                                   @Valid @RequestBody CreateAuditReportRequest request) {
        return ApiResponse.ok(service.create(userId, siteId, request));
    }

    @GetMapping("/{reportId}")
    public ApiResponse<AuditReportResponse> get(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                                @PathVariable Long reportId) {
        return ApiResponse.ok(service.get(userId, siteId, reportId));
    }

    /** 제목·종합 의견·항목별 요약 (lockVersion 필수) */
    @PatchMapping("/{reportId}")
    public ApiResponse<AuditReportResponse> update(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                                   @PathVariable Long reportId,
                                                   @Valid @RequestBody UpdateAuditReportRequest request) {
        return ApiResponse.ok(service.update(userId, siteId, reportId, request));
    }

    /** AI 요약 다시 하기 (요약 실패 또는 요약 중으로 오래 멈춘 보고서) */
    @PostMapping("/{reportId}/summarize")
    public ApiResponse<AuditReportResponse> summarize(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                                      @PathVariable Long reportId) {
        return ApiResponse.ok(service.retrySummary(userId, siteId, reportId));
    }

    /** HWPX 내려받기 (format=hwpx 만). 요약이 끝난 보고서(초안·검토 필요)만, 그 밖은 409 AUDIT_REPORT_NOT_READY */
    @GetMapping("/{reportId}/export")
    public ResponseEntity<byte[]> export(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                         @PathVariable Long reportId,
                                         @RequestParam(name = "format", required = false) String format) {
        AuditReportService.ExportFile file = service.export(userId, siteId, reportId, format);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(HWPX_MEDIA_TYPE))
                .contentLength(file.content().length)
                .header(HttpHeaders.CONTENT_DISPOSITION,
                        ContentDisposition.attachment().filename(file.fileName(), StandardCharsets.UTF_8).build().toString())
                .header("X-Content-Type-Options", "nosniff")
                .header(HttpHeaders.CACHE_CONTROL, "no-store")
                .body(file.content());
    }

    static final String HWPX_MEDIA_TYPE = "application/hwp+zip";

    @DeleteMapping("/{reportId}")
    public ApiResponse<Void> delete(@AuthenticationPrincipal Long userId, @PathVariable Long siteId,
                                    @PathVariable Long reportId) {
        service.delete(userId, siteId, reportId);
        return ApiResponse.ok(null);
    }
}
