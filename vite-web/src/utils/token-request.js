/**
 * 메일 링크 토큰처럼 한 번만 쓸 수 있는 값으로 보내는 요청을 키마다 한 번만 보낸다.
 * React StrictMode(개발)는 useEffect 를 두 번 실행하므로, 그대로 두면 같은 토큰으로 요청이 두 번 가고
 * 두 번째 응답(이미 사용한 링크)이 화면에 남는다. 같은 키로 다시 부르면 첫 요청의 결과(Promise)를 그대로 돌려준다.
 * 페이지를 새로 열면(새로 고침) 기록이 비므로 그때는 다시 보낸다.
 */
export function oncePerKey(request) {
  const pending = new Map();
  return (key) => {
    if (!pending.has(key)) pending.set(key, Promise.resolve().then(() => request(key)));
    return pending.get(key);
  };
}

/** 토큰 요청 오류 → 화면 상태 (서버 AccountTokenService.consume 의 오류 코드) */
export function tokenErrorStatus(error) {
  if (error?.code === 'TOKEN_EXPIRED_LINK') return 'expired';
  if (error?.code === 'TOKEN_ALREADY_USED') return 'used';
  return 'invalid';
}
