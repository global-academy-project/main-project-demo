// 감사 대응 보고서 화면 규칙: 집계 이름(서버 기록 조회 summary 키)과 검증 표시
export const STAT_LABELS = Object.freeze({
  count: '건수',
  works: '작업', written: '평가 작성', approved: '승인', missing: '미작성', rate: '실시율', approvedRate: '승인율',
  permits: '허가', requested: '승인 요청', rejected: '반려', canceled: '취소', blocked: '차단', approvalRate: '승인률',
  actions: '조치', completed: '완료', verified: '확인 완료', open: '미완료', overdue: '기한 지남', completionRate: '조치율',
});

export const VERIFICATION_LABELS = Object.freeze({ MATCH: '수치 일치', MISMATCH: '불일치' });

/** stats 객체 → [[키, 표시값]] (비율은 %, 값 없으면 -) */
export function statEntries(stats) {
  if (!stats || typeof stats !== 'object' || Array.isArray(stats)) return [];
  return Object.entries(stats)
    .filter(([, value]) => value === null || ['number', 'string', 'boolean'].includes(typeof value))
    .map(([key, value]) => {
      if (value === null || value === '') return [key, '-'];
      if (/rate$/i.test(key)) return [key, `${value}%`];
      return [key, String(value)];
    });
}

const ymd = (date) => `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;

/**
 * 만들기 화면의 기본 기간: 이번 달 1일 ~ 오늘 (브라우저 날짜 기준, 11/20).
 * toISOString() 은 UTC 라서 한국 시간에서는 1일이 전달 말일로, 오전 9시 전에는 오늘이 어제로 바뀌었다.
 */
export function defaultAuditPeriod(now = new Date()) {
  return { dateFrom: ymd(new Date(now.getFullYear(), now.getMonth(), 1)), dateTo: ymd(now) };
}

/**
 * "검토 필요" 안내 문구. 예전 요약(항목별 수치 검증)에서 불일치가 있었던 보고서(overallVerification=FAIL)만 불일치 안내,
 * 구성기 응답(11/20, 항목별 검증 없음)은 확인 요청. 검토 필요가 아니면 null.
 */
export function reviewNotice(report) {
  if (report?.status !== 'REVIEW_REQUIRED') return null;
  if (report.overallVerification === 'FAIL') return 'AI 요약의 수치가 집계와 맞지 않는 항목이 있습니다. 항목의 "불일치"를 확인하고 요약을 고쳐 주세요.';
  return 'AI가 집계를 바탕으로 만든 요약입니다. 항목별 요약과 집계를 확인하고, 필요하면 고쳐 저장해 주세요.';
}

/** HWPX 저장을 누를 수 있는 상태(Spring 허용 상태와 같다). 서버는 저장된 값으로 만들므로 저장하지 않은 변경이 있으면 막는다. */
export const HWPX_EXPORTABLE_STATUSES = Object.freeze(['DRAFT', 'REVIEW_REQUIRED']);

export function canExportHwpx(report, dirty) {
  return !dirty && HWPX_EXPORTABLE_STATUSES.includes(report?.status);
}

/** Content-Disposition 의 filename*=UTF-8''… 를 읽는다. 없거나 못 읽으면 audit-report-{id}.hwpx (이름 규칙은 Spring 한 곳에 둔다) */
export function hwpxFileName(disposition, reportId) {
  const fallback = `audit-report-${reportId}.hwpx`;
  const match = /filename\*\s*=\s*UTF-8''([^;]+)/i.exec(disposition ?? '');
  if (!match) return fallback;
  try {
    const name = decodeURIComponent(match[1].trim().replace(/^"|"$/g, ''));
    return name.trim() ? name : fallback;
  } catch {
    return fallback;
  }
}

const trimmed = (value) => (typeof value === 'string' ? value.trim() : '');

/**
 * 그 항목의 AI 원본 요약. Spring(AuditReportService.readReply)과 같은 규칙으로 합친다:
 * 구성기 응답 groups[].items[] 중 queryType 이 같은 항목의 sentences[].text 를 앞뒤 공백 제거 → 빈 문장 제외 → \n 으로 잇기.
 * 구성기 응답이 없거나 같은 항목이 없으면 null.
 */
export function aiItemDraft(composeResult, queryType) {
  const groups = Array.isArray(composeResult?.groups) ? composeResult.groups : [];
  for (const group of groups) {
    const found = (Array.isArray(group?.items) ? group.items : []).find((item) => item?.queryType === queryType);
    if (found) {
      return (Array.isArray(found.sentences) ? found.sentences : []).map((sentence) => trimmed(sentence?.text)).filter(Boolean).join('\n');
    }
  }
  return null;
}

/**
 * "AI 초안" 배지: 저장된 종합 의견이 AI 초안(composeResult.overall.draftText)과 같을 때. 둘 다 앞뒤 공백을 지우고 비교한다.
 * 저장된 값(서버에서 받은 보고서)을 넘긴다. 고쳐 저장하면 사라지고, 저장 전 고치는 동안에는 남는다.
 */
export function isAiDraftSummary(savedReport) {
  const compose = savedReport?.composeResult;
  const summary = trimmed(savedReport?.summary);
  return Boolean(compose && summary) && summary === trimmed(compose.overall?.draftText);
}

/** "AI 초안" 배지: 저장된 그 항목 요약이 AI 원본 요약(aiItemDraft)과 같을 때. 저장된 요약이 비었거나 원본이 없으면 false */
export function isAiDraftItem(savedReport, queryType) {
  const items = Array.isArray(savedReport?.items) ? savedReport.items : [];
  const summary = trimmed(items.find((item) => item?.queryType === queryType)?.summary);
  const draft = aiItemDraft(savedReport?.composeResult, queryType);
  return Boolean(summary) && draft !== null && summary === draft;
}

/** 항목 검증 배지: 검증 결과가 있을 때만 (예전 방식 응답 보고서용. 구성기 응답은 항목별 검증이 없어 배지를 보이지 않는다) */
export function verificationBadge(item) {
  const status = item?.verification?.status;
  if (!status) return null;
  return { className: String(status).toLowerCase(), label: VERIFICATION_LABELS[status] ?? status };
}
