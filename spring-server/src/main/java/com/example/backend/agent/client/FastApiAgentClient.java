package com.example.backend.agent.client;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;
import org.springframework.web.client.RestClientException;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 실제 AI 서버(main-ai-model) 호출. app.agent.client=fastapi 일 때만.
 *   POST {base-url}/api/v1/agent/work-register
 *   POST {base-url}/api/v1/agent/record-query
 *   POST {base-url}/api/v1/agent/near-miss-tag
 *   POST {base-url}/api/v1/agent/audit-report/export  (성공은 HWPX 파일 바이트 그대로, 실패는 아래 JSON 봉투)
 *   성공 {"success": true, "data": WorkRegisterResult}
 *   실패 {"success": false, "error": {"code", "message", "details"}, "steps": [...]}
 * 연결·응답 시간 제한은 application.yaml (app.agent.*). 토큰은 /internal 과 같은 값을 X-Internal-Token 으로 보낸다.
 */
@Component
@ConditionalOnProperty(name = "app.agent.client", havingValue = "fastapi")
public class FastApiAgentClient implements AgentClient {

    static final String WORK_REGISTER_PATH = "/api/v1/agent/work-register";
    static final String RECORD_QUERY_PATH = "/api/v1/agent/record-query";
    static final String AUDIT_REPORT_PATH = "/api/v1/agent/audit-report";
    static final String NEAR_MISS_TAG_PATH = "/api/v1/agent/near-miss-tag";
    static final String AUDIT_EXPORT_PATH = "/api/v1/agent/audit-report/export";
    /** HWPX 파일 한도. 보고서 하나(항목 5개)에 비해 넉넉한 값이며, 넘으면 잘못된 응답으로 본다 */
    static final int MAX_FILE_BYTES = 20 * 1024 * 1024;
    static final String HWPX_MEDIA_TYPE = "application/hwp+zip";
    private static final Logger log = LoggerFactory.getLogger(FastApiAgentClient.class);

    private final RestClient restClient;
    /** 파일 변환 전용 (응답 대기 시간이 요약보다 짧다: app.agent.export-read-timeout-seconds) */
    private final RestClient exportClient;
    private final JsonMapper jsonMapper;
    private final String token;

    @Autowired
    public FastApiAgentClient(@Value("${app.agent.base-url}") String baseUrl,
                              @Value("${app.agent.connect-timeout-seconds}") long connectTimeoutSeconds,
                              @Value("${app.agent.read-timeout-seconds}") long readTimeoutSeconds,
                              @Value("${app.agent.export-read-timeout-seconds:30}") long exportReadTimeoutSeconds,
                              @Value("${app.internal.token}") String token,
                              JsonMapper jsonMapper) {
        // uvicorn 은 HTTP/1.1 만 쓰므로 h2c 업그레이드를 막는다
        HttpClient httpClient = HttpClient.newBuilder()
                .version(HttpClient.Version.HTTP_1_1)
                .connectTimeout(Duration.ofSeconds(connectTimeoutSeconds))
                .build();
        this.restClient = client(baseUrl, httpClient, readTimeoutSeconds);
        this.exportClient = client(baseUrl, httpClient, exportReadTimeoutSeconds);
        this.jsonMapper = jsonMapper;
        this.token = token;
    }

    /** 파일 변환 대기 시간은 기본값(30초) */
    public FastApiAgentClient(String baseUrl, long connectTimeoutSeconds, long readTimeoutSeconds, String token,
                              JsonMapper jsonMapper) {
        this(baseUrl, connectTimeoutSeconds, readTimeoutSeconds, 30, token, jsonMapper);
    }

    private static RestClient client(String baseUrl, HttpClient httpClient, long readTimeoutSeconds) {
        JdkClientHttpRequestFactory factory = new JdkClientHttpRequestFactory(httpClient);
        factory.setReadTimeout(Duration.ofSeconds(readTimeoutSeconds));
        return RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    }

    @Override
    public AgentReply workRegister(WorkRegisterCall call) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("runId", call.runId());
        body.put("siteId", call.siteId());
        body.put("permitId", call.permitId());
        body.put("message", call.message());
        body.put("slots", call.slots());
        body.put("mode", call.mode());
        return post(WORK_REGISTER_PATH, body);
    }

    @Override
    public AgentReply recordQuery(RecordQueryCall call) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("runId", call.runId());
        body.put("siteId", call.siteId());
        body.put("message", call.message());
        body.put("context", call.context());
        body.put("mode", call.mode());
        return post(RECORD_QUERY_PATH, body);
    }

    @Override
    public AgentReply auditReport(Map<String, Object> body) {
        return post(AUDIT_REPORT_PATH, body);
    }

    @Override
    public AgentReply nearMissTag(NearMissTagCall call) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("runId", call.runId());
        body.put("siteId", call.siteId());
        body.put("nearMissId", call.nearMissId());
        body.put("title", call.title());
        body.put("description", call.description() == null ? "" : call.description());   // AI 서버는 문자열(기본 "")만 받는다
        body.put("immediateAction", call.immediateAction());
        body.put("zoneName", call.zoneName());
        body.put("workType", call.workType());
        return post(NEAR_MISS_TAG_PATH, body);
    }

    /**
     * 성공(2xx, JSON 이 아닌 본문)이면 바이트 그대로. 실패 봉투면 read() 와 같이 AgentCallException.
     * 2xx 인데 JSON 이 오거나 본문이 비었거나 너무 크면 AI_BAD_RESPONSE
     */
    @Override
    public AgentFile auditReportExport(Map<String, Object> body) {
        FileRaw raw;
        try {
            raw = exportClient.post().uri(AUDIT_EXPORT_PATH)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.parseMediaType(HWPX_MEDIA_TYPE), MediaType.APPLICATION_OCTET_STREAM, MediaType.APPLICATION_JSON)
                    .header("X-Internal-Token", token)
                    .body(jsonMapper.writeValueAsString(body))
                    .exchange((request, response) -> {
                        MediaType type = response.getHeaders().getContentType();
                        byte[] bytes = response.getBody().readNBytes(MAX_FILE_BYTES + 1);
                        return new FileRaw(response.getStatusCode().value(), type == null ? null : type.toString(), bytes);
                    });
        } catch (RestClientException e) {
            log.warn("AI 서버 호출 실패: path={} reason={}", AUDIT_EXPORT_PATH, e.getMessage());
            throw new AgentCallException("AI_UNAVAILABLE", "AI 서버에 연결할 수 없거나 응답 시간이 초과되었습니다.", null);
        }
        return readFile(raw);
    }

    AgentFile readFile(FileRaw raw) {
        boolean json = raw.contentType() != null && raw.contentType().toLowerCase().startsWith(MediaType.APPLICATION_JSON_VALUE);
        if (raw.status() >= 200 && raw.status() < 300 && !json) {
            if (raw.body().length == 0 || raw.body().length > MAX_FILE_BYTES) {
                log.warn("AI 서버 파일 응답 크기가 이상함: bytes={}", raw.body().length);
                throw new AgentCallException("AI_BAD_RESPONSE", "AI 서버가 돌려준 파일을 읽을 수 없습니다.", null);
            }
            return new AgentFile(raw.body(), raw.contentType() == null ? HWPX_MEDIA_TYPE : raw.contentType());
        }
        read(new Raw(raw.status(), new String(raw.body(), StandardCharsets.UTF_8)));
        // 2xx 인데 JSON 성공 봉투가 왔다: 파일이 아니다
        throw new AgentCallException("AI_BAD_RESPONSE", "AI 서버가 파일 대신 다른 응답을 돌려주었습니다.", null);
    }

    private AgentReply post(String path, Map<String, Object> body) {
        Raw raw;
        try {
            raw = restClient.post().uri(path)
                    .contentType(MediaType.APPLICATION_JSON)
                    .accept(MediaType.APPLICATION_JSON)
                    .header("X-Internal-Token", token)
                    .body(jsonMapper.writeValueAsString(body))
                    .exchange((request, response) -> new Raw(response.getStatusCode().value(),
                            new String(response.getBody().readAllBytes(), StandardCharsets.UTF_8)));
        } catch (RestClientException e) {
            log.warn("AI 서버 호출 실패: path={} reason={}", path, e.getMessage());
            throw new AgentCallException("AI_UNAVAILABLE", "AI 서버에 연결할 수 없거나 응답 시간이 초과되었습니다.", null);
        }
        return read(raw);
    }

    AgentReply read(Raw raw) {
        Envelope env;
        try {
            env = jsonMapper.readValue(raw.body(), Envelope.class);
        } catch (JacksonException e) {
            env = null;
        }
        if (env == null) {
            log.warn("AI 서버 응답 모양이 다름: status={}", raw.status());
            throw new AgentCallException("AI_BAD_RESPONSE", "AI 서버 응답을 읽을 수 없습니다. (HTTP " + raw.status() + ")", null);
        }
        if (raw.status() >= 200 && raw.status() < 300 && Boolean.TRUE.equals(env.success()) && env.data() != null
                && env.data().isObject()) {
            return new AgentReply(env.data());
        }
        String code = env.error() != null && env.error().code() != null ? env.error().code() : "AI_ERROR";
        String message = env.error() != null && env.error().message() != null && !env.error().message().isBlank()
                ? env.error().message() : "AI 서버 오류 (HTTP " + raw.status() + ")";
        throw new AgentCallException(code, message, env.steps() != null && env.steps().isArray() ? env.steps() : null);
    }

    record Raw(int status, String body) {
    }

    record FileRaw(int status, String contentType, byte[] body) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Envelope(Boolean success, JsonNode data, Error error, JsonNode steps) {
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    record Error(String code, String message) {
    }
}
