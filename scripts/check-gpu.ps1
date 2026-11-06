#Requires -Version 5.1
<#
.SYNOPSIS
  检查这台机器适合跑 ComfyUI 的哪个档位。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\check-gpu.ps1
#>
[CmdletBinding()]
param(
    [string]$InstallDrive = "D"
)

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "=== ComfyUI 环境检查 ===" -ForegroundColor Cyan

# 系统
Write-Host ""
Write-Host "[系统]"
Write-Host "  $([System.Environment]::OSVersion.VersionString)"
Write-Host "  64 位：$([Environment]::Is64BitOperatingSystem)"

# 显卡
Write-Host ""
Write-Host "[显卡]"
$vramGB = 0
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if (-not $smi) {
    Write-Host "  未找到 nvidia-smi（没有 N 卡或没装驱动）" -ForegroundColor Yellow
    Write-Host "  → 只能用 CPU 模式，或换有 NVIDIA 显卡的机器。"
} else {
    $csv = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>$null
    if ($LASTEXITCODE -eq 0 -and $csv) {
        $csv | ForEach-Object { Write-Host "  $_" }
        $first = ($csv | Select-Object -First 1)
        if ($first -match '(\d+)\s*MiB') {
            $vramGB = [math]::Round([int]$matches[1] / 1024, 1)
        }
    } else {
        Write-Host "  nvidia-smi 执行失败，请更新驱动。" -ForegroundColor Yellow
    }
}

# 内存
Write-Host ""
Write-Host "[内存]"
$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
Write-Host "  物理内存：$ramGB GB"
if ($ramGB -lt 16) {
    Write-Host "  → 建议把虚拟内存调到 32GB 以上，否则低显存模式容易崩。" -ForegroundColor Yellow
}

# 磁盘
Write-Host ""
Write-Host "[磁盘]"
$drive = Get-PSDrive -Name $InstallDrive -ErrorAction SilentlyContinue
if ($drive) {
    $freeGB = [math]::Round($drive.Free / 1GB, 1)
    Write-Host "  ${InstallDrive}: 剩余 $freeGB GB"
    if ($freeGB -lt 30) {
        Write-Host "  → 不足 30GB，建议换盘或清理。" -ForegroundColor Yellow
    }
} else {
    Write-Host "  找不到 ${InstallDrive}: 盘" -ForegroundColor Yellow
}

# 结论
Write-Host ""
Write-Host "[推荐]" -ForegroundColor Cyan
if ($vramGB -eq 0) {
    Write-Host "  CPU 模式 / 云端。本地不推荐。"
} elseif ($vramGB -lt 4) {
    Write-Host "  显存 $vramGB GB：只能 SD1.5 512×512，建议 --novram。"
    Write-Host "  模型档位：minimal"
} elseif ($vramGB -lt 6) {
    Write-Host "  显存 $vramGB GB：SD1.5 512–768，SDXL 不建议。"
    Write-Host "  模型档位：minimal"
    Write-Host "  启动脚本：start-4gb.bat"
} elseif ($vramGB -lt 8) {
    Write-Host "  显存 $vramGB GB：SD1.5 很顺；SDXL 768 可跑，1024 要 Tiled VAE。"
    Write-Host "  模型档位：standard"
    Write-Host "  启动脚本：start-lowvram.bat"
} else {
    Write-Host "  显存 $vramGB GB：SDXL 1024 比较稳，可试轻量视频。"
    Write-Host "  模型档位：standard（视频再加 video）"
    Write-Host "  启动脚本：start-lowvram.bat"
}

Write-Host ""
Write-Host "下一步："
Write-Host ('  powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -InstallDir "{0}:\ComfyUI"' -f $InstallDrive)
Write-Host ""