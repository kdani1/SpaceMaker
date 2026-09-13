$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot\backend
dotnet restore
dotnet run -c Release --urls http://0.0.0.0:51810
