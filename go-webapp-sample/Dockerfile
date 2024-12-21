FROM golang:latest AS builder
ENV GO111MODULE=on \
    CGO_ENABLED=0 \
    GOOS=linux \
    GOARCH=amd64
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY ./ ./
RUN go build -o webapp .

FROM alpine:latest
WORKDIR /app
COPY --from=builder /app/webapp .
EXPOSE 8080
CMD ["./webapp"]

