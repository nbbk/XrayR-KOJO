param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidatePattern('^v\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$')]
    [string]$Version
)

# Windows PowerShell 5.1 读取无 BOM 的 UTF-8 脚本时可能出现中文乱码，因此本文件必须保留 UTF-8 BOM。
$ErrorActionPreference = 'Stop'
$Repo = 'nbbk/XrayR-KOJO'
$Source = "C:\Users\Administrator\Desktop\XrayR $Version"

function Stop-WithError {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host "[错误] $Message" -ForegroundColor Red
    exit 1
}

function Invoke-GitHubCli {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & gh @Arguments
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "GitHub CLI 执行失败：gh $($Arguments -join ' ')"
    }
}

Write-Host '========================================' -ForegroundColor Cyan
Write-Host '       XrayR-KOJO Release 发布工具' -ForegroundColor Cyan
Write-Host "       版本：$Version" -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan

if (-not (Test-Path -LiteralPath $Source -PathType Container)) {
    Stop-WithError "发布目录不存在：$Source"
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Stop-WithError '未检测到 GitHub CLI。请先安装 gh，并执行 gh auth login。'
}

Write-Host '检查 GitHub 登录状态……' -ForegroundColor Cyan
& gh auth status
if ($LASTEXITCODE -ne 0) {
    Stop-WithError 'GitHub CLI 尚未登录，请先执行：gh auth login'
}

# 仅发布 ZIP，避免把目录里的临时文件误传到 Release。
$Assets = @(Get-ChildItem -LiteralPath $Source -File -Filter '*.zip' | Sort-Object Name)
if ($Assets.Count -eq 0) {
    Stop-WithError "目录中没有 ZIP 发布文件：$Source"
}

Write-Host '即将发布以下文件：' -ForegroundColor Cyan
$Assets | ForEach-Object { Write-Host "  - $($_.Name)" }

# 校验文件使用 ASCII 内容，Linux 上的 sha256sum 可以直接读取。
$ChecksumFile = Join-Path $Source 'SHA256SUMS.txt'
$ChecksumLines = foreach ($Asset in $Assets) {
    $Hash = (Get-FileHash -LiteralPath $Asset.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    "$Hash  $($Asset.Name)"
}
$ChecksumLines | Set-Content -LiteralPath $ChecksumFile -Encoding Ascii
Write-Host "已生成校验文件：$ChecksumFile" -ForegroundColor Green

& gh release view $Version --repo $Repo *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "创建 GitHub Release：$Version" -ForegroundColor Cyan
    Invoke-GitHubCli @('release', 'create', $Version, '--repo', $Repo, '--title', "XrayR-KOJO $Version", '--notes', "XrayR-KOJO 自维护版本 $Version")
} else {
    Write-Host "Release $Version 已存在，将覆盖同名资产。" -ForegroundColor Yellow
}

foreach ($Asset in $Assets) {
    Write-Host "上传：$($Asset.Name)" -ForegroundColor Cyan
    Invoke-GitHubCli @('release', 'upload', $Version, $Asset.FullName, '--repo', $Repo, '--clobber')
}

Write-Host '上传：SHA256SUMS.txt' -ForegroundColor Cyan
Invoke-GitHubCli @('release', 'upload', $Version, $ChecksumFile, '--repo', $Repo, '--clobber')

Write-Host ''
Write-Host "发布完成：https://github.com/$Repo/releases/tag/$Version" -ForegroundColor Green
Write-Host "Linux 安装命令：bash <(curl -Ls https://raw.githubusercontent.com/$Repo/main/install.sh)" -ForegroundColor Green
