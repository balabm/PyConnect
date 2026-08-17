# PondyConnect Backend - Multi-stage Dockerfile with EF Core migrations
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY . .

# Install dotnet-ef tool in SDK stage so it can be copied into the runtime image
RUN dotnet tool install --global dotnet-ef --version 8.0.0
ENV PATH="${PATH}:/root/.dotnet/tools"

# Build to the default output paths so dotnet-ef --no-build can find assemblies
RUN dotnet restore backend/src/PondyConnect.Api/PondyConnect.Api.csproj
RUN dotnet build backend/src/PondyConnect.Api/PondyConnect.Api.csproj -c Release

FROM build AS publish
RUN dotnet publish backend/src/PondyConnect.Api/PondyConnect.Api.csproj -c Release -o /app/publish

FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
COPY --from=build /src/backend/entrypoint.sh ./entrypoint.sh
COPY --from=build /root/.dotnet /root/.dotnet
COPY --from=build /src/backend/src ./src
RUN chmod +x ./entrypoint.sh

ENV PATH="${PATH}:/root/.dotnet/tools"

ENTRYPOINT ["./entrypoint.sh"]
