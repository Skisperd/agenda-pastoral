# Instala a ponte de mídia no computador da igreja e faz ela arrancar com o Windows.
# Botão direito › Executar com o PowerShell (nesta pasta).
$ErrorActionPreference = 'Stop'
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pasta

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  Write-Host 'O Node.js não está instalado. Instale a versão LTS em https://nodejs.org e rode este script de novo.' -ForegroundColor Yellow
  Read-Host 'Enter para sair'; exit 1
}

Write-Host 'Instalando dependências...'
npm install --omit=dev --no-audit --no-fund | Out-Null

if (-not (Test-Path config.json)) {
  Copy-Item config.exemplo.json config.json
  Write-Host 'Preencha o config.json (IP e senha do OBS, conta da ponte) e salve.' -ForegroundColor Yellow
  notepad config.json | Out-Null
}

# Atalho na pasta Inicializar: arranca escondido e grava o registro em ponte.log.
$inicializar = [Environment]::GetFolderPath('Startup')
$atalho = (New-Object -ComObject WScript.Shell).CreateShortcut("$inicializar\Ponte de mídia.lnk")
$atalho.TargetPath = 'powershell.exe'
$atalho.Arguments = "-WindowStyle Hidden -NoProfile -Command `"Set-Location '$pasta'; node ponte.mjs *>> ponte.log`""
$atalho.WorkingDirectory = $pasta
$atalho.Save()

# Reinicia agora (para quem rodou o script de novo depois de mudar algo).
Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like '*ponte.mjs*' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList "-NoProfile -Command `"Set-Location '$pasta'; node ponte.mjs *>> ponte.log`""
Start-Sleep -Seconds 6
Get-Content ponte.log -Tail 8
Write-Host 'A funcionar. O registro fica em ponte.log.' -ForegroundColor Green
Read-Host 'Enter para fechar'
