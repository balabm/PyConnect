# PondyConnect Backend - Multi-stage Dockerfile
# Migrations are applied automatically by the app on startup via DataInitializer.
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .

# Build the API project
RUN dotnet restore backend/src/PondyConnect.Api/PondyConnect.Api.csproj
RUN dotnet build backend/src/PondyConnect.Api/PondyConnect.Api.csproj -c Release

FROM build AS publish
RUN dotnet publish backend/src/PondyConnect.Api/PondyConnect.Api.csproj -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
COPY --from=build /src/backend/entrypoint.sh ./entrypoint.sh
RUN chmod +x ./entrypoint.sh

ENTRYPOINT ["./entrypoint.sh"]
