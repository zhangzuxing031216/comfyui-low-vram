@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%python_embeded\python.exe" set "ROOT=%~dp0.."
cd /d "%ROOT%"
echo.
echo   ComfyUI safe mode (all custom nodes disabled)
echo   Use this to check whether a plugin is causing the problem.
echo.
"%ROOT%python_embeded\python.exe" -s "%ROOT%ComfyUI\main.py" --lowvram --use-pytorch-cross-attention --disable-all-custom-nodes --port 8188
if errorlevel 1 pause