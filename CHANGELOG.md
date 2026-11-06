# 更新记录 / Changelog

版本号遵循 SemVer；当前版本见 `VERSION`，发布和对比流程见 `VERSIONING.md`。

## v0.1.0 · 2026-11-06 · 首次发布

### 新增

- 4GB / 6GB / 8GB 显存的 ComfyUI 低显存部署教程：硬件检查、安装、模型下载、启动参数、首图、排错、维护。
- 中英双语人看文档：`README.md` / `README.en.md`，顶部可切换。
- 中英双语 AI 协议：`AI-DEPLOY.md` / `AI-DEPLOY.en.md`。
- 脚本：
  - `scripts/install-windows.ps1`：下载便携版、解压、生成低显存启动脚本。
  - `scripts/download-models.py` + `scripts/models.json`：多源模型下载、断点续传、自动降级。
  - `scripts/check-gpu.ps1`：判断显存档位。
  - `scripts/verify-install.ps1`：检查文件、Torch、CUDA、模型目录。
- 工作流：
  - `workflows/sd15-basic.json`
  - `workflows/sdxl-768-lowvram.json`
- 文档：`docs/01-hardware.md` 至 `docs/09-maintenance.md`。
- 图片：流程、目录、界面地图、排错树、显存对比等 SVG 示意图。
- 真实截图：`docs/images/07-example-output.jpg`、`docs/images/08-real-ui.png`。
- 实测：RTX 3060 Laptop 6GB，RealVisXL，768×768，20 步，`--lowvram`。

### 说明

- 这是第一个公开版本，作为后续版本对比的基线。
- 与下一版本比较：`git diff v0.1.0..v0.2.0`。
- 已知边界：8GB 跑 SDXL 1024 仍偏慢；本机实测未覆盖 SD1.5 checkpoint。

## 未发布 / Unreleased

- [ ] 补 macOS / Linux 安装说明。
- [ ] 补 AMD / Intel 显卡路径。
- [ ] 补 SD3.5 / Flux 低显存实测。
- [ ] 补 ComfyUI 新版本兼容性验证。
- [ ] 模型链接定期巡检（每季度）。