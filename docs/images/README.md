# 图片说明

本目录目前放的是 **SVG 示意图**，不是真实截图。这样做的原因：

- 截图会随 ComfyUI 版本变化，容易过期；
- 示意图能突出“看哪里”，不会被界面细节干扰；
- SVG 体积小、可缩放、GitHub 直接渲染。

## 现有图

| 文件 | 内容 |
|---|---|
| `01-flow.svg` | 6 步部署闭环 |
| `02-folder.svg` | 目录结构与模型位置 |
| `03-ui-map.svg` | ComfyUI 界面地图（示意图） |
| `04-troubleshooting.svg` | 排错决策树 |

## 如果你要补真实截图

建议补这几张，命名用英文，放在本目录：

| 文件名 | 拍什么 | 注意 |
|---|---|---|
| `shot-01-download.png` | GitHub Releases 下载页 | 圈出 `ComfyUI_windows_portable_nvidia.7z` |
| `shot-02-extract.png` | 7-Zip 解压到 D:\ComfyUI | 显示目标路径 |
| `shot-03-console.png` | 启动成功的控制台 | 保留 `To see the GUI...` 那一行 |
| `shot-04-ui.png` | 浏览器首屏 | 显示节点画布和 Queue |
| `shot-05-model.png` | Load Checkpoint 下拉框 | 显示模型名 |
| `shot-06-output.png` | 出图结果 + output 目录 | 证明真的出图 |

### 截图规范

1. 分辨率 ≥ 1280×720，不要拉伸。
2. 不要拍到账号、API Key、个人信息。
3. 关键区域用红框/箭头标出，不要整张涂鸦。
4. PNG 格式，单张 < 500KB。
5. 截图里的路径、模型名要和文档一致。

### 在 Markdown 里引用

```markdown
![下载便携版](docs/images/shot-01-download.png)
```

> 不要用 AI 生成“假截图”冒充真实界面。示意图可以，伪造截图不行。