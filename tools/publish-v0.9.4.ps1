param(
    [string]$AssetDir = "C:\Users\Administrator\Desktop\XrayR v0.9.4",
    [string]$Tag = "v0.9.4",
    [string]$Repo = "nbbk/XrayR-KOJO"
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path -LiteralPath $AssetDir)) {
    Fail "目录不存在：$AssetDir"
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Fail "未检测到 GitHub CLI (gh)。请先安装 GitHub CLI，然后执行 gh auth login。"
}

Write-Host "检查 GitHub 登录状态..." -ForegroundColor Cyan
& gh auth status
if ($LASTEXITCODE -ne 0) {
    Fail "GitHub CLI 尚未登录，请先执行：gh auth login"
}

$assets = Get-ChildItem -LiteralPath $AssetDir -File | Where-Object {
    $_.Name -match '^XrayR.*\.zip$' -or
    $_.Name -match '^XrayR.*\.tar\.gz$' -or
    $_.Name -eq 'XrayR.service'
} | Sort-Object Name

if (-not $assets -or $assets.Count -eq 0) {
    Fail "没有在 $AssetDir 找到 XrayR 发布文件。"
}

Write-Host "将发布以下文件：" -ForegroundColor Cyan
$assets | ForEach-Object { Write-Host "  - $($_.Name)" }

# 为所有发布资产生成 SHA256SUMS，Linux 安装器会自动校验对应 ZIP。
$checksumFile = Join-Path $env:TEMP "XrayR-KOJO-SHA256SUMS"
$checksumLines = foreach ($asset in $assets) {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $asset.FullName).Hash.ToLowerInvariant()
    "$hash  $($asset.Name)"
}
$checksumLines | Set-Content -LiteralPath $checksumFile -Encoding Ascii

Write-Host "已生成 SHA256SUMS。" -ForegroundColor Green

Write-Host "检查 Release $Tag ..." -ForegroundColor Cyan
& gh release view $Tag --repo $Repo *> $null
$releaseExists = ($LASTEXITCODE -eq 0)

if (-not $releaseExists) {
    Write-Host "创建 Release $Tag ..." -ForegroundColor Cyan
    & gh release create $Tag `
        --repo $Repo `
        --title "XrayR-KOJO $Tag" `
        --notes "XrayR-KOJO self-maintained release. Includes preserved XrayR binaries/source archives and uses the original upstream license."

    if ($LASTEXITCODE -ne 0) {
        Fail "创建 Release 失败。"
    }
}

foreach ($asset in $assets) {
    Write-Host "上传：$($asset.Name)" -ForegroundColor Cyan
    & gh release upload $Tag $asset.FullName --repo $Repo --clobber
    if ($LASTEXITCODE -ne 0) {
        Fail "上传失败：$($asset.FullName)"
    }
}

Write-Host "上传：SHA256SUMS" -ForegroundColor Cyan
& gh release upload $Tag "$checksumFile#SHA256SUMS" --repo $Repo --clobber
if ($LASTEXITCODE -ne 0) {
    Fail "上传 SHA256SUMS 失败。"
}

Remove-Item -LiteralPath $checksumFile -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Release 发布完成。" -ForegroundColor Green
Write-Host "仓库：https://github.com/$Repo/releases/tag/$Tag"
Write-Host ""
Write-Host "接下来可在 Linux VPS 测试：" -ForegroundColor Green
Write-Host "bash <(curl -Ls https://raw.githubusercontent.com/nbbk/XrayR-KOJO/main/install.sh)"
