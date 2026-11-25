# Vite Web

> [!NOTE]
> Korean version: [vite-web.README.kr.md](../docs/localization/vite-web.README.kr.md)

React web application for the field safety management platform.

## Technology

- React 19
- React Router 7
- Vite 8
- Node.js 24

## Local Development

```powershell
npm ci
npm run dev
```

The development server uses `http://localhost:50001`. `/api` requests are forwarded to `http://localhost:8080` by default. Override the API target before starting Vite:

```powershell
$env:VITE_API_PROXY_TARGET = "http://localhost:60001"
npm run dev
```

## Validation

```powershell
npm run lint
npm run build
npm run preview
```

## Docker

The default Dockerfile runs the Vite preview server on port `50001`. Integrated Compose and Kubernetes configuration is maintained in [`infra-manage`](../infra-manage).

## Korean Documentation

- [Vite Web Korean README](../docs/localization/vite-web.README.kr.md)
