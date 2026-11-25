"""감사 대응 보고서 내려받기(HWPX) API.

`POST /api/v1/agent/audit-report/export` — Spring이 저장된 보고서 값을 보내면 파일 바이트를 돌려준다.
성공 응답은 `{"success": true, "data"}` 봉투가 아니라 파일 그대로다(Spring이 그대로 내려준다). 실패는 기존 JSON 오류 봉투.
저장하지 않고, DB·모델을 쓰지 않는다. 끄기: 환경변수 AUDIT_EXPORT_HWPX=false (주소가 없어진다).
"""

from fastapi import APIRouter
from fastapi.responses import Response

from app.schemas.audit_export import AuditExportInput
from app.services.audit_export_service import HWPX_MEDIA_TYPE, content_disposition, export_report

router = APIRouter(prefix="/api/v1/agent", tags=["audit-export"])


@router.post(
    "/audit-report/export",
    response_class=Response,
    responses={200: {"content": {HWPX_MEDIA_TYPE: {}}, "description": "HWPX 파일"}},
)
def audit_report_export(body: AuditExportInput) -> Response:
    content = export_report(body)
    return Response(
        content=content,
        media_type=HWPX_MEDIA_TYPE,
        headers={"Content-Disposition": content_disposition(body)},
    )
