# Spring Server

> [!NOTE]
> Korean version: [spring-server.README.kr.md](../docs/localization/spring-server.README.kr.md)

Spring Boot API for field safety management. It provides authentication, permissions, work records, approvals, notifications, and audit report services.

## Technology

- Java 17
- Spring Boot 4
- Gradle Wrapper
- MySQL and Flyway
- Spring Security and JWT

## Local Development

Java 17 and MySQL are required. Database settings are in `src/main/resources/application.yaml`.

```powershell
$env:JWT_SECRET = "<local-only-secret>"
.\gradlew.bat bootRun
```

The default local URL is `http://localhost:8080`.

## Build and Test

```powershell
.\gradlew.bat test
.\gradlew.bat bootJar
```

## API Documentation

- Swagger UI: `/swagger-ui/index.html`
- OpenAPI: `/v3/api-docs`
- Health: `/actuator/health`

## Database

Flyway applies SQL from `src/main/resources/db/migration/`. Add a new migration version instead of modifying an applied migration.

## Korean Documentation

- [Spring Server Korean README](../docs/localization/spring-server.README.kr.md)
