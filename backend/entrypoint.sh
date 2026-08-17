#!/bin/bash
set -e

echo "Running EF Core migrations..."
cd /app
dotnet ef database update --project src/PondyConnect.Infrastructure --startup-project src/PondyConnect.Api --no-build

echo "Starting API..."
exec dotnet PondyConnect.Api.dll
