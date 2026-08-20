# 1. Build Stage: Resolve workspace dependencies and compile to a native binary
FROM dart:stable AS build

WORKDIR /app

# Copy root workspace and package manifests for efficient layer caching
COPY pubspec.yaml ./
COPY zenpay_dart/pubspec.yaml ./zenpay_dart/
COPY zenpay_flutter/pubspec.yaml ./zenpay_flutter/
COPY example/backend/pubspec.yaml ./example/backend/
COPY example/app/pubspec.yaml ./example/app/

# Download and resolve all workspace dependencies
RUN dart pub get

# Copy source code required by the backend
COPY zenpay_dart/ ./zenpay_dart/
COPY example/backend/ ./example/backend/

# Compile the Shelf backend into a standalone native AOT binary
RUN dart compile exe example/backend/bin/server.dart -o /app/server

# -----------------------------------------------------------------------------
# 2. Runtime Stage: Minimal production container
FROM debian:bookworm-slim

WORKDIR /app

# Copy the compiled standalone executable
COPY --from=build /app/server /app/server

# Copy static .well-known files (App Links / Universal Links associations)
COPY example/backend/well_known/ /app/well_known/

# Default environment variables
ENV PORT=7000
EXPOSE 7000

# Run the server
CMD ["/app/server"]
