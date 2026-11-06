# 更新记录

## 2026-11-06 · 中英双语

- 新增 `README.en.md`：完整英文教程，不是摘要；`README.md` 顶部可切换。
- 新增 `AI-DEPLOY.en.md`：英文 AI 部署协议；`AI-DEPLOY.md` 顶部可切换。
- 项目名改为中英双语：README 标题与首屏名称行同时出现“ComfyUI 低显存部署 / ComfyUI Low-VRAM Deployment”。
- 英文版保留全部命令、路径、参数、验收标准和风险提示。

## 2026-11-06 · 预览图

- 新增 `docs/images/05-ui-mockup.svg`：装完后的工作流界面示意。
- 新增 `docs/images/06-vram-compare.svg`：4GB / 6GB / 8GB 能力边界与 6GB 实测速度。
- 新增 `docs/images/07-example-output.jpg`：本机 RTX 3060 6GB 真实出图。
- 新增 `docs/images/08-real-ui.png`：本机 ComfyUI 真实界面截图。
- `README.md` 增加“效果预览”和首屏徽章/简介/新手 3 步。

## 2026-11-06 · v0.1

- 初版：面向 4GB / 6GB / 8GB 显存的 ComfyUI 入门方案。
- 双文档：
  - `README.md`：给人看，从检查硬件到第一张图。
  - `AI-DEPLOY.md`：给 AI 看，含取证、分支、验收、故障树。
- 脚本：
  - `install-windows.ps1`：下载便携版、解压、生成低显存启动脚本。
  - `download-models.py` + `models.json`：多源模型下载、断点续传、自动降级。
  - `verify-install.ps1`：检查文件、Torch、CUDA、模型目录。
  - `check-gpu.ps1`：判断显存档位。
- 工作流：
  - `sd15-basic.json`
  - `sdxl-768-lowvram.json`
- 文档：硬件、安装、模型、低显存、首图、排错、下载通道、FAQ、维护。
- 图示：流程、目录、界面地图、排错树（SVG，非截图）。

## 待办

- [ ] 补真实截图（Windows 解压、ComfyUI 首屏、模型下拉框、出图结果）。
- [ ] 补 macOS / Linux 安装说明。
- [ ] 补 AMD / Intel 显卡路径。
- [ ] 补 SD3.5 / Flux 低显存实测。
- [ ] 模型链接定期巡检（每季度）。