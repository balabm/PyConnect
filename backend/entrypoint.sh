#!/bin/bash
set -e

echo "Starting API (EF Core migrations applied automatically on startup)..."
exec dotnet PondyConnect.Api.dll
