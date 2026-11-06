#Requires -Version 5.1
<#
.SYNOPSIS
  安装 ComfyUI Windows 便携版，并生成低显存启动脚本。

.DESCRIPTION
  默认安装到 D:\ComfyUI。会检查显卡/磁盘，下载官方便携包，解压，
  生成 start-lowvram.bat / start-4gb.bat，最后跑一次校验。

.PARAMETER InstallDir
  安装目录，不能含中文/空格，默认 D:\ComfyUI。

.PARAMETER ModelsDir
  可选：模型放另一个目录（例如 E:\ComfyUI-models），会写 extra_model_paths.yaml。

.PARAMETER Archive
  可选：已经下载好的 ComfyUI_windows_portable_nvidia.7z 路径。

.PARAMETER SkipDownload
  跳过下载，只用 -Archive 指定的文件。

.PARAMETER AllowNoGpu
  没有 NVIDIA 显卡也继续（仅 CPU，极慢，不推荐）。

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -InstallDir "D:\ComfyUI"

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install-windows.ps1 -Archive "D:\下载\ComfyUI_windows_portable_nvidia.7z" -SkipDownload
#>
[CmdletBinding()]
param(
    [string]$InstallDir = "D:\ComfyUI",
    [string]$ModelsDir = "",
    [string]$Archive = "",
    [switch]$SkipDownload,
    [switch]$AllowNoGpu,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-Step([string]$Text) {
    Write-Host ""
    Write-Host "==> $Text" -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host "    [OK] $Text" -ForegroundColor Green
}

function Write-Warn([string]$Text) {
    Write-Host "    [WARN] $Text" -ForegroundColor Yellow
}

function Stop-WithMessage([string]$Text) {
    Write-Host ""
    Write-Host "[ERROR] $Text" -ForegroundColor Red
    if (-not $NoPause) { Read-Host "按回车退出" | Out-Null }
    exit 1
}

function Test-FreeSpace([string]$Path, [double]$NeedGB) {
    $root = [System.IO.Path]::GetPathRoot($Path)
    $drive = $root.TrimEnd("\").TrimEnd(":")
    $free = (Get-PSDrive -Name $drive -ErrorAction SilentlyContinue).Free
    if ($null -eq $free) {
        Write-Warn "无法读取 $drive 盘剩余空间，跳过检查"
        return
    }
    $freeGB = [math]::Round($free / 1GB, 1)
    Write-Host "    $drive 盘剩余：$freeGB GB（需要约 $NeedGB GB）"
    if ($freeGB -lt $NeedGB) {
        Stop-WithMessage "$drive 盘空间不足。请清理到至少 $NeedGB GB，或换一个盘。"
    }
}

function Get-SevenZip([string]$Dir) {
    $toolDir = Join-Path $Dir "_tools"
    $sevenZip = Join-Path $toolDir "7zr.exe"
    if (Test-Path $sevenZip) { return $sevenZip }

    New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
    $url = "https://www.7-zip.org/a/7zr.exe"
    Write-Host "    下载 7zr.exe（约 600KB）…"
    try {
        Invoke-WebRequest -Uri $url -OutFile $sevenZip -UseBasicParsing -TimeoutSec 60
        Write-Ok "7zr.exe 已下载"
    } catch {
        # 系统若已有 7z，也可以直接用
        $existing = Get-Command 7z -ErrorAction SilentlyContinue
        if ($existing) {
            Write-Warn "7zr 下载失败，改用系统 7z：$($existing.Source)"
            return $existing.Source
        }
        Stop-WithMessage "下载 7zr.exe 失败：$($_.Exception.Message)。请手动安装 7-Zip 后重试。"
    }
    return $sevenZip
}

function Download-File([string]$Url, [string]$OutFile) {
    $dir = Split-Path -Parent $OutFile
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    Write-Host "    下载：$Url"
    if (Get-Command curl.exe -ErrorAction SilentlyContinue) {
        & curl.exe -L --fail --retry 5 --retry-delay 3 -C - -o $OutFile $Url
        if ($LASTEXITCODE -ne 0) {
            throw "curl 下载失败，退出码 $LASTEXITCODE"
        }
    } else {
        Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -TimeoutSec 3600
    }
    if (-not (Test-Path $OutFile)) { throw "下载后文件不存在：$OutFile" }
    $gb = [math]::Round((Get-Item $OutFile).Length / 1GB, 2)
    if ($gb -lt 1.0) { throw "下载文件只有 $gb GB，可能没下完整" }
    Write-Ok "下载完成：$OutFile（$gb GB）"
}

function Write-StartScripts([string]$Root) {
    $low = @'
@echo off
setlocal
cd /d "%~dp0"
echo.
echo   ComfyUI low-VRAM mode (6GB / 8GB)
echo   Wait for: To see the GUI go to http://127.0.0.1:8188
echo.
"%~dp0python_embeded\python.exe" -s "%~dp0ComfyUI\main.py" --lowvram --use-pytorch-cross-attention --port 8188 --preview-method auto
if errorlevel 1 pause
'@
    $lowPath = Join-Path $Root "start-lowvram.bat"
    Set-Content -Path $lowPath -Value $low -Encoding ASCII -NoNewline
    Write-Ok "已生成 $lowPath"

    $four = @'
@echo off
setlocal
cd /d "%~dp0"
echo.
echo   ComfyUI 4GB mode (--novram, slower but safer)
echo   Wait for: To see the GUI go to http://127.0.0.1:8188
echo.
"%~dp0python_embeded\python.exe" -s "%~dp0ComfyUI\main.py" --novram --use-pytorch-cross-attention --reserve-vram 0.3 --port 8188 --preview-method auto
if errorlevel 1 pause
'@
    $fourPath = Join-Path $Root "start-4gb.bat"
    Set-Content -Path $fourPath -Value $four -Encoding ASCII -NoNewline
    Write-Ok "已生成 $fourPath"

    $safe = @'
@echo off
setlocal
cd /d "%~dp0"
echo.
echo   ComfyUI safe mode (all custom nodes disabled)
echo   Use this to check whether a plugin is causing the problem.
echo.
"%~dp0python_embeded\python.exe" -s "%~dp0ComfyUI\main.py" --lowvram --use-pytorch-cross-attention --disable-all-custom-nodes --port 8188
if errorlevel 1 pause
'@
    $safePath = Join-Path $Root "start-safe-mode.bat"
    Set-Content -Path $safePath -Value $safe -Encoding ASCII -NoNewline
    Write-Ok "已生成 $safePath"
}

function Write-ExtraModelPaths([string]$Root, [string]$ExternalModels) {
    $target = Join-Path $Root "ComfyUI\extra_model_paths.yaml"
    $yaml = @"
# 由 install-windows.ps1 生成
# 模型放在外部目录时使用；路径必须用正斜杠。
comfyui_external:
    base_path: $($ExternalModels.Replace('\', '/'))
    checkpoints: checkpoints
    vae: vae
    loras: loras
    controlnet: controlnet
    upscale_models: upscale_models
    embeddings: embeddings
    facerestore_models: facerestore_models
    rembg: rembg
    inpaint: inpaint
    ipadapter: ipadapter
    clip_vision: clip_vision
    style_models: style_models
    unet: unet
    diffusion_models: unet
    text_encoders: text_encoders
    animatediff_models: animatediff_models
    frame_interpolation: frame_interpolation
    sam: sam
    depthanything: depthanything
"@
    if (Test-Path $target) {
        Copy-Item $target "$target.bak_$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    }
    Set-Content -Path $target -Value $yaml -Encoding UTF8
    Write-Ok "已写入 $target"
}

# ---------- 0. 基本检查 ----------
Write-Step "检查系统"
if (-not [Environment]::Is64BitOperatingSystem) {
    Stop-WithMessage "只支持 64 位 Windows。"
}
Write-Host "    系统：$([System.Environment]::OSVersion.VersionString)"
Write-Host "    安装目录：$InstallDir"

if ($InstallDir -match '[\u4e00-\u9fa5]') {
    Stop-WithMessage "安装路径含中文：$InstallDir。请换成纯英文路径，例如 D:\ComfyUI。"
}
if ($InstallDir -match '\s') {
    Write-Warn "安装路径含空格，可能触发少数插件的路径问题。建议换成 D:\ComfyUI。"
}

$driveRoot = [System.IO.Path]::GetPathRoot($InstallDir)
if (-not (Test-Path $driveRoot)) {
    Stop-WithMessage "盘符不存在：$driveRoot"
}
Test-FreeSpace -Path $InstallDir -NeedGB 25

Write-Step "检查显卡"
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if (-not $smi) {
    if ($AllowNoGpu) {
        Write-Warn "没找到 nvidia-smi，将按 CPU 模式继续（极慢）。"
    } else {
        Stop-WithMessage "没找到 nvidia-smi。请先安装 NVIDIA 驱动；如果确定要用 CPU，加 -AllowNoGpu。"
    }
} else {
    & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
    if ($LASTEXITCODE -ne 0) {
        if (-not $AllowNoGpu) { Stop-WithMessage "nvidia-smi 执行失败，请更新 NVIDIA 驱动。" }
    }
}

# ---------- 1. 准备安装目录 ----------
Write-Step "准备安装目录"
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
$downloadDir = Join-Path $InstallDir "_download"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

# ---------- 2. 下载 / 定位安装包 ----------
Write-Step "准备 ComfyUI 便携包"
if (-not $Archive) {
    $Archive = Join-Path $downloadDir "ComfyUI_windows_portable_nvidia.7z"
}
$portableUrl = "https://github.com/Comfy-Org/ComfyUI/releases/download/v0.42.1/ComfyUI_windows_portable_nvidia.7z"

if ($SkipDownload) {
    if (-not (Test-Path $Archive)) {
        Stop-WithMessage "指定了 -SkipDownload，但找不到安装包：$Archive"
    }
    Write-Ok "使用已有安装包：$Archive"
} else {
    if (Test-Path $Archive) {
        $gb = [math]::Round((Get-Item $Archive).Length / 1GB, 2)
        if ($gb -ge 1.0) {
            Write-Ok "安装包已存在，跳过下载：$Archive（$gb GB）"
        } else {
            Write-Warn "安装包不完整，重新下载"
            Remove-Item $Archive -Force
        }
    }
    if (-not (Test-Path $Archive)) {
        try {
            Download-File -Url $portableUrl -OutFile $Archive
        } catch {
            Write-Warn "官方下载失败：$($_.Exception.Message)"
            Stop-WithMessage @"
下载 ComfyUI 便携包失败。可以：
  1. 用浏览器打开 https://github.com/Comfy-Org/ComfyUI/releases
     下载 ComfyUI_windows_portable_nvidia.7z；
  2. 重新运行：
     .\install-windows.ps1 -Archive "你下载的路径\ComfyUI_windows_portable_nvidia.7z" -SkipDownload
  3. 或用国内镜像/网盘拿到同名文件，核对约 2GB。
"@
        }
    }
}

# ---------- 3. 解压 ----------
Write-Step "解压安装包"
$sevenZip = Get-SevenZip -Dir $InstallDir
Write-Host "    解压到：$InstallDir（2GB 包，可能需要 1–3 分钟）"
& $sevenZip x -y "-o$InstallDir" $Archive | Out-Null
if ($LASTEXITCODE -ne 0) {
    Stop-WithMessage "解压失败（7z 退出码 $LASTEXITCODE）。检查安装包是否完整。"
}

# 兼容两种解压结构
$nested = Join-Path $InstallDir "ComfyUI_windows_portable"
if (Test-Path (Join-Path $nested "ComfyUI\main.py")) {
    Write-Host "    检测到嵌套目录，移动到 $InstallDir …"
    Get-ChildItem -Path $nested -Force | ForEach-Object {
        Move-Item -Path $_.FullName -Destination $InstallDir -Force
    }
    Remove-Item $nested -Force -Recurse -ErrorAction SilentlyContinue
}

$mainPy = Join-Path $InstallDir "ComfyUI\main.py"
$python = Join-Path $InstallDir "python_embeded\python.exe"
if (-not (Test-Path $mainPy)) { Stop-WithMessage "解压后找不到 $mainPy。安装包结构可能变了，请手动检查。" }
if (-not (Test-Path $python)) { Stop-WithMessage "解压后找不到 $python。安装包可能不完整。" }
Write-Ok "程序本体：$mainPy"
Write-Ok "自带 Python：$python"

# ---------- 4. 模型目录 ----------
Write-Step "配置模型目录"
if ($ModelsDir) {
    New-Item -ItemType Directory -Force -Path $ModelsDir | Out-Null
    Write-ExtraModelPaths -Root $InstallDir -ExternalModels $ModelsDir
} else {
    $modelsPath = Join-Path $InstallDir "ComfyUI\models"
    New-Item -ItemType Directory -Force -Path $modelsPath | Out-Null
    Write-Ok "模型目录：$modelsPath"
}

# ---------- 5. 启动脚本 ----------
Write-Step "生成启动脚本"
Write-StartScripts -Root $InstallDir

# ---------- 6. 校验 ----------
Write-Step "校验安装"
$verify = Join-Path $PSScriptRoot "verify-install.ps1"
if (Test-Path $verify) {
    & powershell -ExecutionPolicy Bypass -File $verify -InstallDir $InstallDir
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "校验未全部通过，请按上面的提示处理。"
    }
} else {
    & $python -c "import torch; print('torch', torch.__version__); print('cuda', torch.cuda.is_available())"
}

# ---------- 7. 下一步 ----------
Write-Step "完成"
Write-Host @"

安装目录：$InstallDir

下一步：
  1. 下载模型：
     python .\scripts\download-models.py --profile standard --dest "$InstallDir\ComfyUI\models"
  2. 启动：
     $InstallDir\start-lowvram.bat
  3. 浏览器打开：
     http://127.0.0.1:8188
  4. 拖入：
     workflows\sd15-basic.json

4GB 显卡请用 start-4gb.bat。
插件导致启动失败时，用 start-safe-mode.bat。
"@

if (-not $NoPause) { Read-Host "按回车退出" | Out-Null }
exit 0