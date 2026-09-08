# Deployment parity only — local development runs under devenv, not this image.
# Build from the repository root: the compose file passes `context: .`.
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY apps/api apps/api
RUN dotnet publish apps/api/src/Api -c Release -o /out

FROM mcr.microsoft.com/dotnet/aspnet:10.0
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_URLS=http://0.0.0.0:5080
EXPOSE 5080
ENTRYPOINT ["dotnet", "Api.dll"]
