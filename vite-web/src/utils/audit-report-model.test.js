import test from 'node:test';
import assert from 'node:assert/strict';
import { statEntries, defaultAuditPeriod, reviewNotice, verificationBadge, canExportHwpx, hwpxFileName, aiItemDraft, isAiDraftSummary, isAiDraftItem } from './audit-report-model.js';

test('감사 대응 보고서 집계 표시: 비율은 %, 빈 값은 -, 목록·객체는 뺀다', () => {
  assert.deepEqual(statEntries({ works: 4, rate: 75.0, approvedRate: null, nested: { a: 1 }, list: [1] }),
    [['works', '4'], ['rate', '75%'], ['approvedRate', '-']]);
  assert.deepEqual(statEntries(null), []);
  assert.deepEqual(statEntries([1, 2]), []);
});

test('만들기 기본 기간은 브라우저 날짜로 이번 달 1일 ~ 오늘 (한국 시간 오전에도 UTC 로 하루 밀리지 않는다)', () => {
  assert.deepEqual(defaultAuditPeriod(new Date(2026, 10, 1, 0, 30)), { dateFrom: '2026-11-01', dateTo: '2026-11-01' });
  assert.deepEqual(defaultAuditPeriod(new Date(2026, 10, 20, 8, 59)), { dateFrom: '2026-11-01', dateTo: '2026-11-20' });
  assert.deepEqual(defaultAuditPeriod(new Date(2026, 0, 5, 23, 59)), { dateFrom: '2026-01-01', dateTo: '2026-01-05' });
});

test('검토 필요 안내: 예전 수치 불일치(FAIL)만 불일치 안내, 구성기 응답은 확인 요청, 다른 상태는 없음', () => {
  assert.match(reviewNotice({ status: 'REVIEW_REQUIRED', overallVerification: 'FAIL' }), /불일치/);
  const composed = reviewNotice({ status: 'REVIEW_REQUIRED', overallVerification: null });
  assert.doesNotMatch(composed, /불일치/);
  assert.match(composed, /확인/);
  assert.equal(reviewNotice({ status: 'DRAFT', overallVerification: 'PASS' }), null);
  assert.equal(reviewNotice(null), null);
});

test('항목 검증 배지는 검증 결과가 있을 때만 (구성기 응답은 배지 없음)', () => {
  assert.deepEqual(verificationBadge({ verification: { status: 'MATCH' } }), { className: 'match', label: '수치 일치' });
  assert.deepEqual(verificationBadge({ verification: { status: 'MISMATCH' } }), { className: 'mismatch', label: '불일치' });
  assert.equal(verificationBadge({ verification: null }), null);
  assert.equal(verificationBadge({}), null);
});
test('HWPX 저장: 초안·검토 필요일 때만, 저장하지 않은 변경이 있으면 막는다', () => {
  assert.equal(canExportHwpx({ status: 'DRAFT' }, false), true);
  assert.equal(canExportHwpx({ status: 'REVIEW_REQUIRED' }, false), true);
  assert.equal(canExportHwpx({ status: 'REVIEW_REQUIRED' }, true), false);
  for (const status of ['GENERATING', 'FAILED', undefined]) assert.equal(canExportHwpx({ status }, false), false);
  assert.equal(canExportHwpx(null, false), false);
});

test('HWPX 파일 이름: filename* 를 풀어 쓰고, 없거나 깨졌으면 audit-report-{id}.hwpx', () => {
  const header = "attachment; filename=\"audit-report-7.hwpx\"; filename*=UTF-8''%EA%B0%90%EC%82%AC%20%EB%B3%B4%EA%B3%A0%EC%84%9C%202026-10-01%20~%202026-10-31.hwpx";
  assert.equal(hwpxFileName(header, 7), '감사 보고서 2026-10-01 ~ 2026-10-31.hwpx');
  assert.equal(hwpxFileName("attachment; filename*=utf-8''a%20b.hwpx", 7), 'a b.hwpx');
  assert.equal(hwpxFileName(null, 7), 'audit-report-7.hwpx');
  assert.equal(hwpxFileName('attachment; filename="x.hwpx"', 7), 'audit-report-7.hwpx');
  assert.equal(hwpxFileName("attachment; filename*=UTF-8''%E0%A4%A", 7), 'audit-report-7.hwpx');
});

// "AI 초안" 배지: C 답신(11/23) 3장의 확인 4가지
const compose = {
  overall: { draftText: '  점검 기간은 2026-10-01 ~ 2026-10-31임.\n확인 필요: 미작성 6건임.  ' },
  groups: [
    { docNo: 1, items: [
      { queryType: 'risk_assessment_rate', sentences: [{ text: ' 첫 문장임. ' }, { text: '   ' }, { text: '' }, { text: '둘째 문장임.' }] },
      { queryType: 'permit_approval_statistics', sentences: [{ text: '허가 문장임.' }] },
    ] },
    { docNo: 2, items: [{ queryType: 'near_miss_count', sentences: [] }] },
  ],
};
const newReport = () => ({
  summary: '점검 기간은 2026-10-01 ~ 2026-10-31임.\n확인 필요: 미작성 6건임.',
  composeResult: compose,
  items: [
    { queryType: 'risk_assessment_rate', summary: '첫 문장임.\n둘째 문장임.' },
    { queryType: 'permit_approval_statistics', summary: '허가 문장임.' },
    { queryType: 'blocked_records', summary: '구성기에 없는 항목' },
  ],
});

test('AI 원본 항목 요약은 Spring 규칙(공백 제거 → 빈 문장 제외 → 줄바꿈)으로 합친다', () => {
  assert.equal(aiItemDraft(compose, 'risk_assessment_rate'), '첫 문장임.\n둘째 문장임.');
  assert.equal(aiItemDraft(compose, 'near_miss_count'), '');
  assert.equal(aiItemDraft(compose, 'blocked_records'), null);
  assert.equal(aiItemDraft(null, 'risk_assessment_rate'), null);
});

test('AI 초안 배지: 새 보고서는 종합 의견과 요약이 있는 항목에 보인다', () => {
  const report = newReport();
  assert.equal(isAiDraftSummary(report), true);
  assert.equal(isAiDraftItem(report, 'risk_assessment_rate'), true);
  assert.equal(isAiDraftItem(report, 'permit_approval_statistics'), true);
  assert.equal(isAiDraftItem(report, 'blocked_records'), false);
});

test('AI 초안 배지: 종합 의견만 고쳐 저장하면 종합 의견 배지만 사라진다', () => {
  const report = { ...newReport(), summary: '사람이 고친 의견' };
  assert.equal(isAiDraftSummary(report), false);
  assert.equal(isAiDraftItem(report, 'risk_assessment_rate'), true);
});

test('AI 초안 배지: 항목 하나를 고쳐 저장하면 그 카드 배지만 사라진다', () => {
  const report = newReport();
  report.items[0] = { ...report.items[0], summary: '첫 문장임.\n사람이 고친 둘째 문장.' };
  assert.equal(isAiDraftItem(report, 'risk_assessment_rate'), false);
  assert.equal(isAiDraftItem(report, 'permit_approval_statistics'), true);
  assert.equal(isAiDraftSummary(report), true);
});

test('AI 초안 배지: 예전 보고서(composeResult 없음)·빈 요약에는 보이지 않고, 수치 일치·불일치 배지는 그대로', () => {
  const old = { summary: '의견', composeResult: null, items: [{ queryType: 'risk_assessment_rate', summary: '요약', verification: { status: 'MATCH' } }] };
  assert.equal(isAiDraftSummary(old), false);
  assert.equal(isAiDraftItem(old, 'risk_assessment_rate'), false);
  assert.deepEqual(verificationBadge(old.items[0]), { className: 'match', label: '수치 일치' });
  const empty = { ...newReport(), summary: '   ' };
  empty.items[0] = { ...empty.items[0], summary: '' };
  assert.equal(isAiDraftSummary(empty), false);
  assert.equal(isAiDraftItem(empty, 'risk_assessment_rate'), false);
  assert.equal(isAiDraftSummary(null), false);
});
