FROM node:18 AS builder
LABEL maintainer="Praveen.Guntu"
WORKDIR /app
COPY package*.json yarn* .
RUN yarn install
COPY . .
RUN yarn build

FROM nginx:latest
COPY --from=builder /app/build/ /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
