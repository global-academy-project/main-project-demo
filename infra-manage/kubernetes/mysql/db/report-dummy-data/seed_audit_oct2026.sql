-- ============================================================================
-- 감사 대응 보고서용 더미 데이터: 2026-10-01 ~ 2026-10-31 (한 달치, 현장 1곳)
-- 대상: 작업 51건(취소 3 포함)·위험성평가·작업허가·승인·측정값·규칙 판정(차단)·개선조치
-- 표식: works.description / corrective_actions.description 이 '[SEED]' 로 시작, 구역 code 가 'SEED-', 판정 JSON 에 seed:true
-- 같은 현장에 두 번 실행하면 구역(SEED-Z1)에서 중복 오류로 멈춘다(그 전에는 아무것도 들어가지 않는다)
-- ============================================================================
SET NAMES utf8mb4;

-- 1) 대상 현장·사용자 (원하는 값이 있으면 숫자로 바꾼다)
SET @site_id = (SELECT id FROM sites WHERE active = TRUE ORDER BY id LIMIT 1);
SET @writer_id = COALESCE(
  (SELECT sm.user_id FROM site_members sm JOIN users u ON u.id = sm.user_id
    WHERE sm.site_id = @site_id AND sm.role = 'WRITER' AND sm.status = 'ACTIVE' AND u.status = 'ACTIVE' ORDER BY sm.user_id LIMIT 1),
  (SELECT sm.user_id FROM site_members sm JOIN users u ON u.id = sm.user_id
    WHERE sm.site_id = @site_id AND sm.status = 'ACTIVE' AND u.status = 'ACTIVE' ORDER BY sm.user_id LIMIT 1),
  (SELECT id FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' ORDER BY id LIMIT 1));
SET @approver_id = COALESCE(
  (SELECT sm.user_id FROM site_members sm JOIN users u ON u.id = sm.user_id
    WHERE sm.site_id = @site_id AND sm.role = 'APPROVER' AND sm.status = 'ACTIVE' AND u.status = 'ACTIVE' ORDER BY sm.user_id LIMIT 1),
  (SELECT sm.user_id FROM site_members sm JOIN users u ON u.id = sm.user_id
    WHERE sm.site_id = @site_id AND sm.role = 'SITE_ADMIN' AND sm.status = 'ACTIVE' AND u.status = 'ACTIVE' ORDER BY sm.user_id LIMIT 1),
  (SELECT id FROM users WHERE role = 'ADMIN' AND status = 'ACTIVE' ORDER BY id LIMIT 1),
  @writer_id);
SELECT @site_id AS site_id, (SELECT name FROM sites WHERE id = @site_id) AS site_name,
       @writer_id AS writer_id, @approver_id AS approver_id;

-- 2) 구역 (현장에 이미 구역이 있어도 쓰지 않고 시드 전용 구역 4개를 만든다)
INSERT INTO work_zones (site_id, code, name, zone_type, is_confined, hazard_note) VALUES (@site_id, 'SEED-Z1', '반응공정 A동', 'PROCESS', 0, NULL);
SET @z1 = LAST_INSERT_ID();
INSERT INTO work_zones (site_id, code, name, zone_type, is_confined, hazard_note) VALUES (@site_id, 'SEED-Z2', '저장탱크 구역', 'TANK', 1, NULL);
SET @z2 = LAST_INSERT_ID();
INSERT INTO work_zones (site_id, code, name, zone_type, is_confined, hazard_note) VALUES (@site_id, 'SEED-Z3', '배관 랙 구역', 'PIPE', 0, NULL);
SET @z3 = LAST_INSERT_ID();
INSERT INTO work_zones (site_id, code, name, zone_type, is_confined, hazard_note) VALUES (@site_id, 'SEED-Z4', '정비동', 'MAINT', 0, NULL);
SET @z4 = LAST_INSERT_ID();

-- 3) 작업 (51건: 일반 28·화기 13·밀폐 6·고소 4, 이 중 취소 3)
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-01', '반응기 주변 설비 일상점검', '[SEED] 반응기 주변 설비 일상점검', 'GENERAL', 0, '2026-10-01 09:00:00', '2026-10-01 17:00:00', 3, 'DONE', @writer_id);
SET @w_g01 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-01', '펌프 윤활유 교체', '[SEED] 펌프 윤활유 교체', 'GENERAL', 0, '2026-10-01 09:00:00', '2026-10-01 17:00:00', 3, 'DONE', @writer_id);
SET @w_g02 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-02', '배관 지지대 도장 보수', '[SEED] 배관 지지대 도장 보수', 'GENERAL', 0, '2026-10-02 09:00:00', '2026-10-02 17:00:00', 3, 'DONE', @writer_id);
SET @w_g03 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-02', '공구실 정리 및 재고 조사', '[SEED] 공구실 정리 및 재고 조사', 'GENERAL', 0, '2026-10-02 09:00:00', '2026-10-02 17:00:00', 3, 'DONE', @writer_id);
SET @w_g04 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-06', '냉각수 순환펌프 점검', '[SEED] 냉각수 순환펌프 점검', 'GENERAL', 0, '2026-10-06 09:00:00', '2026-10-06 17:00:00', 3, 'DONE', @writer_id);
SET @w_g05 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-06', '지게차 운행 전 점검', '[SEED] 지게차 운행 전 점검', 'GENERAL', 0, '2026-10-06 09:00:00', '2026-10-06 17:00:00', 3, 'DONE', @writer_id);
SET @w_g06 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-07', '배관 보온재 보수', '[SEED] 배관 보온재 보수', 'GENERAL', 0, '2026-10-07 09:00:00', '2026-10-07 17:00:00', 3, 'DONE', @writer_id);
SET @w_g07 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-07', '탱크 외벽 도장면 점검', '[SEED] 탱크 외벽 도장면 점검', 'GENERAL', 0, '2026-10-07 09:00:00', '2026-10-07 17:00:00', 3, 'REJECTED', @writer_id);
SET @w_g08 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-08', '계측기 교정 보조', '[SEED] 계측기 교정 보조', 'GENERAL', 0, '2026-10-08 09:00:00', '2026-10-08 17:00:00', 3, 'DONE', @writer_id);
SET @w_g09 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-08', '전기 패널 청소', '[SEED] 전기 패널 청소', 'GENERAL', 0, '2026-10-08 09:00:00', '2026-10-08 17:00:00', 3, 'DONE', @writer_id);
SET @w_g10 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-12', '야적장 자재 이동', '[SEED] 야적장 자재 이동', 'GENERAL', 0, '2026-10-12 09:00:00', '2026-10-12 17:00:00', 3, 'DONE', @writer_id);
SET @w_g11 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-12', '컨베이어 벨트 교체', '[SEED] 컨베이어 벨트 교체', 'GENERAL', 0, '2026-10-12 09:00:00', '2026-10-12 17:00:00', 3, 'DONE', @writer_id);
SET @w_g12 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-13', '소화기 점검 및 교체', '[SEED] 소화기 점검 및 교체', 'GENERAL', 0, '2026-10-13 09:00:00', '2026-10-13 17:00:00', 3, 'DONE', @writer_id);
SET @w_g13 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-14', '탱크 레벨 게이지 점검', '[SEED] 탱크 레벨 게이지 점검', 'GENERAL', 0, '2026-10-14 09:00:00', '2026-10-14 17:00:00', 3, 'DONE', @writer_id);
SET @w_g14 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-15', '안전 표지 교체', '[SEED] 안전 표지 교체', 'GENERAL', 0, '2026-10-15 09:00:00', '2026-10-15 17:00:00', 3, 'REJECTED', @writer_id);
SET @w_g15 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-16', '반응기 안전밸브 외관 점검', '[SEED] 반응기 안전밸브 외관 점검', 'GENERAL', 0, '2026-10-16 09:00:00', '2026-10-16 17:00:00', 3, 'DONE', @writer_id);
SET @w_g16 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-16', '폐기물 반출', '[SEED] 폐기물 반출', 'GENERAL', 0, '2026-10-16 09:00:00', '2026-10-16 17:00:00', 3, 'DONE', @writer_id);
SET @w_g17 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-19', '배관 누설 점검', '[SEED] 배관 누설 점검', 'GENERAL', 0, '2026-10-19 09:00:00', '2026-10-19 17:00:00', 3, 'DONE', @writer_id);
SET @w_g18 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-19', '작업장 바닥 도장', '[SEED] 작업장 바닥 도장', 'GENERAL', 0, '2026-10-19 09:00:00', '2026-10-19 17:00:00', 3, 'DONE', @writer_id);
SET @w_g19 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-20', '열교환기 외관 점검', '[SEED] 열교환기 외관 점검', 'GENERAL', 0, '2026-10-20 09:00:00', '2026-10-20 17:00:00', 3, 'PENDING', @writer_id);
SET @w_g20 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-21', '탱크 주변 방유제 정비', '[SEED] 탱크 주변 방유제 정비', 'GENERAL', 0, '2026-10-21 09:00:00', '2026-10-21 17:00:00', 3, 'DONE', @writer_id);
SET @w_g21 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-22', '수공구 정기 점검', '[SEED] 수공구 정기 점검', 'GENERAL', 0, '2026-10-22 09:00:00', '2026-10-22 17:00:00', 3, 'DONE', @writer_id);
SET @w_g22 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-23', '교반기 윤활 점검', '[SEED] 교반기 윤활 점검', 'GENERAL', 0, '2026-10-23 09:00:00', '2026-10-23 17:00:00', 3, 'DONE', @writer_id);
SET @w_g23 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-27', '배관 라벨 부착', '[SEED] 배관 라벨 부착', 'GENERAL', 0, '2026-10-27 09:00:00', '2026-10-27 17:00:00', 3, 'DONE', @writer_id);
SET @w_g24 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-28', '정비동 환기설비 청소', '[SEED] 정비동 환기설비 청소', 'GENERAL', 0, '2026-10-28 09:00:00', '2026-10-28 17:00:00', 3, 'DONE', @writer_id);
SET @w_g25 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-29', '공정 샘플링 포인트 정리', '[SEED] 공정 샘플링 포인트 정리', 'GENERAL', 0, '2026-10-29 09:00:00', '2026-10-29 17:00:00', 3, 'DONE', @writer_id);
SET @w_g26 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-08', '창고 선반 설치(일정 변경으로 취소)', '[SEED] 창고 선반 설치(일정 변경으로 취소)', 'GENERAL', 0, '2026-10-08 09:00:00', '2026-10-08 17:00:00', 3, 'CANCELED', @writer_id);
SET @w_gx1 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-14', '보온재 반입(발주 취소)', '[SEED] 보온재 반입(발주 취소)', 'GENERAL', 0, '2026-10-14 09:00:00', '2026-10-14 17:00:00', 3, 'CANCELED', @writer_id);
SET @w_gx2 = LAST_INSERT_ID();
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-01', '배관 플랜지 용접', '[SEED] 배관 플랜지 용접', 'HOT', 1, '2026-10-01 09:00:00', '2026-10-01 17:00:00', 4, 'DONE', @writer_id);
SET @w_h01 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h01, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-02', '배관 지지대 가스절단', '[SEED] 배관 지지대 가스절단', 'HOT', 1, '2026-10-02 09:00:00', '2026-10-02 17:00:00', 4, 'DONE', @writer_id);
SET @w_h02 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h02, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-06', '브래킷 제작 용접', '[SEED] 브래킷 제작 용접', 'HOT', 1, '2026-10-06 09:00:00', '2026-10-06 17:00:00', 4, 'DONE', @writer_id);
SET @w_h03 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h03, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-07', '배관 엘보 교체 용접', '[SEED] 배관 엘보 교체 용접', 'HOT', 1, '2026-10-07 09:00:00', '2026-10-07 17:00:00', 4, 'DONE', @writer_id);
SET @w_h04 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h04, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-08', '반응기 노즐 보수 용접', '[SEED] 반응기 노즐 보수 용접', 'HOT', 1, '2026-10-08 09:00:00', '2026-10-08 17:00:00', 4, 'DONE', @writer_id);
SET @w_h05 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h05, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-13', '그라인딩 및 용접 보수', '[SEED] 그라인딩 및 용접 보수', 'HOT', 1, '2026-10-13 09:00:00', '2026-10-13 17:00:00', 4, 'DONE', @writer_id);
SET @w_h06 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h06, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-15', '스팀 배관 용접', '[SEED] 스팀 배관 용접', 'HOT', 1, '2026-10-15 09:00:00', '2026-10-15 17:00:00', 4, 'DONE', @writer_id);
SET @w_h07 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h07, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-19', '지지대 가스절단', '[SEED] 지지대 가스절단', 'HOT', 1, '2026-10-19 09:00:00', '2026-10-19 17:00:00', 4, 'DONE', @writer_id);
SET @w_h08 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h08, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-21', '배관 밸브 교체 용접', '[SEED] 배관 밸브 교체 용접', 'HOT', 1, '2026-10-21 09:00:00', '2026-10-21 17:00:00', 4, 'DONE', @writer_id);
SET @w_h09 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h09, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-22', '열교환기 노즐 용접', '[SEED] 열교환기 노즐 용접', 'HOT', 1, '2026-10-22 09:00:00', '2026-10-22 17:00:00', 4, 'DONE', @writer_id);
SET @w_h10 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h10, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-26', '탱크 보강재 용접', '[SEED] 탱크 보강재 용접', 'HOT', 1, '2026-10-26 09:00:00', '2026-10-26 17:00:00', 4, 'DONE', @writer_id);
SET @w_h11 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h11, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-28', '반응기 배관 연결 용접', '[SEED] 반응기 배관 연결 용접', 'HOT', 1, '2026-10-28 09:00:00', '2026-10-28 17:00:00', 4, 'DONE', @writer_id);
SET @w_h12 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_h12, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z4, '2026-10-20', '용접 보수(자재 지연으로 취소)', '[SEED] 용접 보수(자재 지연으로 취소)', 'HOT', 1, '2026-10-20 09:00:00', '2026-10-20 17:00:00', 3, 'CANCELED', @writer_id);
SET @w_hx1 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_hx1, 'HOT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-06', '저장탱크 내부 청소', '[SEED] 저장탱크 내부 청소', 'CONFINED', 1, '2026-10-06 09:00:00', '2026-10-06 17:00:00', 4, 'DONE', @writer_id);
SET @w_c01 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c01, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-12', '탱크 내부 슬러지 제거', '[SEED] 탱크 내부 슬러지 제거', 'CONFINED', 1, '2026-10-12 09:00:00', '2026-10-12 17:00:00', 4, 'DONE', @writer_id);
SET @w_c02 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c02, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z1, '2026-10-15', '반응기 내부 점검', '[SEED] 반응기 내부 점검', 'CONFINED', 1, '2026-10-15 09:00:00', '2026-10-15 17:00:00', 4, 'DONE', @writer_id);
SET @w_c03 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c03, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-20', '탱크 내부 도장 전 점검', '[SEED] 탱크 내부 도장 전 점검', 'CONFINED', 1, '2026-10-20 09:00:00', '2026-10-20 17:00:00', 4, 'DONE', @writer_id);
SET @w_c04 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c04, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-23', '집수조 내부 청소', '[SEED] 집수조 내부 청소', 'CONFINED', 1, '2026-10-23 09:00:00', '2026-10-23 17:00:00', 4, 'DONE', @writer_id);
SET @w_c05 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c05, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z2, '2026-10-29', '저장탱크 내부 검사', '[SEED] 저장탱크 내부 검사', 'CONFINED', 1, '2026-10-29 09:00:00', '2026-10-29 17:00:00', 4, 'BLOCKED', @writer_id);
SET @w_c06 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_c06, 'CONFINED', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-07', '배관 랙 상부 점검', '[SEED] 배관 랙 상부 점검', 'HEIGHT', 1, '2026-10-07 09:00:00', '2026-10-07 17:00:00', 3, 'DONE', @writer_id);
SET @w_t01 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_t01, 'HEIGHT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-14', '크레인 레일 점검', '[SEED] 크레인 레일 점검', 'HEIGHT', 1, '2026-10-14 09:00:00', '2026-10-14 17:00:00', 3, 'DONE', @writer_id);
SET @w_t02 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_t02, 'HEIGHT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-22', '외벽 패널 보수 고소작업', '[SEED] 외벽 패널 보수 고소작업', 'HEIGHT', 1, '2026-10-22 09:00:00', '2026-10-22 17:00:00', 3, 'DONE', @writer_id);
SET @w_t03 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_t03, 'HEIGHT', 'USER');
INSERT INTO works (site_id, zone_id, work_date, title, description, work_type, is_high_risk, start_at, end_at, worker_count, status, writer_id) VALUES (@site_id, @z3, '2026-10-30', '지붕 패널 교체', '[SEED] 지붕 패널 교체', 'HEIGHT', 1, '2026-10-30 09:00:00', '2026-10-30 17:00:00', 3, 'PENDING', @writer_id);
SET @w_t04 = LAST_INSERT_ID();
INSERT INTO work_risk_factors (work_id, factor, detected_by) VALUES (@w_t04, 'HEIGHT', 'USER');

-- 4) 위험성평가 (작성 + 항목. 승인 후에는 항목을 못 넣으므로 DRAFT 로 만들고 항목을 넣은 뒤 상태를 바꾼다)
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g01, 1, '2026-10-01', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-01 07:40:00', '2026-10-01 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g02, 1, '2026-10-01', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'REJECTED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'REJECTED', '위험요인과 감소대책 보완 필요', '2026-10-01 07:40:00', '2026-10-01 08:30:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g02, 2, '2026-10-01', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-01 07:40:00', '2026-10-01 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g03, 1, '2026-10-02', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-02 07:40:00', '2026-10-02 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g05, 1, '2026-10-06', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-06 07:40:00', '2026-10-06 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g06, 1, '2026-10-06', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-06 07:40:00', '2026-10-06 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g07, 1, '2026-10-07', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-07 07:40:00', '2026-10-07 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g08, 1, '2026-10-07', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'REJECTED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'REJECTED', '위험요인과 감소대책 보완 필요', '2026-10-07 07:40:00', '2026-10-07 08:30:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g09, 1, '2026-10-08', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-08 07:40:00', '2026-10-08 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g10, 1, '2026-10-08', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-08 07:40:00', '2026-10-08 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g12, 1, '2026-10-12', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-12 07:40:00', '2026-10-12 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g13, 1, '2026-10-13', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-13 07:40:00', '2026-10-13 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g14, 1, '2026-10-14', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-14 07:40:00', '2026-10-14 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g15, 1, '2026-10-15', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'REJECTED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'REJECTED', '위험요인과 감소대책 보완 필요', '2026-10-15 07:40:00', '2026-10-15 08:30:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g16, 1, '2026-10-16', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-16 07:40:00', '2026-10-16 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g17, 1, '2026-10-16', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-16 07:40:00', '2026-10-16 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g18, 1, '2026-10-19', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-19 07:40:00', '2026-10-19 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g20, 1, '2026-10-20', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'PENDING' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, status, requested_at, due_at) VALUES (@site_id, 'RISK', @ra, @writer_id, 'PENDING', '2026-10-20 07:40:00', '2026-10-20 08:40:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g21, 1, '2026-10-21', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-21 07:40:00', '2026-10-21 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g22, 1, '2026-10-22', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-22 07:40:00', '2026-10-22 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g23, 1, '2026-10-23', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-23 07:40:00', '2026-10-23 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g24, 1, '2026-10-27', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-27 07:40:00', '2026-10-27 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g25, 1, '2026-10-28', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-28 07:40:00', '2026-10-28 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_g26, 1, '2026-10-29', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '작업 준비', '공구·자재 이동 중 넘어짐·끼임', NULL, 2, 2, 'LOW', '작업 전 통로 확보, 장갑·안전화 착용', 1, 1);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '점검·정비', '회전체 접촉에 의한 끼임', NULL, 2, 3, 'MEDIUM', '전원 차단·LOTO 후 작업, 방호덮개 확인', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-29 07:40:00', '2026-10-29 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h01, 1, '2026-10-01', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-01 07:40:00', '2026-10-01 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h02, 1, '2026-10-02', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-02 07:40:00', '2026-10-02 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h04, 1, '2026-10-07', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-07 07:40:00', '2026-10-07 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h05, 1, '2026-10-08', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-08 07:40:00', '2026-10-08 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h06, 1, '2026-10-13', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-13 07:40:00', '2026-10-13 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h07, 1, '2026-10-15', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-15 07:40:00', '2026-10-15 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h08, 1, '2026-10-19', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-19 07:40:00', '2026-10-19 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h09, 1, '2026-10-21', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-21 07:40:00', '2026-10-21 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h10, 1, '2026-10-22', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'REJECTED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'REJECTED', '위험요인과 감소대책 보완 필요', '2026-10-22 07:40:00', '2026-10-22 08:30:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h10, 2, '2026-10-22', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-22 07:40:00', '2026-10-22 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_h12, 1, '2026-10-28', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '용접·절단', '불티 비산에 의한 화재', NULL, 3, 4, 'HIGH', '방화포·소화기 비치, 화재감시자 배치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '가스 사용', '가연성 가스 체류에 의한 폭발', NULL, 2, 5, 'HIGH', '작업 전 가스 측정, 환기', 1, 4);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-28 07:40:00', '2026-10-28 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c01, 1, '2026-10-06', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-06 07:40:00', '2026-10-06 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c02, 1, '2026-10-12', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-12 07:40:00', '2026-10-12 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c03, 1, '2026-10-15', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-15 07:40:00', '2026-10-15 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c04, 1, '2026-10-20', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-20 07:40:00', '2026-10-20 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c05, 1, '2026-10-23', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-23 07:40:00', '2026-10-23 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_c06, 1, '2026-10-29', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '진입', '산소 결핍·유해가스 흡입', NULL, 3, 5, 'HIGH', '작업 전 적정공기 측정, 환기, 감시인 배치', 1, 4);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '내부 작업', '비상시 대피 지연', NULL, 2, 4, 'HIGH', '대피용 기구 비치, 비상 연락망 확인', 1, 3);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-29 07:40:00', '2026-10-29 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_t01, 1, '2026-10-07', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '고소 이동', '작업발판에서의 추락', NULL, 3, 4, 'HIGH', '안전대 착용, 추락방호망·안전난간 설치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '자재 인양', '낙하물에 의한 맞음', NULL, 2, 3, 'MEDIUM', '하부 출입통제, 낙하물 방지망 설치', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-07 07:40:00', '2026-10-07 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_t03, 1, '2026-10-22', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '고소 이동', '작업발판에서의 추락', NULL, 3, 4, 'HIGH', '안전대 착용, 추락방호망·안전난간 설치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '자재 인양', '낙하물에 의한 맞음', NULL, 2, 3, 'MEDIUM', '하부 출입통제, 낙하물 방지망 설치', 1, 2);
UPDATE risk_assessments SET status = 'APPROVED' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'RISK', @ra, @writer_id, @approver_id, 'APPROVED', '2026-10-22 07:40:00', '2026-10-22 08:15:00');
INSERT INTO risk_assessments (site_id, assessment_type, work_id, revision, assess_date, method, status, writer_id) VALUES (@site_id, 'DAILY', @w_t04, 1, '2026-10-30', 'FREQ_SEVERITY', 'DRAFT', @writer_id);
SET @ra = LAST_INSERT_ID();
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 1, '고소 이동', '작업발판에서의 추락', NULL, 3, 4, 'HIGH', '안전대 착용, 추락방호망·안전난간 설치', 1, 3);
INSERT INTO risk_assessment_items (assessment_id, seq, work_step, hazard, accident_type, frequency, severity, risk_level, controls, residual_frequency, residual_severity) VALUES (@ra, 2, '자재 인양', '낙하물에 의한 맞음', NULL, 2, 3, 'MEDIUM', '하부 출입통제, 낙하물 방지망 설치', 1, 2);
UPDATE risk_assessments SET status = 'PENDING' WHERE id = @ra;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, status, requested_at, due_at) VALUES (@site_id, 'RISK', @ra, @writer_id, 'PENDING', '2026-10-30 07:40:00', '2026-10-30 08:40:00');

-- 5) 작업허가·측정값·규칙 판정·승인 (측정값은 승인 전 단계에서만 넣을 수 있어 CHECKING/BLOCKED 로 만든 뒤 최종 상태로 바꾼다)
-- HOT-20261001-901 rev1 (배관 플랜지 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h01, 'HOT', 1, 'HOT-20261001-901', '2026-10-01 10:00:00', '2026-10-01 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h01_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-01 08:00:00', 'LEL', 2.0, 'PCT_LEL', '배관 랙 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-01 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-01 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-01 08:30:00', '2026-10-01 09:10:00');

-- HOT-20261002-901 rev1 (배관 지지대 가스절단) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h02, 'HOT', 1, 'HOT-20261002-901', '2026-10-02 10:00:00', '2026-10-02 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h02_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-02 08:00:00', 'LEL', 2.0, 'PCT_LEL', '정비동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-02 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-02 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-02 08:30:00', '2026-10-02 09:10:00');

-- HOT-20261006-901 rev1 (브래킷 제작 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h03, 'HOT', 1, 'HOT-20261006-901', '2026-10-06 10:00:00', '2026-10-06 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h03_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'LEL', 2.0, 'PCT_LEL', '정비동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-06 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-06 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-06 08:30:00', '2026-10-06 09:10:00');

-- HOT-20261007-901 rev1 (배관 엘보 교체 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h04, 'HOT', 1, 'HOT-20261007-901', '2026-10-07 10:00:00', '2026-10-07 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h04_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-07 08:00:00', 'LEL', 2.0, 'PCT_LEL', '배관 랙 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-07 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-07 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-07 08:30:00', '2026-10-07 09:10:00');

-- HOT-20261013-901 rev1 (그라인딩 및 용접 보수) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h06, 'HOT', 1, 'HOT-20261013-901', '2026-10-13 10:00:00', '2026-10-13 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h06_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-13 08:00:00', 'LEL', 2.0, 'PCT_LEL', '정비동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-13 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-13 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-13 08:30:00', '2026-10-13 09:10:00');

-- HOT-20261015-901 rev1 (스팀 배관 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h07, 'HOT', 1, 'HOT-20261015-901', '2026-10-15 10:00:00', '2026-10-15 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h07_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'LEL', 2.0, 'PCT_LEL', '배관 랙 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-15 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-15 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-15 08:30:00', '2026-10-15 09:10:00');

-- HOT-20261019-901 rev1 (지지대 가스절단) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h08, 'HOT', 1, 'HOT-20261019-901', '2026-10-19 10:00:00', '2026-10-19 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h08_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-19 08:00:00', 'LEL', 2.0, 'PCT_LEL', '정비동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-19 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-19 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-19 08:30:00', '2026-10-19 09:10:00');

-- HOT-20261021-901 rev1 (배관 밸브 교체 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h09, 'HOT', 1, 'HOT-20261021-901', '2026-10-21 10:00:00', '2026-10-21 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h09_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-21 08:00:00', 'LEL', 2.0, 'PCT_LEL', '배관 랙 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-21 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-21 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-21 08:30:00', '2026-10-21 09:10:00');

-- HOT-20261008-901 rev1 (반응기 노즐 보수 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h05, 'HOT', 1, 'HOT-20261008-901', '2026-10-08 10:00:00', '2026-10-08 17:00:00', 'BLOCKED', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h05_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-08 08:00:00', 'LEL', 2.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'BLOCK', '{"seed":true,"permitType":"HOT","form":{"watcher_name":null,"extinguisher_ready":false}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-08 07:40:00');
SET @e = LAST_INSERT_ID();
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, NULL, '지정 필요', severity, message, legal_basis FROM rules WHERE rule_code = 'HOT_FIRE_WATCHER' AND enabled = TRUE;
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, 'false', 'true', severity, message, legal_basis FROM rules WHERE rule_code = 'HOT_EXTINGUISHER' AND enabled = TRUE;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-08 08:20:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, watcher_name = '박안전', closed_at = '2026-10-08 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-08 08:30:00', '2026-10-08 09:10:00');

-- HOT-20261022-901 rev1 (열교환기 노즐 용접) → 최종 REJECTED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h10, 'HOT', 1, 'HOT-20261022-901', '2026-10-22 10:00:00', '2026-10-22 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h10_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-22 08:00:00', 'LEL', 2.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
UPDATE permits SET status = 'REJECTED' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'REJECTED', '작업 범위와 감시인 배치 보완 후 다시 신청', '2026-10-22 08:30:00', '2026-10-22 09:25:00');

-- HOT-20261022-901 rev2 (열교환기 노즐 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h10, 'HOT', 2, 'HOT-20261022-901', '2026-10-22 10:00:00', '2026-10-22 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h10_r2 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-22 08:00:00', 'LEL', 2.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":2.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-22 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-22 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-22 08:30:00', '2026-10-22 09:10:00');

-- HOT-20261026-901 rev1 (탱크 보강재 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h11, 'HOT', 1, 'HOT-20261026-901', '2026-10-26 10:00:00', '2026-10-26 17:00:00', 'CHECKING', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h11_r1 = @p;
UPDATE permits SET status = 'CLOSED', closed_at = '2026-10-26 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-26 08:30:00', '2026-10-26 09:10:00');

-- HOT-20261028-901 rev1 (반응기 배관 연결 용접) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_h12, 'HOT', 1, 'HOT-20261028-901', '2026-10-28 10:00:00', '2026-10-28 17:00:00', 'BLOCKED', '박안전', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_h12_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-28 07:30:00', 'LEL', 12.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-28 08:10:00', 'LEL', 4.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 1);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'BLOCK', '{"seed":true,"permitType":"HOT","measurement":{"LEL":12.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-28 07:40:00');
SET @e = LAST_INSERT_ID();
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, '12.0 %LEL', '10 %LEL 미만', severity, message, legal_basis FROM rules WHERE rule_code = 'HOT_LEL_MAX' AND enabled = TRUE;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HOT","measurement":{"LEL":4.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HOT', 'ALL')), '2026-10-28 08:20:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-28 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-28 08:30:00', '2026-10-28 09:10:00');

-- CONFINED-20261006-901 rev1 (저장탱크 내부 청소) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c01, 'CONFINED', 1, 'CONFINED-20261006-901', '2026-10-06 10:00:00', '2026-10-06 15:00:00', 'CHECKING', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c01_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'O2', 20.9, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'CO2', 0.04, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'CO', 2.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'H2S', 0.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-06 08:00:00', 'LEL', 0.0, 'PCT_LEL', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":20.9,"CO2":0.04,"CO":2.0,"H2S":0.0,"LEL":0.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-06 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-06 15:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-06 08:30:00', '2026-10-06 09:10:00');

-- CONFINED-20261012-901 rev1 (탱크 내부 슬러지 제거) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c02, 'CONFINED', 1, 'CONFINED-20261012-901', '2026-10-12 10:00:00', '2026-10-12 15:00:00', 'CHECKING', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c02_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-12 08:00:00', 'O2', 20.9, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-12 08:00:00', 'CO2', 0.04, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-12 08:00:00', 'CO', 2.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-12 08:00:00', 'H2S', 0.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-12 08:00:00', 'LEL', 0.0, 'PCT_LEL', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":20.9,"CO2":0.04,"CO":2.0,"H2S":0.0,"LEL":0.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-12 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-12 15:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-12 08:30:00', '2026-10-12 09:10:00');

-- CONFINED-20261015-901 rev1 (반응기 내부 점검) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c03, 'CONFINED', 1, 'CONFINED-20261015-901', '2026-10-15 10:00:00', '2026-10-15 15:00:00', 'CHECKING', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c03_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'O2', 20.9, 'PCT', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'CO2', 0.04, 'PCT', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'CO', 2.0, 'PPM', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'H2S', 0.0, 'PPM', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-15 08:00:00', 'LEL', 0.0, 'PCT_LEL', '반응공정 A동', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":20.9,"CO2":0.04,"CO":2.0,"H2S":0.0,"LEL":0.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-15 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-15 15:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-15 08:30:00', '2026-10-15 09:10:00');

-- CONFINED-20261020-901 rev1 (탱크 내부 도장 전 점검) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c04, 'CONFINED', 1, 'CONFINED-20261020-901', '2026-10-20 10:00:00', '2026-10-20 15:00:00', 'CHECKING', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c04_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-20 08:00:00', 'O2', 20.9, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-20 08:00:00', 'CO2', 0.04, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-20 08:00:00', 'LEL', 0.0, 'PCT_LEL', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
UPDATE permits SET status = 'CLOSED', closed_at = '2026-10-20 15:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-20 08:30:00', '2026-10-20 09:10:00');

-- CONFINED-20261023-901 rev1 (집수조 내부 청소) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c05, 'CONFINED', 1, 'CONFINED-20261023-901', '2026-10-23 10:00:00', '2026-10-23 15:00:00', 'BLOCKED', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c05_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 07:30:00', 'O2', 17.2, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 07:30:00', 'CO2', 0.04, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 07:30:00', 'CO', 2.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 07:30:00', 'H2S', 14.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 07:30:00', 'LEL', 0.0, 'PCT_LEL', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 08:10:00', 'O2', 20.8, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 1);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-23 08:10:00', 'H2S', 2.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 1);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'BLOCK', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":17.2,"H2S":14.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-23 07:40:00');
SET @e = LAST_INSERT_ID();
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, '17.2 %', '18 % 이상 23.5 % 미만', severity, message, legal_basis FROM rules WHERE rule_code = 'CONFINED_O2_RANGE' AND enabled = TRUE;
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, '14.0 ppm', '10 ppm 미만', severity, message, legal_basis FROM rules WHERE rule_code = 'CONFINED_H2S_MAX' AND enabled = TRUE;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":20.8,"CO2":0.04,"CO":2.0,"H2S":2.0,"LEL":0.0}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-23 08:20:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-23 15:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-23 08:30:00', '2026-10-23 09:10:00');

-- CONFINED-20261029-901 rev1 (저장탱크 내부 검사) → 최종 BLOCKED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_c06, 'CONFINED', 1, 'CONFINED-20261029-901', '2026-10-29 10:00:00', '2026-10-29 15:00:00', 'BLOCKED', '최감시', '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_c06_r1 = @p;
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-29 07:30:00', 'O2', 16.8, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-29 07:30:00', 'CO2', 0.04, 'PCT', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-29 07:30:00', 'CO', 2.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-29 07:30:00', 'H2S', 0.0, 'PPM', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO permit_measurements (permit_id, phase, measured_at, item, value, unit, location, measurer_name, instrument, is_remeasure) VALUES (@p, 'PRE_WORK', '2026-10-29 07:30:00', 'LEL', 0.0, 'PCT_LEL', '저장탱크 구역', '정측정', '복합가스검지기 GX-3R', 0);
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'BLOCK', '{"seed":true,"permitType":"CONFINED","measurement":{"O2":16.8}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('CONFINED', 'ALL')), '2026-10-29 07:40:00');
SET @e = LAST_INSERT_ID();
INSERT INTO rule_violations (evaluation_id, rule_id, actual_value, expected, severity, message, legal_basis) SELECT @e, id, '16.8 %', '18 % 이상 23.5 % 미만', severity, message, legal_basis FROM rules WHERE rule_code = 'CONFINED_O2_RANGE' AND enabled = TRUE;
UPDATE permits SET status = 'BLOCKED', last_evaluation_id = @e WHERE id = @p;

-- HEIGHT-20261007-901 rev1 (배관 랙 상부 점검) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_t01, 'HEIGHT', 1, 'HEIGHT-20261007-901', '2026-10-07 10:00:00', '2026-10-07 17:00:00', 'CHECKING', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_t01_r1 = @p;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HEIGHT","form":{"fall_protection":true,"helmet_worn":true,"harness_worn":true}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HEIGHT', 'ALL')), '2026-10-07 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-07 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, 'CANCELED', '2026-10-07 08:30:00', '2026-10-07 08:45:00');
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-07 08:50:00', '2026-10-07 09:30:00');

-- HEIGHT-20261014-901 rev1 (크레인 레일 점검) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_t02, 'HEIGHT', 1, 'HEIGHT-20261014-901', '2026-10-14 10:00:00', '2026-10-14 17:00:00', 'CHECKING', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_t02_r1 = @p;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HEIGHT","form":{"fall_protection":true,"helmet_worn":true,"harness_worn":true}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HEIGHT', 'ALL')), '2026-10-14 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-14 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-14 08:30:00', '2026-10-14 09:10:00');

-- HEIGHT-20261022-901 rev1 (외벽 패널 보수 고소작업) → 최종 CLOSED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_t03, 'HEIGHT', 1, 'HEIGHT-20261022-901', '2026-10-22 10:00:00', '2026-10-22 17:00:00', 'CHECKING', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_t03_r1 = @p;
INSERT INTO rule_evaluations (site_id, target_type, target_id, result, input_snapshot, rules_applied, evaluated_at) VALUES (@site_id, 'PERMIT', @p, 'PASS', '{"seed":true,"permitType":"HEIGHT","form":{"fall_protection":true,"helmet_worn":true,"harness_worn":true}}', (SELECT COUNT(*) FROM rules WHERE enabled = TRUE AND work_type IN ('HEIGHT', 'ALL')), '2026-10-22 08:10:00');
SET @e = LAST_INSERT_ID();
UPDATE permits SET status = 'CLOSED', last_evaluation_id = @e, closed_at = '2026-10-22 17:10:00' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'APPROVED', '2026-10-22 08:30:00', '2026-10-22 09:10:00');

-- HEIGHT-20261030-901 rev1 (지붕 패널 교체) → 최종 REJECTED
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_t04, 'HEIGHT', 1, 'HEIGHT-20261030-901', '2026-10-30 10:00:00', '2026-10-30 17:00:00', 'CHECKING', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_t04_r1 = @p;
UPDATE permits SET status = 'REJECTED' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, approver_id, status, comment, requested_at, decided_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, @approver_id, 'REJECTED', '작업 범위와 감시인 배치 보완 후 다시 신청', '2026-10-30 08:30:00', '2026-10-30 09:25:00');

-- HEIGHT-20261030-901 rev2 (지붕 패널 교체) → 최종 PENDING
INSERT INTO permits (site_id, work_id, permit_type, revision, permit_no, valid_from, valid_to, status, watcher_name, supervisor_name, writer_id) VALUES (@site_id, @w_t04, 'HEIGHT', 2, 'HEIGHT-20261030-901', '2026-10-30 10:00:00', '2026-10-30 17:00:00', 'CHECKING', NULL, '이현장', @writer_id);
SET @p = LAST_INSERT_ID();
SET @p_t04_r2 = @p;
UPDATE permits SET status = 'PENDING' WHERE id = @p;
INSERT INTO approvals (site_id, target_type, target_id, requested_by, status, requested_at, due_at) VALUES (@site_id, 'PERMIT', @p, @writer_id, 'PENDING', '2026-10-30 08:30:00', '2026-10-30 09:30:00');

-- 6) 개선조치 (기간 안 12건: 완료·확인 7, 미완료 5 중 기한 경과 3. 그리고 집계에서 빠져야 하는 3건: 취소 1, 전월 등록 1, 익월 등록 1)
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '화기작업 구역 소화기 배치 점검표 개정', '[SEED] 화기작업 구역 소화기 배치 점검표 개정', @writer_id, '2026-10-16', 'VERIFIED', '2026-10-14 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-16 11:00:00', @approver_id, '2026-10-02 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '가스검지기 교정 주기 관리대장 정비', '[SEED] 가스검지기 교정 주기 관리대장 정비', @writer_id, '2026-10-20', 'VERIFIED', '2026-10-15 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-19 11:00:00', @approver_id, '2026-10-06 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '화재감시자 지정 서식 항목 보완', '[SEED] 화재감시자 지정 서식 항목 보완', @writer_id, '2026-10-22', 'DONE', '2026-10-20 16:00:00', '현장 조치 완료, 사진 첨부', NULL, NULL, @approver_id, '2026-10-08 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '배관 랙 고소작업 추락방호망 보수', '[SEED] 배관 랙 고소작업 추락방호망 보수', @writer_id, '2026-10-26', 'VERIFIED', '2026-10-23 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-26 11:00:00', @approver_id, '2026-10-12 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '탱크 맨홀 출입 통제 표지 교체', '[SEED] 탱크 맨홀 출입 통제 표지 교체', @writer_id, '2026-10-28', 'VERIFIED', '2026-10-21 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-27 11:00:00', @approver_id, '2026-10-14 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '위험성평가 미작성 작업 보완 작성', '[SEED] 위험성평가 미작성 작업 보완 작성', @writer_id, '2026-10-30', 'DONE', '2026-10-28 16:00:00', '현장 조치 완료, 사진 첨부', NULL, NULL, @approver_id, '2026-10-16 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '작업 전 측정값 입력 누락 방지 절차 수립', '[SEED] 작업 전 측정값 입력 누락 방지 절차 수립', @writer_id, '2026-11-14', 'IN_PROGRESS', NULL, NULL, NULL, NULL, @approver_id, '2026-10-20 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '정비동 용접 구역 방화포 비치 확인', '[SEED] 정비동 용접 구역 방화포 비치 확인', @writer_id, '2026-11-05', 'VERIFIED', '2026-10-30 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-31 11:00:00', @approver_id, '2026-10-22 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '밀폐공간 감시인 교육 이수 현황 점검', '[SEED] 밀폐공간 감시인 교육 이수 현황 점검', @writer_id, '2026-12-05', 'IN_PROGRESS', NULL, NULL, NULL, NULL, @approver_id, '2026-10-23 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '밀폐공간 환기 설비 점검 및 재측정 기록 관리', '[SEED] 밀폐공간 환기 설비 점검 및 재측정 기록 관리', @writer_id, '2026-10-31', 'OPEN', NULL, NULL, NULL, NULL, @approver_id, '2026-10-26 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '고소작업 안전대 부착설비 보강', '[SEED] 고소작업 안전대 부착설비 보강', @writer_id, '2026-11-18', 'OPEN', NULL, NULL, NULL, NULL, @approver_id, '2026-10-27 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '작업허가 승인 전 측정값 확인 항목 추가', '[SEED] 작업허가 승인 전 측정값 확인 항목 추가', @writer_id, '2026-12-10', 'OPEN', NULL, NULL, NULL, NULL, @approver_id, '2026-10-29 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '중복 등록된 조치 건', '[SEED] 중복 등록된 조치 건', @writer_id, '2026-10-23', 'CANCELED', NULL, NULL, NULL, NULL, @approver_id, '2026-10-13 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '9월 점검 지적 조치(전월 등록)', '[SEED] 9월 점검 지적 조치(전월 등록)', @writer_id, '2026-10-10', 'VERIFIED', '2026-10-02 16:00:00', '현장 조치 완료, 사진 첨부', @approver_id, '2026-10-03 11:00:00', @approver_id, '2026-09-25 10:00:00');
INSERT INTO corrective_actions (site_id, source_type, source_id, title, description, assignee_id, due_date, status, completed_at, completion_note, verified_by, verified_at, created_by, created_at) VALUES (@site_id, 'OTHER', NULL, '11월 등록 조치(익월 등록)', '[SEED] 11월 등록 조치(익월 등록)', @writer_id, '2026-11-30', 'OPEN', NULL, NULL, NULL, NULL, @approver_id, '2026-11-03 10:00:00');

-- 끝. 아래로 현장·기간 집계를 확인한다 (seed_audit_oct2026_check.sql)
SELECT 'seed rows' AS what, (SELECT COUNT(*) FROM works WHERE description LIKE '[SEED]%' AND site_id = @site_id) AS works,
       (SELECT COUNT(*) FROM permits p JOIN works w ON w.id = p.work_id WHERE w.description LIKE '[SEED]%' AND w.site_id = @site_id) AS permits,
       (SELECT COUNT(*) FROM corrective_actions WHERE description LIKE '[SEED]%' AND site_id = @site_id) AS actions;
