#Requires -Version 5.1
<#
.SYNOPSIS
  校验 ComfyUI 便携版是否装好、CUDA 是否可用、模型目录是否存在。
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\verify-install.ps1 -InstallDir "D:\ComfyUI"
#>
[CmdletBinding()]
param(
    [string]$InstallDir = "D:\ComfyUI",
    [switch]$AllowCpu
)

$ErrorActionPreference = "Continue"
$failed = @()

function Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
    if ($Ok) {
        Write-Host "  [PASS] $Name $Detail" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Name $Detail" -ForegroundColor Red
        $script:failed += $Name
    }
}

Write-Host ""
Write-Host "=== 校验 ComfyUI 安装：$InstallDir ===" -ForegroundColor Cyan
Write-Host ""

$mainPy = Join-Path $InstallDir "ComfyUI\main.py"
$python = Join-Path $InstallDir "python_embeded\python.exe"
$models = Join-Path $InstallDir "ComfyUI\models"
$lowBat = Join-Path $InstallDir "start-lowvram.bat"
$fourBat = Join-Path $InstallDir "start-4gb.bat"

Check "ComfyUI\main.py" (Test-Path $mainPy) $mainPy
Check "python_embeded\python.exe" (Test-Path $python) $python
Check "models 目录" (Test-Path $models) $models
Check "start-lowvram.bat" (Test-Path $lowBat) $lowBat
Check "start-4gb.bat" (Test-Path $fourBat) $fourBat

# 模型目录结构
$requiredDirs = @("checkpoints", "vae", "loras", "controlnet", "upscale_models")
foreach ($d in $requiredDirs) {
    Check "models\$d" (Test-Path (Join-Path $models $d))
}

# Python / Torch / CUDA
Write-Host ""
Write-Host "[运行时]" -ForegroundColor Cyan
if (Test-Path $python) {
    $code = @'
import sys
print("python", sys.version.split()[0])
try:
    import torch
    print("torch", torch.__version__)
    print("cuda", torch.cuda.is_available())
    if torch.cuda.is_available():
        print("device", torch.cuda.get_device_name(0))
        print("vram_gb", round(torch.cuda.get_device_properties(0).total_memory / 1024**3, 1))
except Exception as e:
    print("torch_error", type(e).__name__, e)
'@
    $tmp = Join-Path $env:TEMP "comfyui_verify_$PID.py"
    Set-Content -Path $tmp -Value $code -Encoding UTF8
    $out = & $python $tmp 2>&1
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    $out | ForEach-Object { Write-Host "  $_" }

    $text = ($out | Out-String)
    Check "Python 可执行" ($text -match "python 3\.") ""
    if ($AllowCpu) {
        Check "Torch 可导入" ($text -match "torch [0-9]") ""
    } else {
        Check "Torch 可导入" ($text -match "torch [0-9]") ""
        Check "CUDA 可用" ($text -match "cuda True") "（如果是 False，见 AI-DEPLOY.md 故障树）"
    }
} else {
    Write-Host "  [SKIP] Python 不存在，跳过运行时检查" -ForegroundColor Yellow
}

# 模型数量
Write-Host ""
Write-Host "[模型]" -ForegroundColor Cyan
$ckpts = Get-ChildItem (Join-Path $models "checkpoints") -File -ErrorAction SilentlyContinue
$ckptCount = @($ckpts).Count
if ($ckptCount -gt 0) {
    Write-Host "  [PASS] checkpoints 有 $ckptCount 个文件" -ForegroundColor Green
    $ckpts | Select-Object -First 10 | ForEach-Object {
        Write-Host ("    {0}  {1:N2} GB" -f $_.Name, ($_.Length / 1GB))
    }
} else {
    Write-Host "  [WARN] checkpoints 为空；启动后模型下拉框也会是空的。" -ForegroundColor Yellow
    Write-Host "         运行：python .\scripts\download-models.py --profile minimal --dest `"$models`""
}

# 结论
Write-Host ""
if ($failed.Count -eq 0) {
    Write-Host "=== 结果：PASS ===" -ForegroundColor Green
    Write-Host "下一步：双击 $lowBat，浏览器打开 http://127.0.0.1:8188"
    exit 0
} else {
    Write-Host "=== 结果：FAIL（$($failed.Count) 项） ===" -ForegroundColor Red
    $failed | ForEach-Object { Write-Host "  - $_" }
    exit 1
}