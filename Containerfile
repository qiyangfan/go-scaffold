# 单二进制构建；CGO 关闭以获得静态产物
FROM golang:1.27 AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /out/server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/server /usr/local/bin/server
USER 65532:65532
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/server"]
