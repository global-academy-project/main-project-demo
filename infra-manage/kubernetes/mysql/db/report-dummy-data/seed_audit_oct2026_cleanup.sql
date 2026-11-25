-- ============================================================================
-- 더미 데이터 정리: seed_audit_oct2026.sql 이 넣은 행만 지운다 ('[SEED]' 표식·SEED- 구역·seed:true 판정)
--
-- 주의 1) 규칙 판정(rule_evaluations·rule_violations)은 감사 증거라 V9 트리거가 삭제를 막는다.
--        시드 판정 몇 줄을 지우려고 두 트리거를 잠깐 내렸다가 바로 다시 만든다(아래 '트리거 구간').
--        이 구간에서 오류로 멈추면 이 파일 맨 끝 'RESTORE' 의 CREATE TRIGGER 두 줄을 반드시 실행한다.
-- 주의 2) 시드로 만든 감사 대응 보고서(audit_reports)와 열람 기록(record_access_logs)은 지우지 않는다.
--        열람 기록은 삭제 금지이고, 보고서는 화면의 삭제 기능으로 지운다.
-- 주의 3) 이 현장에서 시드 이후에 사람이 시드 작업에 붙인 기록이 있으면 FK 오류로 멈춘다(아무것도 지우지 않은 채).
-- ============================================================================
SET NAMES utf8mb4;
SET @site_id = (SELECT id FROM sites WHERE active = TRUE ORDER BY id LIMIT 1);

CREATE TEMPORARY TABLE t_works   AS SELECT id FROM works WHERE site_id = @site_id AND description LIKE '[SEED]%';
CREATE TEMPORARY TABLE t_permits AS SELECT id FROM permits WHERE work_id IN (SELECT id FROM t_works);
CREATE TEMPORARY TABLE t_risks   AS SELECT id FROM risk_assessments WHERE work_id IN (SELECT id FROM t_works);
CREATE TEMPORARY TABLE t_evals   AS SELECT id FROM rule_evaluations WHERE site_id = @site_id AND target_type = 'PERMIT'
   AND target_id IN (SELECT id FROM t_permits) AND JSON_UNQUOTE(JSON_EXTRACT(input_snapshot, '$.seed')) = 'true';
SELECT (SELECT COUNT(*) FROM t_works) AS works, (SELECT COUNT(*) FROM t_permits) AS permits,
       (SELECT COUNT(*) FROM t_risks) AS risks, (SELECT COUNT(*) FROM t_evals) AS evaluations,
       (SELECT COUNT(*) FROM corrective_actions WHERE site_id = @site_id AND description LIKE '[SEED]%') AS actions;

DELETE FROM corrective_actions WHERE site_id = @site_id AND description LIKE '[SEED]%';
DELETE FROM approvals WHERE site_id = @site_id AND target_type = 'PERMIT' AND target_id IN (SELECT id FROM t_permits);
DELETE FROM approvals WHERE site_id = @site_id AND target_type = 'RISK' AND target_id IN (SELECT id FROM t_risks);
-- 측정값·체크리스트·평가 항목은 부모 행 삭제로 함께 지워진다 (ON DELETE CASCADE)
DELETE FROM permits WHERE id IN (SELECT id FROM t_permits);
DELETE FROM risk_assessments WHERE id IN (SELECT id FROM t_risks);

-- ---- 트리거 구간 시작 ----
DROP TRIGGER IF EXISTS trg_viol_no_delete;
DROP TRIGGER IF EXISTS trg_eval_no_delete;
DELETE FROM rule_violations WHERE evaluation_id IN (SELECT id FROM t_evals);
DELETE FROM rule_evaluations WHERE id IN (SELECT id FROM t_evals);
CREATE TRIGGER trg_eval_no_delete BEFORE DELETE ON rule_evaluations
FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rule_evaluations는 삭제할 수 없습니다';
CREATE TRIGGER trg_viol_no_delete BEFORE DELETE ON rule_violations
FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rule_violations는 삭제할 수 없습니다';
-- ---- 트리거 구간 끝 ----

DELETE FROM works WHERE id IN (SELECT id FROM t_works);   -- work_risk_factors 는 CASCADE
DELETE FROM work_zones WHERE site_id = @site_id AND code LIKE 'SEED-%';
DROP TEMPORARY TABLE t_works, t_permits, t_risks, t_evals;
SELECT 'done' AS cleanup,
       (SELECT COUNT(*) FROM works WHERE site_id = @site_id AND description LIKE '[SEED]%') AS works_left,
       (SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema = DATABASE()
          AND trigger_name IN ('trg_eval_no_delete', 'trg_viol_no_delete')) AS protect_triggers_present;   -- 2 여야 한다

-- ---- RESTORE (오류로 멈췄을 때만) ----
-- DROP TRIGGER IF EXISTS trg_eval_no_delete;
-- CREATE TRIGGER trg_eval_no_delete BEFORE DELETE ON rule_evaluations
-- FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rule_evaluations는 삭제할 수 없습니다';
-- DROP TRIGGER IF EXISTS trg_viol_no_delete;
-- CREATE TRIGGER trg_viol_no_delete BEFORE DELETE ON rule_violations
-- FOR EACH ROW SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'rule_violations는 삭제할 수 없습니다';
