package com.example.backend.agent.client;

/** AI 서버가 돌려준 파일 (감사 대응 보고서 HWPX 등). JSON 봉투 없이 받은 바이트 그대로 */
public record AgentFile(byte[] content, String contentType) {
}
