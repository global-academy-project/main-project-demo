import assert from 'node:assert/strict';
import test from 'node:test';
import { oncePerKey, tokenErrorStatus } from './token-request.js';

test('같은 토큰으로 두 번 불러도 요청은 한 번만 가고 같은 결과를 받는다 (StrictMode 두 번 실행)', async () => {
  const calls = [];
  const send = oncePerKey(async (token) => { calls.push(token); return 'ok'; });
  const [a, b] = await Promise.all([send('t1'), send('t1')]);
  assert.deepEqual(calls, ['t1']);
  assert.equal(a, 'ok');
  assert.equal(b, 'ok');
});

test('첫 요청이 실패하면 두 번째 호출도 같은 오류를 받고 다시 보내지 않는다', async () => {
  let count = 0;
  const send = oncePerKey(async () => { count += 1; throw Object.assign(new Error('만료'), { code: 'TOKEN_EXPIRED_LINK' }); });
  await assert.rejects(send('t1'), { code: 'TOKEN_EXPIRED_LINK' });
  await assert.rejects(send('t1'), { code: 'TOKEN_EXPIRED_LINK' });
  assert.equal(count, 1);
});

test('다른 토큰은 따로 보낸다', async () => {
  const calls = [];
  const send = oncePerKey(async (token) => { calls.push(token); });
  await send('t1'); await send('t2');
  assert.deepEqual(calls, ['t1', 't2']);
});

test('요청 함수가 바로 예외를 던져도 Promise 거절로 돌려준다', async () => {
  const send = oncePerKey(() => { throw new Error('동기 오류'); });
  await assert.rejects(send('t1'), /동기 오류/);
});

test('오류 코드 → 화면 상태: 만료·이미 사용·그 밖은 잘못된 링크', () => {
  assert.equal(tokenErrorStatus({ code: 'TOKEN_EXPIRED_LINK' }), 'expired');
  assert.equal(tokenErrorStatus({ code: 'TOKEN_ALREADY_USED' }), 'used');
  assert.equal(tokenErrorStatus({ code: 'TOKEN_INVALID' }), 'invalid');
  assert.equal(tokenErrorStatus({ code: 'CONFLICT' }), 'invalid');
  assert.equal(tokenErrorStatus(undefined), 'invalid');
});
