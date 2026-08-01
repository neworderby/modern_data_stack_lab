# load_env.ps1 - загружает .env БЕЗ direnv
$envFile = ".env"
Write-Host "Загрузка $envFile..." -ForegroundColor Cyan

if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith('#')) {
            $parts = $line -split '=', 2
            if ($parts.Length -eq 2) {
                $name = $parts[0].Trim()
                $value = $parts[1].Trim().Trim('"').Trim("'")
                
                # Устанавливаем переменную
                [Environment]::SetEnvironmentVariable($name, $value, "Process")
                Write-Host "  $name = ***" -ForegroundColor DarkGray
            }
        }
    }
    Write-Host "✅ .env загружен!" -ForegroundColor Green
    
    # Показать несколько переменных для проверки
    Write-Host "`nПроверка:" -ForegroundColor Yellow
    Write-Host "  AIRFLOW_UID: $env:AIRFLOW_UID"
    Write-Host "  DWH_USER: $env:DWH_USER"
    Write-Host "  NOCODB_ADMIN_EMAIL: $env:NOCODB_ADMIN_EMAIL"
} else {
    Write-Host "❌ Файл .env не найден!" -ForegroundColor Red
}