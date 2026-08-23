# PondyConnect Backend - Multi-stage Dockerfile
# Migrations are applied automatically by the app on startup via DataInitializer.
#
# Build context is the `backend/` directory, so COPY . . copies the contents
# of backend/ (src/, tests/, entrypoint.sh, etc.) into /src.
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .

# Build the API project — path is src/ (not backend/src/) because the
# build context is already the backend/ directory.
RUN dotnet restore src/PondyConnect.Api/PondyConnect.Api.csproj
RUN dotnet build src/PondyConnect.Api/PondyConnect.Api.csproj -c Release

FROM build AS publish
RUN dotnet publish src/PondyConnect.Api/PondyConnect.Api.csproj -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
COPY --from=build /src/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
