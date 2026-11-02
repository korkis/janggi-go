# 대국 서버 이미지. janggi_core를 path 의존성으로 쓰므로 저장소 루트를 빌드 컨텍스트로 쓴다.
#   docker build -f server/game/Dockerfile .
# 자세한 내용은 server/game/README.md.

FROM dart:3.13 AS build

# 의존성만 먼저 받아 소스가 바뀌어도 이 층을 다시 쓰게 한다.
WORKDIR /src
COPY packages/janggi_core/pubspec.yaml packages/janggi_core/
COPY server/game/pubspec.yaml server/game/pubspec.lock server/game/
WORKDIR /src/server/game
RUN dart pub get

COPY packages/janggi_core /src/packages/janggi_core
COPY server/game /src/server/game
RUN dart pub get --offline
RUN dart compile exe bin/server.dart -o /app/server

# 실행에 필요한 런타임 파일과 실행 파일만 담는다.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
# Cloud Run이 PORT를 넣어 준다.
CMD ["/app/server"]
