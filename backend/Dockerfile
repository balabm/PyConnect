# PondyConnect Backend - Multi-stage Dockerfile
# Stage 1: Build the .NET 8 API using the full SDK
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build

WORKDIR /src

# Copy project files first for better layer caching.
# Restore runs only when project files change.
COPY Directory.Build.props ./
COPY src/PondyConnect.Domain/PondyConnect.Domain.csproj src/PondyConnect.Domain/
COPY src/PondyConnect.Application/PondyConnect.Application.csproj src/PondyConnect.Application/
COPY src/PondyConnect.Infrastructure/PondyConnect.Infrastructure.csproj src/PondyConnect.Infrastructure/
COPY src/PondyConnect.Api/PondyConnect.Api.csproj src/PondyConnect.Api/

RUN dotnet restore src/PondyConnect.Api/PondyConnect.Api.csproj

# Copy the rest of the source code
COPY src/ src/

# Publish the API project with Release configuration.
# Trimming is intentionally NOT enabled because EF Core and reflection-based
# serialization (System.Text.Json source-gen aside) need the full type metadata.
RUN dotnet publish src/PondyConnect.Api/PondyConnect.Api.csproj \
    -c Release \
    -o /app/publish \
    /p:UseAppHost=false

# Stage 2: Runtime on Alpine Linux (small footprint, ideal for t3.micro)
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS runtime

# Install ICU for globalization support (Alpine doesn't ship it by default).
# Required by EF Core / Npgsql for culture-aware string operations.
RUN apk add --no-cache icu-libs

ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

WORKDIR /app

# Copy the published output from the build stage
COPY --from=build /app/publish ./

# Expose the HTTP port the API listens on.
# ASP.NET Core listens on port 8080 by default in the aspnet:8.0-alpine image
# (the ASPNETCORE_HTTP_PORTS env var is set by the base image).
EXPOSE 8080

# Non-root user for security. The aspnet:8.0-alpine image ships a `app` user.
USER app

# Health check: hit the health endpoint exposed by the API.
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "PondyConnect.Api.dll"]
