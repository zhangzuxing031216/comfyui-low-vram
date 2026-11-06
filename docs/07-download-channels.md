# 07 · 模型下载通道：主通道、备用通道、怎么选

> 国内下模型，最大的问题不是“找不到”，而是“下到一半断了”“下到假文件”“速度 30KB/s”。
> 这一章给你一套可执行的通道顺序。

---

## 1. 通道总表

| 通道 | 地址 | 登录 | 国内速度 | 适合 | 风险 |
|---|---|---|---|---|---|
| **ModelScope 魔搭** | <https://modelscope.cn/models> | 不需要 | 快 | 主流底模、ControlNet、Wan | 低 |
| **CNB 社区镜像** | <https://cnb.cool/ai-models/zhanzhangtuijian/ComfyUI_models> | 不需要 | 快 | ComfyUI 常用模型 | 中（第三方） |
| **hf-mirror** | <https://hf-mirror.com/> | 不需要 | 中 | 国外模型 | 中（镜像） |
| **Hugging Face** | <https://huggingface.co/> | 部分要 | 国内常慢/断 | 最新模型 | 低（官方） |
| **Civitai** | <https://civitai.com/> | 要 | 不稳定 | 社区底模、LoRA | 中（需甄别） |
| **LiblibAI** | <https://www.liblib.art/> | 要 | 快 | 国内作者模型 | 低 |
| **GitHub** | <https://github.com/Comfy-Org/ComfyUI/releases> | 不需要 | 不稳定 | 安装包、插件 | 低 |
| **百度网盘/夸克** | — | 要 | 看会员 | 整合包/朋友分享 | 高（可能带毒） |

**推荐顺序**：

```text
ModelScope → CNB → hf-mirror → Civitai/Liblib → 网盘
```

---

## 2. ModelScope（魔搭）：国内主通道

### 2.1 网页下载

1. 打开 <https://modelscope.cn/models>。
2. 搜索模型名，例如 `RealVisXL`、`animagine-xl-4.0`。
3. 进模型页 → “模型文件”。
4. 找到 `.safetensors`，点下载。
5. 放到对应 `models\` 子目录。

### 2.2 直接拼 URL

ModelScope 的文件直链格式：

```text
https://modelscope.cn/models/<仓库名>/resolve/master/<文件路径>
```

例：

```text
https://modelscope.cn/models/stabilityai/sdxl-vae/resolve/master/sdxl_vae.safetensors
```

### 2.3 用 SDK

```powershell
D:\ComfyUI\python_embeded\python.exe -m pip install modelscope
```

```python
from modelscope import snapshot_download
p = snapshot_download("stabilityai/sdxl-vae", cache_dir=r"D:\modelscope-cache")
print(p)
```

优点：自动断点续传、自动校验。
缺点：会多一层缓存目录，需要手动移到 `models`。

### 2.4 适合下什么

- SDXL / SD1.5 主流底模（看有没有镜像）
- ControlNet fp16
- VAE
- Wan2.2 系列
- 文本编码器

### 2.5 注意

- 不是所有 Hugging Face 模型都有镜像。
- 搜不到时，用仓库名搜，不要只搜中文。
- 下完看文件大小。

---

## 3. CNB 社区镜像：速度快的备用

### 3.1 地址

- <https://cnb.cool/ai-models/zhanzhangtuijian/ComfyUI_models>
- <https://cnb.cool/itq5/comfyui_models>

### 3.2 特点

- 腾讯 CNB 平台
- Git LFS 存储
- 实测 1.5 MB/s 左右
- 覆盖 ComfyUI 常用模型：底模、ControlNet、放大、抠图、修复、SVD、LivePortrait

### 3.3 怎么下

**方法 A：脚本（推荐）**

```powershell
python .\scripts\download-models.py --profile standard --source cnb --dest "D:\ComfyUI\ComfyUI\models"
```

脚本会自动解析 LFS 指针，不需要你懂 Git。

**方法 B：网页**

打开仓库 → 找文件 → Download。

**方法 C：git clone**

```powershell
git lfs install
git clone https://cnb.cool/ai-models/zhanzhangtuijian/ComfyUI_models.git
```

> 仓库很大，不建议全 clone。

### 3.4 注意

- 第三方镜像，文件可能更新不及时。
- 下完核对大小。
- 失效时换 ModelScope / hf-mirror。

---

## 4. hf-mirror：Hugging Face 的国内镜像

### 4.1 地址

<https://hf-mirror.com/>

### 4.2 用法

把 Hugging Face 链接里的域名替换：

```text
https://huggingface.co/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors
↓
https://hf-mirror.com/SG161222/RealVisXL_V4.0/resolve/main/RealVisXL_V4.0.safetensors
```

### 4.3 环境变量

用 `huggingface-cli` / `diffusers` 时：

```powershell
$env:HF_ENDPOINT = "https://hf-mirror.com"
```

永久：

```powershell
[Environment]::SetEnvironmentVariable("HF_ENDPOINT", "https://hf-mirror.com", "User")
```

### 4.4 注意

- 镜像不是官方，可能同步延迟。
- 速度看时段，有时只有几十 KB/s。
- 大文件建议用脚本断点续传。

---

## 5. Hugging Face 官方

### 5.1 什么时候用

- 镜像没有的新模型
- 需要登录的 gated 模型
- 需要精确版本

### 5.2 下载方式

```powershell
D:\ComfyUI\python_embeded\python.exe -m pip install huggingface_hub
```

```python
from huggingface_hub import hf_hub_download
p = hf_hub_download(
    repo_id="SG161222/RealVisXL_V4.0",
    filename="RealVisXL_V4.0.safetensors",
    local_dir=r"D:\ComfyUI\ComfyUI\models\checkpoints",
)
print(p)
```

### 5.3 注意

- 国内直连经常断。
- 大文件用 `hf_transfer` 或镜像。
- 不要泄露 token。

---

## 6. Civitai：社区模型首选

### 6.1 适合

- 社区底模（RealVisXL、Juggernaut、majicMIX）
- LoRA（角色、画风、姿势）
- 风格模型

### 6.2 怎么下

1. 打开 <https://civitai.com/>。
2. 搜模型名。
3. 进模型页 → 选版本 → Download。
4. 注意文件大小和版本。
5. 放到对应目录。

### 6.3 注意

- 国内可能需要网络工具。
- 有些模型要登录。
- 下 `.safetensors`，不要下 `.ckpt`（除非你信任作者）。
- 看模型页的“Trigger Words”，LoRA 需要触发词。

---

## 7. LiblibAI：国内社区

### 7.1 地址

<https://www.liblib.art/>

### 7.2 适合

- 国内作者的底模 / LoRA
- 国风、二次元
- 中文提示词友好

### 7.3 注意

- 需要登录。
- 部分模型有使用限制。
- 下载后看文件名，别下成预览图。

---

## 8. GitHub：安装包和插件

### 8.1 ComfyUI 安装包

<https://github.com/Comfy-Org/ComfyUI/releases>

文件名：

```text
ComfyUI_windows_portable_nvidia.7z
```

### 8.2 插件

在 ComfyUI Manager 里搜，或：

```powershell
cd D:\ComfyUI\ComfyUI\custom_nodes
git clone <插件仓库>
```

### 8.3 GitHub 下不动

- 用镜像/加速（自行确认可用性）。
- 让朋友下好传网盘。
- 用国内整合包过渡。

---

## 9. 网盘：最后手段

### 9.1 只信

- 官方/作者本人分享
- 熟人
- 有 SHA256 校验的包

### 9.2 不要

- 下 `.exe` 安装器
- 下“一键包”里带未知脚本
- 关闭杀毒软件
- 用管理员权限运行来源不明的 bat

### 9.3 下完检查

```powershell
Get-FileHash "文件路径" -Algorithm SHA256
```

和分享页的哈希对比。

---

## 10. 文件完整性检查

### 10.1 看大小

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\models" -Recurse -File |
  Select-Object FullName,@{n='GB';e={[math]::Round($_.Length/1GB,2)}} |
  Sort-Object GB -Descending
```

### 10.2 看是不是 LFS 指针

用记事本打开小文件，如果看到：

```text
version https://git-lfs.github.com/spec/v1
oid sha256:...
size ...
```

说明下的是指针，不是模型。

### 10.3 sha256

如果下载页给了哈希：

```powershell
Get-FileHash "D:\...\model.safetensors" -Algorithm SHA256
```

对比。

### 10.4 safetensors 头

```powershell
Format-Hex -Path "D:\...\model.safetensors" -Count 16
```

正常是长度 + `{`，不是 `<html>`。

---

## 11. 速度优化

| 方法 | 效果 |
|---|---|
| 用有线网络 | 比 Wi-Fi 稳 |
| 避开晚高峰 | 晚上 8–11 点最慢 |
| 用脚本断点续传 | 断了不用重来 |
| 一次只下一个大文件 | 避免抢带宽 |
| 用 ModelScope | 国内通常最快 |
| 换 DNS | 有时有用 |
| 关闭代理 | 国内源不需要代理 |

### 测速

```powershell
# 测试 ModelScope 小文件
curl.exe -L -o NUL -w "%{speed_download} B/s" "https://modelscope.cn/models/stabilityai/sdxl-vae/resolve/master/sdxl_vae.safetensors"
```

---

## 12. 常见下载坑

| 现象 | 原因 | 解决 |
|---|---|---|
| 下到几 KB | 下到网页/LFS 指针 | 用脚本；换“模型文件”页 |
| 下到一半断 | 网络/SSL | 断点续传；换源 |
| 速度 30KB/s | 源限速/晚高峰 | 换 ModelScope/CNB |
| 文件大小对但加载失败 | 内部损坏 | 重下；校验哈希 |
| 下成 `.ckpt` | 选错格式 | 优先 `.safetensors` |
| 下成预览图 | 点错按钮 | 看文件大小 |
| 解压密码 | 网盘分享 | 找分享者；别乱下 |

---

## 13. 本章检查清单

- [ ] 知道 ModelScope 怎么搜、怎么下
- [ ] 知道 hf-mirror 怎么替换域名
- [ ] 知道 CNB 是备用
- [ ] 知道 Civitai / Liblib 适合社区模型
- [ ] 会看文件大小
- [ ] 会识别 LFS 指针
- [ ] 不会下来源不明的 `.exe`
- [ ] 知道网盘是最后手段