$ErrorActionPreference = 'Stop'
$envFile = Join-Path $PSScriptRoot '..\.env'
if (-not (Test-Path -LiteralPath $envFile)) {
    throw 'backend/.env is missing. Configure MySQL credentials before starting the C++ API.'
}

foreach ($line in Get-Content -LiteralPath $envFile) {
    if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
        [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
}

$vcpkgBin = Join-Path $env:USERPROFILE 'dev\vcpkg\installed\x64-windows\bin'
$env:MARIADB_PLUGIN_DIR = Join-Path $PSScriptRoot 'build\vcpkg_installed\x64-windows\plugins\libmariadb'
$env:PATH = "$vcpkgBin;$env:PATH"
$exe = Join-Path $PSScriptRoot 'build\Release\stockroom_api.exe'
if (-not (Test-Path -LiteralPath $exe)) {
    throw 'C++ API is not built. Run the CMake configure/build commands in README.md first.'
}
& $exe
