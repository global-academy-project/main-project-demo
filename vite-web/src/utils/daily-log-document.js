const textOf = (value) => {
  if (value == null) return '';
  if (Array.isArray(value)) return value.map(textOf).filter(Boolean).join('\n');
  return String(value);
};

const firstValue = (...values) => values.find((value) => value != null && value !== '');
const WORK_TYPE_LABELS = Object.freeze({ GENERAL: '일반', HOT: '화기', CONFINED: '밀폐공간', HEIGHT: '고소' });
const EVIDENCE_TYPE_LABELS = Object.freeze({
  WORK: '작업', RISK: '위험성평가', PERMIT: '작업허가', TBM: 'TBM', INSPECTION: '점검표',
  DAILY_LOG: '안전일지', APPROVAL: '결재', CORRECTIVE_ACTION: '개선조치', NEAR_MISS: '아차사고',
});
const INTERNAL_STATE_CODES = '(?:APPROVAL_(?:REQUEST|RESULT|STATUS|REQUIRED)|WAITING_INPUT|IN_PROGRESS|IN_REVIEW|DRAFT|APPROVAL|PENDING|APPROVED|REJECTED|CANCELED|CANCELLED|CHECKING|BLOCKED|DONE|SUPERSEDED|CLOSED|WAITING|PROCESSING|FAILED|SUBMITTED|REQUESTED|REVOKED|SKIPPED)';
const INTERNAL_STATE_TOKEN = new RegExp(`\\b${INTERNAL_STATE_CODES}\\b`, 'g');
const LABELED_INTERNAL_STATE = new RegExp(`\\b(?:approval[_\\s-]*status|status)\\s*[:=]?\\s*${INTERNAL_STATE_CODES}\\b`, 'gi');
const LABELED_KOREAN_STATE = new RegExp(`(?:승인\\s*상태|상태)\\s*[:=]?\\s*${INTERNAL_STATE_CODES}\\b`, 'g');

function evidenceTypeLabel(value) {
  return Object.hasOwn(EVIDENCE_TYPE_LABELS, value)
    ? EVIDENCE_TYPE_LABELS[value]
    : cleanDailyLogEvidenceText(value);
}

export function cleanDailyLogEvidenceText(value) {
  return textOf(value)
    .replace(LABELED_INTERNAL_STATE, ' ')
    .replace(LABELED_KOREAN_STATE, ' ')
    .replace(INTERNAL_STATE_TOKEN, ' ')
    .replace(/\(\s*\)|\[\s*\]/g, ' ')
    .replace(/(?:\s*[·,;|/]\s*){2,}/g, ' · ')
    .replace(/^\s*[·,;|/]\s*|\s*[·,;|/]\s*$/g, '')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

export function cleanDailyLogEvidence(entries = []) {
  return (Array.isArray(entries) ? entries : []).map((item) => ({
    ...item,
    title: cleanDailyLogEvidenceText(item?.title),
    label: cleanDailyLogEvidenceText(item?.label),
    detail: cleanDailyLogEvidenceText(item?.detail),
    displayTargetType: evidenceTypeLabel(item?.targetType),
  })).filter((item) => item.title || item.label || item.detail || item.displayTargetType || item.targetId != null);
}

const countOf = (stats, key) => {
  const value = stats?.[key]?.total;
  return Number.isFinite(value) ? `${value}건` : '';
};

function workContentOf(source) {
  const stats = source?.stats || {};
  return [
    ['작업', countOf(stats, 'works')],
    ['작업허가', countOf(stats, 'permits')],
    ['TBM', countOf(stats, 'tbm')],
    ['점검표', countOf(stats, 'inspections')],
  ].filter(([, value]) => value).map(([label, value]) => `${label} ${value}`).join('\n');
}

function riskFactorsOf(source) {
  return (Array.isArray(source?.checks) ? source.checks : [])
    .map((item) => {
      const label = item?.label || item?.type;
      return label && item?.count != null ? `${label}: ${item.count}건` : '';
    })
    .filter(Boolean)
    .join('\n');
}

function evidenceOf(source) {
  return (Array.isArray(source?.evidence) ? source.evidence : [])
    .map((item) => {
      const targetType = evidenceTypeLabel(item?.targetType);
      const target = targetType && item?.targetId != null ? `${targetType} #${item.targetId}` : '';
      const title = cleanDailyLogEvidenceText(item?.title) || target;
      const detail = cleanDailyLogEvidenceText(item?.detail);
      return [title, detail].filter(Boolean).join(' · ');
    })
    .filter(Boolean)
    .join('\n');
}

function tbmPhotoEvidenceOf(photos) {
  return (Array.isArray(photos) ? photos : [])
    .map((photo) => {
      const id = photo?.attachmentId != null ? `사진 #${photo.attachmentId}` : 'TBM 사진';
      const takenAt = photo?.takenAt ? `촬영 ${String(photo.takenAt).replace('T', ' ').slice(0, 16)}` : '촬영 시각 없음';
      const result = photo?.check?.result ? ` · ${photo.check.result}` : '';
      return `${id} · ${takenAt}${result}`;
    })
    .filter(Boolean)
    .join('\n');
}

/** API 초안 JSON을 공사안전 점검일지 인쇄 양식의 고정 필드로 변환합니다. */
export function normalizeDailyLogDocument(log, context = {}) {
  const source = log?.content || log?.document?.content || log?.document || log || {};
  const user = context.user || {};
  const site = context.site || {};
  const workTypes = [...new Set((context.workTypes || source.workTypes || [])
    .map((type) => WORK_TYPE_LABELS[type] || type)
    .filter(Boolean))];

  return {
    siteName: textOf(firstValue(source.siteName, source.site_name, site.name)),
    workerName: textOf(firstValue(source.workerName, source.worker_name, source.writerName, source.writer_name, user.name)),
    birthDate: textOf(firstValue(source.birthDate, source.birth_date)),
    position: textOf(firstValue(source.position, user.jobTitle)),
    company: textOf(firstValue(source.company, user.department)),
    workType: textOf(firstValue(source.workType, source.work_type, workTypes.join(', '))),
    healthStatus: textOf(firstValue(source.healthStatus, source.health_status)),
    specialNotes: textOf(firstValue(source.specialNotes, source.special_notes)),
    workContent: textOf(firstValue(source.workContent, source.work_content, workContentOf(source))),
    safetyRules: textOf(firstValue(source.safetyRules, source.safety_rules)),
    riskFactors: textOf(firstValue(source.riskFactors, source.risk_factors, riskFactorsOf(source))),
    aiSummary: textOf(firstValue(
      source.aiSummary,
      source.ai_summary,
      source.summary,
    )),
    evidence: tbmPhotoEvidenceOf(context.tbmPhotos) || evidenceOf(source),
  };
}

export function missingDailyLogDocumentFields() {
  // Spring 응답에 없는 양식 필드는 빈칸으로 출력하며 인쇄를 막지 않는다.
  return [];
}

