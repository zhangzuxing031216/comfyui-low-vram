# 09 · 维护、备份、升级、搬家

> ComfyUI 本身不复杂，复杂的是插件和模型越堆越多。这一章教你怎么让它一直能跑。

---

## 1. 版本策略

| 组件 | 策略 |
|---|---|
| ComfyUI 本体 | 稳定版，别追 nightly |
| PyTorch | 用便携版自带，别乱升级 |
| 插件 | 需要才装，装完验证 |
| 模型 | 常用 3–5 个，其他归档 |

**原则**：能跑就别动。升级前先备份。

---

## 2. 升级 ComfyUI

### 2.1 便携版

```bat
cd /d D:\ComfyUI
update\update_comfyui.bat
```

### 2.2 升级前

```powershell
# 备份插件和工作流
$ts = Get-Date -Format yyyyMMdd-HHmm
Copy-Item "D:\ComfyUI\ComfyUI\custom_nodes" "D:\ComfyUI\_backup\custom_nodes-$ts" -Recurse
Copy-Item "D:\ComfyUI\ComfyUI\user" "D:\ComfyUI\_backup\user-$ts" -Recurse
```

### 2.3 升级后

1. 启动。
2. 看有没有 `IMPORT FAILED`。
3. 跑一张 512×512。
4. 再跑一个带 ControlNet/LoRA 的工作流。
5. 都正常再继续用。

### 2.4 升级失败怎么回滚

- 便携版没有自动回滚。
- 重新解压旧版本，或删掉新版本重装。
- 所以升级前要备份 `custom_nodes` / `user`。

---

## 3. 备份什么

| 内容 | 大小 | 优先级 | 说明 |
|---|---|---|---|
| `models` | 大 | ★★★ | 重下花时间；至少备份常用 |
| `custom_nodes` | 小 | ★★★★ | 插件和配置 |
| `user` | 小 | ★★★★ | 工作流、设置、预设 |
| `output` | 中 | ★★ | 作品 |
| `extra_model_paths.yaml` | 极小 | ★★★★ | 模型路径 |
| `python_embeded` | 大 | ★ | 可重装 |
| `__pycache__` | 小 | 0 | 不备份 |

### 3.1 备份命令

```powershell
$ts = Get-Date -Format yyyyMMdd-HHmm
$dst = "E:\ComfyUI-backup\$ts"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

Copy-Item "D:\ComfyUI\ComfyUI\custom_nodes" "$dst\custom_nodes" -Recurse
Copy-Item "D:\ComfyUI\ComfyUI\user" "$dst\user" -Recurse
Copy-Item "D:\ComfyUI\ComfyUI\extra_model_paths.yaml" "$dst\" -ErrorAction SilentlyContinue
Copy-Item "D:\ComfyUI\start-*.bat" "$dst\" -ErrorAction SilentlyContinue

# 模型清单（不复制大文件）
Get-ChildItem "D:\ComfyUI\ComfyUI\models" -Recurse -File |
  Select-Object FullName,Length |
  Export-Csv "$dst\models.csv" -NoTypeInformation -Encoding UTF8
```

### 3.2 恢复

1. 重装同版本 ComfyUI。
2. 把 `custom_nodes` / `user` 复制回去。
3. 模型按 `models.csv` 放回。
4. 启动验证。

---

## 4. 清理磁盘

### 4.1 找大文件

```powershell
Get-ChildItem "D:\ComfyUI" -Recurse -File |
  Sort-Object Length -Descending |
  Select-Object -First 30 FullName,@{n='GB';e={[math]::Round($_.Length/1GB,2)}}
```

### 4.2 清理项

| 项 | 说明 |
|---|---|
| `output` 旧图 | 按月归档 |
| `.part` | 没下完的模型 |
| `_download` | 安装包，装完可删 |
| `temp` | 临时文件 |
| `__pycache__` | 缓存 |
| 不用的模型 | 移到机械盘/删除 |
| 不用的插件 | 移到 `custom_nodes.disabled` |

### 4.3 命令

```powershell
# 删 .part
Get-ChildItem "D:\ComfyUI\ComfyUI\models" -Recurse -Filter *.part | Remove-Item -Force

# 删 __pycache__
Get-ChildItem "D:\ComfyUI" -Recurse -Directory -Filter __pycache__ | Remove-Item -Recurse -Force

# 清空 temp（确认没有正在跑的任务）
Remove-Item "D:\ComfyUI\ComfyUI\temp\*" -Recurse -Force -ErrorAction SilentlyContinue
```

---

## 5. 插件管理

### 5.1 查看插件

```powershell
Get-ChildItem "D:\ComfyUI\ComfyUI\custom_nodes" -Directory |
  Select-Object Name,LastWriteTime
```

### 5.2 禁用插件

```powershell
# 建一个禁用目录
New-Item -ItemType Directory -Force -Path "D:\ComfyUI\ComfyUI\custom_nodes.disabled" | Out-Null

# 移动
Move-Item "D:\ComfyUI\ComfyUI\custom_nodes\插件名" "D:\ComfyUI\ComfyUI\custom_nodes.disabled\"
```

重启生效。

### 5.3 判断插件是否必要

- 工作流用到 → 留
- 一个月没打开 → 移走
- 启动报错 → 先移走
- 不知道干什么 → 移走

---

## 6. 模型管理

### 6.1 命名规范

```text
<模型名>_<版本>_<精度>.safetensors
```

例：

```text
RealVisXL_V4.0_fp16.safetensors
animagine-xl-4.0_opt.safetensors
```

不要用：

```text
最终版.safetensors
新建文件夹(2).safetensors
model(1).safetensors
```

### 6.2 记录清单

维护一个 `models.csv`：

```csv
name,type,size_gb,source,use,date
RealVisXL_V4.0,checkpoint,6.46,hf,写实人像,2026-11
```

### 6.3 归档

不用的模型：

```powershell
Move-Item "D:\ComfyUI\ComfyUI\models\checkpoints\旧模型.safetensors" "E:\ComfyUI-archive\checkpoints\"
```

---

## 7. 搬家（换电脑/换盘）

### 7.1 只搬程序

1. 新机器装同版本 ComfyUI。
2. 复制 `custom_nodes` / `user` / `extra_model_paths.yaml`。
3. 重新下模型。

### 7.2 整体搬

1. 关 ComfyUI。
2. 复制整个 `D:\ComfyUI`。
3. 新路径不能含中文。
4. 启动脚本里的路径要改（如果用了绝对路径）。
5. 模型路径 `extra_model_paths.yaml` 要改。

### 7.3 注意

- 便携版的 Python 有绝对路径依赖，**不要直接改目录名**。
- 搬完先跑 `verify-install.ps1`。

---

## 8. 安全

### 8.1 不要暴露到公网

默认只监听 `127.0.0.1`。不要随便加 `--listen 0.0.0.0`，除非你知道怎么加认证/防火墙。

### 8.2 插件风险

- 只从可信仓库装。
- 看 issues / star / 最近更新。
- 不要运行来源不明的 `.bat` / `.exe`。

### 8.3 模型风险

- 优先 `.safetensors`。
- 不要加载来源不明的 `.ckpt`。
- 网盘包先杀毒。

### 8.4 隐私

- 本地出图不上传。
- 云端平台会看到你的提示词和图片。
- 不要把 API Key 写进工作流。

---

## 9. 日常检查清单

### 每周

- [ ] 清一次 `output` 旧图
- [ ] 看磁盘剩余
- [ ] 关掉不用的插件

### 每月

- [ ] 备份 `custom_nodes` / `user`
- [ ] 整理模型，归档不用的
- [ ] 更新一次 ComfyUI（如果稳定）

### 出问题后

- [ ] 记录现象、报错、处理
- [ ] 下次遇到能快速定位

---

## 10. 本章检查清单

- [ ] 知道升级前备份什么
- [ ] 会禁用插件
- [ ] 会清理 `.part` / `__pycache__`
- [ ] 会给模型起可读的名字
- [ ] 知道怎么搬家
- [ ] 不会把 8188 暴露到公网