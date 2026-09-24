FROM golang:1.27-alpine AS builder 
WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download 

COPY . . 
RUN CGO_ENABLED=0 go build -o /app/server main.go

FROM alpine:3.20
RUN adduser -D -u 10001 appuser
USER appuser

COPY --from=builder /app/server /server
EXPOSE 8080
ENTRYPOINT [ "/server" ]