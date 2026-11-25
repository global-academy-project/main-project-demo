package com.example.backend.agent.client;

import com.sun.net.httpserver.HttpServer;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import tools.jackson.databind.json.JsonMapper;

import java.io.IOException;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.atomic.AtomicReference;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/** 실제 HTTP 로 가짜 AI 서버(JDK 내장 서버)를 불러 요청 모양·응답 읽기·오류 변환을 확인 */
@DisplayName("FastApiAgentClient: AI 서버 호출")
class FastApiAgentClientTest {

    private static final String TOKEN = "t".repeat(32);
    private final JsonMapper jsonMapper = JsonMapper.builder().build();
    private HttpServer server;

    @AfterEach
    void stop() {
        if (server != null) server.stop(0);
    }

    private FastApiAgentClient start(int status, String body, AtomicReference<String> seenBody,
                                     AtomicReference<String> seenToken) throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        for (String path : new String[]{FastApiAgentClient.WORK_REGISTER_PATH, FastApiAgentClient.RECORD_QUERY_PATH}) {
            server.createContext(path, ex -> {
                seenBody.set(ex.getRequestURI().getPath() + " " + new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
                seenToken.set(ex.getRequestHeaders().getFirst("X-Internal-Token"));
                byte[] out = body.getBytes(StandardCharsets.UTF_8);
                ex.getResponseHeaders().add("Content-Type", "application/json");
                ex.sendResponseHeaders(status, out.length);
                ex.getResponseBody().write(out);
                ex.close();
            });
        }
        server.start();
        return new FastApiAgentClient("http://127.0.0.1:" + server.getAddress().getPort(), 2, 5, TOKEN, jsonMapper);
    }

    @Test
    @DisplayName("성공: 요청에 runId·siteId·slots·mode, 토큰 헤더. 응답 data 를 그대로 돌려줌")
    void success() throws IOException {
        AtomicReference<String> body = new AtomicReference<>();
        AtomicReference<String> token = new AtomicReference<>();
        FastApiAgentClient client = start(200,
                "{\"success\":true,\"data\":{\"runStatus\":\"WAITING_INPUT\",\"slots\":{\"askedKeys\":[\"location\"]}}}",
                body, token);

        AgentReply reply = client.workRegister(new WorkRegisterCall(345L, 5L, null, "용접 작업",
                jsonMapper.readTree("{\"askedKeys\":[\"x\"],\"future\":1}"), "VERIFY"));

        assertThat(jsonMapper.writeValueAsString(reply.data())).contains("\"runStatus\":\"WAITING_INPUT\"");
        assertThat(jsonMapper.writeValueAsString(reply.data().get("slots"))).contains("location");
        assertThat(token.get()).isEqualTo(TOKEN);
        assertThat(body.get()).contains("\"runId\":345", "\"siteId\":5", "\"permitId\":null", "\"mode\":\"VERIFY\"",
                "\"future\":1");   // slots 안의 모르는 필드도 그대로 전달
    }

    @Test
    @DisplayName("기록 질문: record-query 경로에 runId·siteId·message·context·mode")
    void recordQuery() throws IOException {
        AtomicReference<String> body = new AtomicReference<>();
        FastApiAgentClient client = start(200,
                "{\"success\":true,\"data\":{\"runStatus\":\"DONE\",\"answer\":\"0건입니다.\"}}",
                body, new AtomicReference<>());

        AgentReply reply = client.recordQuery(new RecordQueryCall(77L, 5L, "지난달 차단된 허가 있어?",
                jsonMapper.readTree("{\"turns\":1}"), "GUIDE"));

        assertThat(reply.data().get("answer").asString()).isEqualTo("0건입니다.");
        assertThat(body.get()).startsWith(FastApiAgentClient.RECORD_QUERY_PATH)
                .contains("\"runId\":77", "\"siteId\":5", "\"context\":{\"turns\":1}", "\"mode\":\"GUIDE\"");
    }

    @Test
    @DisplayName("실패 응답: error.code 와 그때까지의 steps 를 AgentCallException 으로")
    void errorWithSteps() throws IOException {
        FastApiAgentClient client = start(503,
                "{\"success\":false,\"error\":{\"code\":\"LLM_UNAVAILABLE\",\"message\":\"모델 응답 없음\",\"details\":[]},"
                        + "\"steps\":[{\"seq\":1,\"kind\":\"TOOL\",\"name\":\"classify_work\",\"toolName\":\"classify_work\",\"status\":\"OK\"}]}",
                new AtomicReference<>(), new AtomicReference<>());

        assertThatThrownBy(() -> client.workRegister(new WorkRegisterCall(1L, 1L, null, "m", null, "VERIFY")))
                .isInstanceOfSatisfying(AgentCallException.class, e -> {
                    assertThat(e.getCode()).isEqualTo("LLM_UNAVAILABLE");
                    assertThat(e.getMessage()).isEqualTo("모델 응답 없음");
                    assertThat(e.getSteps().isArray()).isTrue();
                });
    }

    @Test
    @DisplayName("응답이 JSON 이 아니면 AI_BAD_RESPONSE")
    void badResponse() throws IOException {
        FastApiAgentClient client = start(502, "<html>bad gateway</html>", new AtomicReference<>(), new AtomicReference<>());

        assertThatThrownBy(() -> client.workRegister(new WorkRegisterCall(1L, 1L, null, "m", null, "VERIFY")))
                .isInstanceOfSatisfying(AgentCallException.class, e -> assertThat(e.getCode()).isEqualTo("AI_BAD_RESPONSE"));
    }

    @Test
    @DisplayName("연결 실패면 AI_UNAVAILABLE")
    void unavailable() throws IOException {
        int port;
        try (java.net.ServerSocket s = new java.net.ServerSocket(0)) {   // 비어 있는 포트만 받고 바로 닫음
            port = s.getLocalPort();
        }
        FastApiAgentClient client = new FastApiAgentClient("http://127.0.0.1:" + port, 1, 2, TOKEN, jsonMapper);

        assertThatThrownBy(() -> client.workRegister(new WorkRegisterCall(1L, 1L, null, "m", null, "VERIFY")))
                .isInstanceOfSatisfying(AgentCallException.class, e -> assertThat(e.getCode()).isEqualTo("AI_UNAVAILABLE"));
    }

    /** HWPX 변환 주소만 여는 서버. 받은 요청 본문을 seenBody 에 */
    private FastApiAgentClient startExport(int status, String contentType, byte[] body, AtomicReference<String> seenBody)
            throws IOException {
        server = HttpServer.create(new InetSocketAddress("127.0.0.1", 0), 0);
        server.createContext(FastApiAgentClient.AUDIT_EXPORT_PATH, ex -> {
            seenBody.set(new String(ex.getRequestBody().readAllBytes(), StandardCharsets.UTF_8));
            ex.getResponseHeaders().add("Content-Type", contentType);
            ex.sendResponseHeaders(status, body.length == 0 ? -1 : body.length);
            if (body.length > 0) ex.getResponseBody().write(body);
            ex.close();
        });
        server.start();
        return new FastApiAgentClient("http://127.0.0.1:" + server.getAddress().getPort(), 2, 5, 5, TOKEN, jsonMapper);
    }

    @Test
    @DisplayName("HWPX 변환: 성공이면 파일 바이트와 Content-Type 을 그대로")
    void exportFile() throws IOException {
        AtomicReference<String> body = new AtomicReference<>();
        byte[] zip = {0x50, 0x4b, 0x03, 0x04, 1, 2, 3};
        FastApiAgentClient client = startExport(200, "application/hwp+zip", zip, body);

        AgentFile file = client.auditReportExport(java.util.Map.of("format", "HWPX", "reportId", 6));

        assertThat(file.content()).isEqualTo(zip);
        assertThat(file.contentType()).isEqualTo("application/hwp+zip");
        assertThat(body.get()).contains("\"format\":\"HWPX\"", "\"reportId\":6");
    }

    @Test
    @DisplayName("HWPX 변환: 실패 봉투면 error.code 로 AgentCallException")
    void exportError() throws IOException {
        FastApiAgentClient client = startExport(503, "application/json",
                "{\"success\":false,\"error\":{\"code\":\"SERVICE_UNAVAILABLE\",\"message\":\"HWPX 파일을 만들 수 없는 환경입니다.\"}}"
                        .getBytes(StandardCharsets.UTF_8), new AtomicReference<>());

        assertThatThrownBy(() -> client.auditReportExport(java.util.Map.of("reportId", 6)))
                .isInstanceOfSatisfying(AgentCallException.class, e -> {
                    assertThat(e.getCode()).isEqualTo("SERVICE_UNAVAILABLE");
                    assertThat(e.getMessage()).isEqualTo("HWPX 파일을 만들 수 없는 환경입니다.");
                });
    }

    @Test
    @DisplayName("HWPX 변환: 성공인데 JSON 이 오거나 본문이 비면 AI_BAD_RESPONSE")
    void exportNotAFile() throws IOException {
        FastApiAgentClient client = startExport(200, "application/json",
                "{\"success\":true,\"data\":{}}".getBytes(StandardCharsets.UTF_8), new AtomicReference<>());
        assertThatThrownBy(() -> client.auditReportExport(java.util.Map.of("reportId", 6)))
                .isInstanceOfSatisfying(AgentCallException.class, e -> assertThat(e.getCode()).isEqualTo("AI_BAD_RESPONSE"));

        stop();
        FastApiAgentClient empty = startExport(200, "application/hwp+zip", new byte[0], new AtomicReference<>());
        assertThatThrownBy(() -> empty.auditReportExport(java.util.Map.of("reportId", 6)))
                .isInstanceOfSatisfying(AgentCallException.class, e -> assertThat(e.getCode()).isEqualTo("AI_BAD_RESPONSE"));
    }
}
