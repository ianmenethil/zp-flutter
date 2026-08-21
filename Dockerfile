# Multi-stage build: backend + frontend in one image
# Stage 1: Build backend (Dart AOT executable)
FROM dart:latest AS backend-build

WORKDIR /app

COPY zenpay_dart/ ./zenpay_dart/
COPY example/backend/ ./example/backend/

RUN printf "name: backend_workspace\npublish_to: none\nenvironment:\n  sdk: '>=3.12.0 <4.0.0'\nworkspace:\n  - zenpay_dart\n  - example/backend\n" > pubspec.yaml

RUN dart pub get
RUN dart compile exe example/backend/bin/server.dart -o /app/server

# Stage 2: Build frontend (Flutter Web)
FROM dart:latest AS frontend-build

RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

RUN flutter config --enable-web
RUN flutter --version

WORKDIR /app

COPY zenpay_dart/ ./zenpay_dart/
COPY zenpay_flutter/ ./zenpay_flutter/
COPY example/app/ ./example/app/

# Generate Flutter-only workspace pubspec (zenpay_flutter + example/app only)
RUN printf "name: flutter_workspace\npublish_to: none\nenvironment:\n  sdk: '>=3.12.0 <4.0.0'\n  flutter: '>=3.44.0'\nworkspace:\n  - zenpay_flutter\n  - example/app\n" > pubspec.yaml

RUN cd example/app && flutter pub get && flutter build web --release

# Stage 3: Runtime (minimal)
FROM debian:bookworm-slim

WORKDIR /app

COPY --from=backend-build /app/server /app/server
COPY --from=frontend-build /app/example/app/build/web /app/web
COPY example/backend/well_known/ /app/well_known/

ENV PORT=7000
EXPOSE 7000

CMD ["/app/server"]
