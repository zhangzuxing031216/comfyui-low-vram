# AI-DEPLOY.md · ComfyUI Low-VRAM Deployment Instructions for AI

> **Language / 语言**: [中文](AI-DEPLOY.md) | English

> This document is written for an **AI assistant** to read, not for a human.
> The human only needs to hand the whole document to the AI and say "deploy according to this".
>
> Target machine: Windows 10/11 + NVIDIA GPU (4GB / 6GB / 8GB VRAM preferred)
> Target outcome: ComfyUI starts, the models are visible, and the first 512×512 image is generated.
> Document version: 2026-11 · corresponds to ComfyUI v0.42.1

---

## 0. Your Role Right Now

You are the deployment executor, not a chat assistant. Work according to the protocol below:

1. **Gather evidence first, then act**: at every step, run the check command first and decide the branch from the real output. Do not guess from experience.
2. **Do one thing at a time**: execute one step → paste the command and the raw output → confirm success → then move to the next step.
3. **Do not fabricate**: do not say "done" for a command you did not run; do not say "should be fine" for output you did not see.
4. **Do not overstep**: do not delete the user's existing models or projects; do not install software unrelated to the task; do not write any secrets.
5. **Degrade on failure**: follow the fallback paths in this document; do not get stuck on a single source.
6. **Final delivery must include evidence**: the command text + the actual output + the acceptance result.

---

## 1. Before Starting, Ask the User Only 3 Questions

If the information can already be read from the system, do not ask.

1. Which drive should it be installed to? Default `D:\ComfyUI`, with at least 30GB free (60GB recommended for the standard profile).
2. What GPU is it? If you are unsure, just run `nvidia-smi` and read it.
3. Can the network reach GitHub / Hugging Face? If not, that is fine — use ModelScope / CNB.

**Do not ask** "which model do you want to use" or "do you want plugins installed" — get the minimal loop working first, then extend as needed.

---

## 2. Hard Constraints

- 64-bit Windows only.
- NVIDIA GPUs only (for AMD/Intel, switch to the corresponding portable package; not covered in this document).
- The install path must not contain Chinese characters or spaces.
- Do not use the system Python; you must use the portable build's bundled `python_embeded\python.exe`.
- Do not run `.exe` files of unknown origin; download only the `.7z` and extract it.
- Do not enable `--highvram`.
- Do not install multiple custom nodes at once; make sure native image generation works first.
- Do not modify `C:\Windows`, and do not change global environment variables (unless the user explicitly agrees).
- Do not commit/upload the user's models, output images, or API keys.

---

## 3. Phase 0 · Environment Evidence

Run these in order and record the raw output.

```powershell
# 0.1 OS
[System.Environment]::OSVersion.VersionString
(Get-CimInstance Win32_OperatingSystem).OSArchitecture

# 0.2 GPU
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv

# 0.3 RAM
[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)

# 0.4 Target drive space
Get-PSDrive D | Select-Object Name,@{n='FreeGB';e={[math]::Round($_.Free/1GB,1)}}

# 0.5 Already installed?
Test-Path "D:\ComfyUI\ComfyUI\main.py"
```

### Decision Table

| Result | Branch |
|---|---|
| `nvidia-smi` fails | Stop. Tell the user to install the NVIDIA driver, or switch to CPU/cloud. Do not continue. |
| VRAM < 4GB | Use the `minimal` profile only + SD1.5 + `--novram`. |
| VRAM 4–5GB | `minimal` profile + `start-4gb.bat`. |
| VRAM 6–7GB | `standard` profile + `start-lowvram.bat`. |
| VRAM ≥ 8GB | `standard` profile + `start-lowvram.bat`; SDXL at 1024 can be attempted. |
| Disk < 30GB | Stop. Have the user free up space or choose another drive. |
| `main.py` already exists | Skip to Phase 3 (startup verification); do not overwrite the existing install. |

**Evidence format**:

```text
[Phase 0]
Command: nvidia-smi --query-gpu=...
Output: NVIDIA GeForce RTX 3060 Laptop GPU, 6144 MiB, 560.94
Decision: 6GB → standard profile + lowvram
```

---

## 4. Phase 1 · Install ComfyUI

### 4.1 Preferred: Repository Script

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -InstallDir "D:\ComfyUI"
```

Expected results:

- Exit code 0
- `D:\ComfyUI\ComfyUI\main.py` exists
- `D:\ComfyUI\python_embeded\python.exe` exists
- `D:\ComfyUI\start-lowvram.bat` exists

### 4.2 If the Script Fails: Manual Install

1. Download:
   `https://github.com/Comfy-Org/ComfyUI/releases/download/v0.42.1/ComfyUI_windows_portable_nvidia.7z`
2. If GitHub is unreachable, use the fallback:
   - Ask the user for the path to an already-downloaded `.7z`, then run `install-windows.ps1 -Archive "<path>" -SkipDownload`
   - Or find a package with the same name on ModelScope / a domestic mirror (check that the size is about 2GB)
3. Extract it to `D:\ComfyUI` with 7-Zip.
4. Confirm the directory structure:

```text
D:\ComfyUI\ComfyUI\main.py
D:\ComfyUI\python_embeded\python.exe
```

### 4.3 Verify Python / Torch / CUDA Immediately After Installing

```powershell
D:\ComfyUI\python_embeded\python.exe -c "import torch; print('torch', torch.__version__); print('cuda', torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')"
```

Expected:

```text
torch 2.x.x+cu12x
cuda True
NVIDIA GeForce ...
```

If `cuda False`:

- Driver too old → update the NVIDIA driver.
- A CPU package was downloaded by mistake → download `..._nvidia.7z` again.
- Laptop with dual GPUs → set `python.exe` to High Performance in the NVIDIA Control Panel.

---

## 5. Phase 2 · Download Models

### 5.1 Choose a Profile

| VRAM | profile | Disk | Contents |
|---|---|---|---|
| 4GB | `minimal` | ~4GB | SD1.5 + VAE + LCM + upscale + 2 ControlNets |
| 6–8GB | `standard` | ~23GB | minimal + RealVisXL + Animagine + SDXL VAE + LCM-XL + Union |
| ≥8GB and video needed | `video` | ~42GB | standard + SVD + Wan2.2 + AnimateDiff |

### 5.2 Execute

```powershell
# List first, confirm the ids and sizes
python .\scripts\download-models.py --list

# Download by profile
python .\scripts\download-models.py --profile standard --dest "D:\ComfyUI\ComfyUI\models"
```

Expected:

- Each file prints `OK <filename> <size>`
- At the end it prints `成功 N，跳过 M，失败 0` (N succeeded, M skipped, 0 failed)
- Exit code 0

### 5.3 Fallback Order on Failure

The script already tries the sources in the order given in `models.json`. If it still fails:

1. Switch to `--source modelscope`
2. Switch to `--source cnb`
3. Switch to `--source hf`
4. Have the user download manually from <https://modelscope.cn/models> and put the files in the corresponding directory
5. Record the missing files; do not block "the first image": first get a run working with only the SD1.5 that is already downloaded

### 5.4 Verify

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\models\checkpoints" |
  Select-Object Name, @{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

Decision:

- `.safetensors` size within 5% of the manifest → pass
- A `.part` file appears → download did not finish, re-run
- Only a few KB → you downloaded a web page/pointer; delete it and download again

---

## 6. Phase 3 · Startup Verification

### 6.1 Start

```powershell
cd /d D:\ComfyUI
start-lowvram.bat
```

Or directly:

```powershell
D:\ComfyUI\python_embeded\python.exe -s D:\ComfyUI\ComfyUI\main.py --lowvram --use-pytorch-cross-attention --port 8188 --preview-method auto
```

> This step blocks the terminal, which is normal. Start it in the background, or ask the user to keep the window open.

### 6.2 Wait and Check

```powershell
# Poll, up to 120 seconds
1..60 | ForEach-Object {
  try {
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:8188/system_stats" -TimeoutSec 2
    $r | ConvertTo-Json -Depth 4
    break
  } catch { Start-Sleep -Seconds 2 }
}
```

Expected:

- HTTP 200
- The JSON contains `system.comfyui_version`
- `devices[0].name` is the NVIDIA GPU
- `devices[0].vram_total` matches the VRAM

### 6.3 Check Whether the Models Are Detected

```powershell
Invoke-RestMethod "http://127.0.0.1:8188/models/checkpoints" | ConvertTo-Json
Invoke-RestMethod "http://127.0.0.1:8188/models/loras" | ConvertTo-Json
Invoke-RestMethod "http://127.0.0.1:8188/models/controlnet" | ConvertTo-Json
```

Expected: the returned array shows the filenames you downloaded (without paths).

If it is empty:

- Check whether the files are in `ComfyUI\models\checkpoints`.
- Check whether the extension is `.safetensors` / `.ckpt`.
- Restart ComfyUI.
- Check whether `extra_model_paths.yaml` points to a wrong directory.

---

## 7. Phase 4 · First Image Acceptance

### 7.1 Manual Acceptance (Recommended)

1. Open <http://127.0.0.1:8188> in a browser.
2. Drag `workflows/sd15-basic.json` into it.
3. In `Load Checkpoint`, select the SD1.5 model you downloaded.
4. Click `Queue`.
5. Wait 5–30 seconds.
6. Confirm:
   - An image appears on the page
   - It is not all black / corrupted
   - There is a new file in `D:\ComfyUI\ComfyUI\output`

### 7.2 Programmatic Acceptance (Optional)

If the user permits, submit the workflow through the ComfyUI API:

```powershell
# Read the workflow and submit it (you need to convert the JSON into API format, or use an API workflow saved directly from the UI)
$body = Get-Content ".\workflows\sd15-basic-api.json" -Raw
Invoke-RestMethod -Uri "http://127.0.0.1:8188/prompt" -Method Post -Body $body -ContentType "application/json"
```

> Note: UI workflows and API workflows have different formats. If you do not have the API format, do not fake it — go with manual acceptance instead.

### 7.3 Acceptance Criteria

| Item | Pass criteria |
|---|---|
| Service | `/system_stats` returns 200 |
| Device | NVIDIA GPU detected |
| Models | `/models/checkpoints` is non-empty |
| Image generation | 512×512 completes within 60 seconds (6GB) |
| Output | A new PNG in the `output` directory |
| Log | No `OutOfMemoryError` / `Traceback` |

Only when everything passes is it done. If any item fails, keep troubleshooting; do not declare success.

---

## 8. Phase 5 · Low-VRAM Troubleshooting Tree

### 8.1 Startup Failure

```text
Service did not come up
├─ Port in use → switch to --port 8189
├─ Python reports ModuleNotFound → use the portable python, not the system python
├─ Plugin errors → add --disable-all-custom-nodes
├─ CUDA unavailable → update the driver / reinstall the nvidia package
└─ Path contains Chinese characters → switch to a pure ASCII path
```

### 8.2 Out of VRAM (OOM)

Try these in order, changing only one variable per step:

1. Resolution 1024 → 768 → 512
2. `batch_size` → 1
3. `VAE Decode` → `VAE Decode (Tiled)`, `tile_size` 512 → 256
4. Model SDXL → SD1.5
5. Add `--lowvram` to the launch arguments
6. If that still fails, add `--novram`
7. Close browser video, games, emulators
8. Set virtual memory to 32–64GB

### 8.3 Models Not Showing

```text
Model list is empty
├─ Wrong directory → put it in models\checkpoints
├─ Not restarted → restart ComfyUI
├─ Wrong extension → only .safetensors / .ckpt / .pt are recognized
├─ Corrupted file → check the size, download again
└─ extra_model_paths.yaml points to the wrong place → fix base_path
```

### 8.4 Abnormal Image Output

| Symptom | Action |
|---|---|
| All black | Change the VAE; check whether the model is complete |
| Corrupted image | Model is corrupted; switch to fp16; lower the resolution |
| Blurry | Raise steps to 25–30; change the sampler; add upscaling |
| Broken hands | Add negative prompts; use FaceDetailer/HandDetailer; change the model |
| Grayish colors | Change the VAE; set CFG to 5–7; switch to SDXL |

---

## 9. Phase 6 · Delivery Report Template

When finished, output in this format (no filler):

```text
[Conclusion] Success / Partial success / Failure

[Environment]
- OS:
- GPU / VRAM:
- Driver:
- Install path:
- ComfyUI version:

[Execution]
1. Install: command + result
2. Models: profile + success/failure list
3. Startup: command + port
4. Acceptance: /system_stats summary + model list count + first-image time

[Artifacts]
- Launch script:
- Workflows:
- Output directory:
- Logs:

[Unresolved / Risks]
- ...

[Suggested next steps]
- ...
```

---

## 10. Prohibited Actions (Hard Rules)

1. Do not delete the user's existing `models`, `output`, or `custom_nodes`.
2. Do not overwrite the user's `extra_model_paths.yaml`: read before editing, and back up before editing.
3. Do not install integrated packages / `.exe` files of unknown origin.
4. Do not upload models, images, or API keys anywhere.
5. Do not say "deployment complete" without having run the acceptance commands.
6. Do not fake `/system_stats` output in order to "look successful".
7. Do not force SDXL at 1024 on a 4GB machine.
8. Do not install 10 plugins at once; when something breaks, you cannot isolate the cause.

---

## 11. Quick Command Card

```powershell
# Environment
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv
powershell -ExecutionPolicy Bypass -File .\scripts\check-gpu.ps1

# Install
powershell -ExecutionPolicy Bypass -File .\scripts\install-windows.ps1 -InstallDir "D:\ComfyUI"

# Models
python .\scripts\download-models.py --list
python .\scripts\download-models.py --profile standard --dest "D:\ComfyUI\ComfyUI\models"

# Verify
D:\ComfyUI\python_embeded\python.exe -c "import torch; print(torch.__version__, torch.cuda.is_available())"
powershell -ExecutionPolicy Bypass -File .\scripts\verify-install.ps1 -InstallDir "D:\ComfyUI"

# Launch
cd /d D:\ComfyUI
start-lowvram.bat

# Acceptance
Invoke-RestMethod "http://127.0.0.1:8188/system_stats"
Invoke-RestMethod "http://127.0.0.1:8188/models/checkpoints"
```

---

## 12. Versions and Compatibility

| Component | Version verified in this document | Notes |
|---|---|---|
| Windows | 10 / 11 64-bit | 32-bit is not supported |
| ComfyUI | v0.42.1 | Newer versions are generally compatible, but plugins may not be |
| Python | Bundled with the portable build (around 3.12) | Do not mix in the system Python |
| PyTorch | Bundled with the portable build, cu12x | Do not upgrade manually unless you know exactly what you are doing |
| CUDA driver | ≥ 550 | Older versions may not support the bundled torch |

> If the user already has another ComfyUI installed (the Akiba (秋叶) integrated package, etc.), do not install it again. First confirm whether the existing instance starts and where its model directories are, then decide whether to reuse it.

---

## 13. One Last Thing to Tell the User

When deployment is complete, tell the user:

> You can now open <http://127.0.0.1:8188>, drag in `workflows/sd15-basic.json`, select a model, and click Queue.
> The first run will be slow, the second will be fast. Start with 512×512, and only try 768 or SDXL once it is stable.
> If you hit an error, paste the last 20 lines of the console to me.