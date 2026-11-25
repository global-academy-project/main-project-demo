FROM node:24.0.2-slim AS build

WORKDIR /app

COPY package*.json ./

RUN npm ci

COPY . .

RUN npm run build

# -------------------------------[ Build Stage to Nginx Stage ]-------------------------------
FROM nginx:1.27-alpine

# kubernetes Nginx Conf 파일만 사용하기 때문에 compose용 Nginx Conf는 복사하지 않음
COPY nginx.kubernetes.conf /etc/nginx/conf.d/nginx.kubernetes.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 50001

# -------------------------------[ End of Dockerfile ]-------------------------------