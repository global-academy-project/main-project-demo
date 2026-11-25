import { useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import SafetyPageLayout from '../../components/safety-page-layout';
import PageHeader from '../../components/ui/page-header.jsx';
import StatusView from '../../components/ui/status-view.jsx';
import { useToast } from '../../components/ui/toast-context.js';
import { exportAuditReportHwpx, getAuditReport, retryAuditReportSummary, updateAuditReport } from '../../api/audit-reports.js';
import { STAT_LABELS, canExportHwpx, hwpxFileName, isAiDraftItem, isAiDraftSummary, reviewNotice, statEntries, verificationBadge } from '../../utils/audit-report-model.js';
import '../../styles/audit-reports.css';

// 요약 중(GENERATING)일 때 다시 조회하는 간격
const POLL_MS = 5000;

// AI가 쓴 글이 저장된 그대로인 칸에 붙이는 배지. 인쇄·PDF에는 찍지 않는다(HWPX 파일에도 표시하지 않음)
const AI_DRAFT_BADGE = <span className="audit-status audit-status--ai_draft audit-no-print">AI 초안</span>;

export default function AuditReportDetail() {
  return (
    <SafetyPageLayout title="감사 대응">
      {(site) => <Detail site={site} />}
    </SafetyPageLayout>
  );
}

function Detail({ site }) {
  const { reportId } = useParams();
  const navigate = useNavigate();
  const toast = useToast();
  const [report, setReport] = useState(null);
  // 서버에서 마지막으로 받은(저장된) 보고서. "AI 초안" 배지는 고치는 중인 값이 아니라 이 값으로 판정한다
  const [savedReport, setSavedReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState(false);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState('');
  const siteId = site.currentSite?.siteId;
  const allowed = site.account?.user?.role === 'ADMIN'
    || ['ADMIN', 'SITE_ADMIN'].includes(site.currentSite?.role);
  const generating = report?.status === 'GENERATING';

  useEffect(() => {
    if (!siteId || !allowed) return undefined;
    let active = true;
    getAuditReport(siteId, reportId)
      .then((data) => { if (active) { setReport(data); setSavedReport(data); } })
      .catch((requestError) => { if (active) setError(requestError.message || '감사 대응 보고서를 불러오지 못했습니다.'); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, [siteId, reportId, allowed]);

  // AI 요약이 끝날 때까지 다시 조회한다. 요약 중에는 편집을 막아 두므로 받은 값으로 바로 바꿔도 고친 내용이 사라지지 않는다.
  // 요약 중에도 받아 두는 것은 오래 멈추면 서버가 summaryRetryable 을 켜 주기 때문
  useEffect(() => {
    if (!generating || !siteId) return undefined;
    const timer = setInterval(() => {
      getAuditReport(siteId, reportId).then((data) => { setReport(data); setSavedReport(data); }).catch(() => {});
    }, POLL_MS);
    return () => clearInterval(timer);
  }, [generating, siteId, reportId]);

  // 인쇄·PDF 저장 때 파일 이름과 브라우저 제목이 "vite-project" 가 되지 않게 보고서 제목을 쓴다
  useEffect(() => {
    if (!report?.title) return undefined;
    const previous = document.title;
    document.title = report.title;
    return () => { document.title = previous; };
  }, [report?.title]);

  if (!allowed) {
    return <StatusView kind="forbidden" title="관리자만 감사 대응 보고서를 이용할 수 있습니다" />;
  }
  if (loading) {
    return <StatusView kind="loading" title="보고서를 불러오는 중입니다" />;
  }
  if (error || !report) {
    return (
      <StatusView
        kind="error"
        title="보고서를 불러오지 못했습니다"
        message={error}
        action={{ label: '목록으로', onClick: () => navigate('/audit-reports') }}
      />
    );
  }

  const items = Array.isArray(report.items) ? report.items : [];
  const edit = (patch) => { setReport({ ...report, ...patch }); setDirty(true); };

  const save = async () => {
    setSaving(true);
    try {
      const saved = await updateAuditReport(siteId, reportId, {
        title: report.title,
        summary: report.summary ?? null,
        items: items.map((item) => ({ queryType: item.queryType, summary: item.summary ?? '' })),
        lockVersion: report.lockVersion,
      });
      setReport(saved);
      setSavedReport(saved);
      setDirty(false);
      toast.show({ tone: 'success', message: '감사 대응 보고서를 저장했습니다.' });
    } catch (requestError) {
      const conflict = requestError.code === 'CONFLICT_MODIFIED';
      toast.show({ tone: 'error', message: conflict ? '다른 사람이 먼저 저장했습니다. 새로 고침한 뒤 다시 고쳐 주세요.' : requestError.message || '저장에 실패했습니다.' });
    } finally {
      setSaving(false);
    }
  };

  const retry = async () => {
    try {
      const retried = await retryAuditReportSummary(siteId, reportId);
      setReport(retried);
      setSavedReport(retried);
      toast.show({ tone: 'success', message: 'AI 요약을 다시 시작했습니다. 잠시 뒤 채워집니다.' });
    } catch (requestError) {
      toast.show({ tone: 'error', message: requestError.message || '다시 요약하지 못했습니다.' });
    }
  };

  const exportHwpx = async () => {
    setExporting(true);
    try {
      const response = await exportAuditReportHwpx(siteId, reportId);
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = hwpxFileName(response.headers.get('Content-Disposition'), report.reportId ?? reportId);
      document.body.appendChild(link);
      link.click();
      link.remove();
      setTimeout(() => URL.revokeObjectURL(url), 0);
    } catch (requestError) {
      toast.show({ tone: 'error', message: requestError.message || 'HWPX 파일을 내려받지 못했습니다.' });
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="audit-page">
      <PageHeader
        title={report.title || `감사 대응 보고서 #${reportId}`}
        description={`${report.dateFrom} ~ ${report.dateTo} · 만든 사람 ${report.createdByName ?? '-'}`}
        context={site}
        actions={(
          <>
            <Link className="ui-btn ui-btn--ghost" to="/audit-reports">목록</Link>
            <Link className="ui-btn ui-btn--ghost" to={`/records/actions?new=1&sourceType=AUDIT&sourceId=${report.reportId}`}>개선조치 등록</Link>
            <button type="button" className="ui-btn ui-btn--secondary" disabled={dirty} onClick={() => window.print()}>인쇄·PDF 저장</button>
            <button type="button" className="ui-btn ui-btn--secondary" disabled={exporting || !canExportHwpx(report, dirty)} onClick={exportHwpx}>{exporting ? 'HWPX 만드는 중…' : 'HWPX 저장'}</button>
            <button type="button" className="ui-btn ui-btn--primary" disabled={saving || generating || !dirty} onClick={save}>
              {saving ? '저장 중…' : '변경 저장'}
            </button>
          </>
        )}
      />

      <section className="audit-card">
        <div className="audit-card__head">
          <div>
            <h2>감사 대응 보고서</h2>
            <p>집계 수치는 만든 순간의 공식 기록 그대로이며 고칠 수 없습니다. 제목·종합 의견·항목별 요약만 고칠 수 있습니다.{dirty ? ' 저장하지 않은 변경이 있습니다(인쇄는 저장 후).' : ''}</p>
          </div>
          <span className={`audit-status audit-status--${String(report.status).toLowerCase()}`}>{report.statusLabel ?? report.status}</span>
        </div>

        {generating && !report.summaryRetryable && <p className="audit-notice" role="status">AI가 항목별 요약과 종합 의견 초안을 만드는 중입니다. 끝나면 이 화면이 저절로 바뀝니다.</p>}
        {generating && report.summaryRetryable && (
          <p className="audit-notice" role="alert">AI 요약이 너무 오래 걸리고 있습니다. 멈췄을 수 있으니 다시 요약해 주세요.
            <button type="button" className="ui-btn ui-btn--ghost" onClick={retry}>AI 요약 다시 하기</button></p>
        )}
        {report.status === 'FAILED' && (
          <p className="audit-notice" role="alert">AI 요약을 만들지 못했습니다{report.failureReason ? `: ${report.failureReason}` : ''}. 집계는 남아 있으니 직접 요약을 쓰거나 다시 요약하세요.
            {report.summaryRetryable && <button type="button" className="ui-btn ui-btn--ghost" onClick={retry}>AI 요약 다시 하기</button>}</p>
        )}
        {reviewNotice(report) && <p className="audit-notice" role="note">{reviewNotice(report)}</p>}

        <label className="audit-editor audit-no-print">
          제목
          <input maxLength={200} value={report.title ?? ''} disabled={generating} onChange={(event) => edit({ title: event.target.value })} />
        </label>
        <label className="audit-editor">
          <span className="audit-editor__label">종합 의견{isAiDraftSummary(savedReport) && AI_DRAFT_BADGE}</span>
          <textarea value={report.summary ?? ''} rows={5} disabled={generating} onChange={(event) => edit({ summary: event.target.value })} />
          <div className="audit-print-text">{report.summary ?? ''}</div>
        </label>

        <div className="audit-items">
          {items.map((item, index) => (
            <article className="audit-item" key={item.queryType ?? index}>
              <div className="audit-item__title">
                <h3>{item.title || item.queryType}</h3>
                <span className="audit-item__badges">
                  {isAiDraftItem(savedReport, item.queryType) && AI_DRAFT_BADGE}
                  {verificationBadge(item) && (
                    <span className={`audit-status audit-status--${verificationBadge(item).className}`}>{verificationBadge(item).label}</span>
                  )}
                </span>
              </div>
              <dl className="audit-stats">
                {statEntries(item.stats).map(([key, value]) => (
                  <div key={key}><dt>{STAT_LABELS[key] ?? key}</dt><dd>{value}</dd></div>
                ))}
              </dl>
              {item.verification?.mismatches?.length > 0 && (
                <ul className="audit-evidence">{item.verification.mismatches.map((text, i) => <li key={i}>불일치: {text}</li>)}</ul>
              )}
              <label className="audit-editor">
                요약
                <textarea
                  value={item.summary || ''}
                  disabled={generating}
                  onChange={(event) => edit({
                    items: items.map((current, itemIndex) => (itemIndex === index ? { ...current, summary: event.target.value } : current)),
                  })}
                  rows={4}
                />
                <div className="audit-print-text">{item.summary || ''}</div>
              </label>
              <p className={`audit-evidence${(item.evidence?.length ?? 0) === 0 && !item.truncated ? ' audit-no-print' : ''}`}>근거 기록 {item.evidence?.length ?? 0}건{item.truncated ? ` · 전체 ${item.total}건 중 일부만 담김` : ''}</p>
            </article>
          ))}
        </div>
      </section>
    </div>
  );
}
