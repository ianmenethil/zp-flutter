# 1. Build Stage: Resolve backend workspace dependencies and compile
FROM dart:stable AS build

WORKDIR /app

# Copy the packages required for the backend
COPY zenpay_dart/ ./zenpay_dart/
COPY example/backend/ ./example/backend/

# Generate a workspace manifest that only includes pure-Dart packages (excluding Flutter app)
RUN printf "name: backend_workspace\npublish_to: none\nenvironment:\n  sdk: '>=3.12.0 <4.0.0'\nworkspace:\n  - zenpay_dart\n  - example/backend\n" > pubspec.yaml

# Download and resolve all backend workspace dependencies
RUN dart pub get

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
