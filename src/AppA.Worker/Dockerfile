FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY ["src/AppA.Worker/AppA.Worker.csproj", "src/AppA.Worker/"]
RUN dotnet restore "src/AppA.Worker/AppA.Worker.csproj"

COPY . .
RUN dotnet publish "src/AppA.Worker/AppA.Worker.csproj" -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/runtime:8.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "AppA.Worker.dll"]
