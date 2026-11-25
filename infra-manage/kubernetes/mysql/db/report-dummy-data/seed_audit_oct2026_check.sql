-- 감사 대응 보고서가 읽는 5개 집계를 SQL 로 다시 계산한다 (RecordSearchService·AuditReportService 와 같은 정의).
-- 보고서 화면의 숫자와 비교한다. 같은 현장·기간의 시드가 아닌 기록도 함께 센다.
SET NAMES utf8mb4;
SET @site_id = (SELECT id FROM sites WHERE active = TRUE ORDER BY id LIMIT 1);
SET @from = '2026-10-01';
SET @to   = '2026-10-31';

-- 1) 위험성평가 실시율: 취소 제외 작업, 작업별 최신 revision. 실시율 = 작성 ÷ 작업, 승인율 = 승인 ÷ 작업
SELECT COALESCE(w.work_type, '합계') AS work_type, COUNT(*) AS works, SUM(r.id IS NOT NULL) AS written,
       SUM(r.status = 'APPROVED') AS approved, COUNT(*) - SUM(r.id IS NOT NULL) AS missing,
       ROUND(SUM(r.id IS NOT NULL) * 100 / COUNT(*), 1) AS rate, ROUND(SUM(r.status = 'APPROVED') * 100 / COUNT(*), 1) AS approved_rate
FROM works w LEFT JOIN risk_assessments r ON r.work_id = w.id
     AND r.revision = (SELECT MAX(r2.revision) FROM risk_assessments r2 WHERE r2.work_id = w.id)
WHERE w.site_id = @site_id AND w.work_date BETWEEN @from AND @to AND w.status <> 'CANCELED'
GROUP BY w.work_type WITH ROLLUP;

-- 2) 작업허가 승인 현황: 허가는 valid_from 이 기간 안, 승인은 허가에 달린 결재 행 수. 승인률 = 승인 ÷ (승인 + 반려). 차단 = 공식 판정(agent_run_id 없음)에서 한 번이라도 BLOCK
SELECT COALESCE(p.permit_type, '합계') AS permit_type, COUNT(DISTINCT p.id) AS permits, COUNT(a.id) AS requested,
       SUM(a.status = 'APPROVED') AS approved, SUM(a.status = 'REJECTED') AS rejected, SUM(a.status = 'CANCELED') AS canceled,
       COUNT(DISTINCT CASE WHEN EXISTS (SELECT 1 FROM rule_evaluations e WHERE e.target_type = 'PERMIT' AND e.target_id = p.id
             AND e.result = 'BLOCK' AND e.agent_run_id IS NULL) THEN p.id END) AS blocked,
       ROUND(SUM(a.status = 'APPROVED') * 100 / NULLIF(SUM(a.status = 'APPROVED') + SUM(a.status = 'REJECTED'), 0), 1) AS approval_rate
FROM permits p LEFT JOIN approvals a ON a.target_type = 'PERMIT' AND a.target_id = p.id
WHERE p.site_id = @site_id AND p.valid_from >= @from AND p.valid_from < DATE_ADD(@to, INTERVAL 1 DAY)
GROUP BY p.permit_type WITH ROLLUP;

-- 3) 측정값 없이 승인된 허가: 켜진 MEASUREMENT 규칙이 요구하는 항목 중 작업 전(PRE_WORK) 측정이 없는 것
SELECT p.permit_no, p.permit_type, GROUP_CONCAT(req.item ORDER BY req.item) AS missing_items
FROM permits p
JOIN (SELECT work_type AS permit_type, SUBSTRING(target, 13) AS item FROM rules
      WHERE enabled = TRUE AND category = 'MEASUREMENT' AND target LIKE 'measurement.%' AND work_type IN ('HOT', 'CONFINED', 'HEIGHT')) req
  ON req.permit_type = p.permit_type
WHERE p.site_id = @site_id AND p.valid_from >= @from AND p.valid_from < DATE_ADD(@to, INTERVAL 1 DAY)
  AND EXISTS (SELECT 1 FROM approvals a WHERE a.target_type = 'PERMIT' AND a.target_id = p.id AND a.status = 'APPROVED')
  AND NOT EXISTS (SELECT 1 FROM permit_measurements m WHERE m.permit_id = p.id AND m.phase = 'PRE_WORK' AND m.item = req.item)
GROUP BY p.id, p.permit_no, p.permit_type ORDER BY p.permit_no;

-- 4) 차단 기록: 기간 안 공식 BLOCK 판정과 위반 규칙
SELECT p.permit_no, p.permit_type, e.evaluated_at, GROUP_CONCAT(r.rule_code ORDER BY v.id) AS rules, p.status AS current_status
FROM rule_evaluations e JOIN permits p ON p.id = e.target_id
     LEFT JOIN rule_violations v ON v.evaluation_id = e.id LEFT JOIN rules r ON r.id = v.rule_id
WHERE e.site_id = @site_id AND e.target_type = 'PERMIT' AND e.result = 'BLOCK' AND e.agent_run_id IS NULL
  AND e.evaluated_at >= @from AND e.evaluated_at < DATE_ADD(@to, INTERVAL 1 DAY)
GROUP BY e.id, p.permit_no, p.permit_type, e.evaluated_at, p.status ORDER BY e.evaluated_at;

-- 5) 지적사항 조치율: 기간 안에 등록된(created_at) 개선조치, 취소 제외. 조치율 = (완료+확인) ÷ 전체. 기한 경과는 오늘(CURDATE) 기준
SELECT COUNT(*) AS actions, SUM(status IN ('DONE', 'VERIFIED')) AS completed, SUM(status = 'VERIFIED') AS verified,
       COUNT(*) - SUM(status IN ('DONE', 'VERIFIED')) AS open_count,
       SUM(status IN ('OPEN', 'IN_PROGRESS') AND due_date < CURDATE()) AS overdue,
       ROUND(SUM(status IN ('DONE', 'VERIFIED')) * 100 / COUNT(*), 1) AS completion_rate
FROM corrective_actions
WHERE site_id = @site_id AND DATE(created_at) BETWEEN @from AND @to AND status <> 'CANCELED';
