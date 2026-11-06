@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%python_embeded\python.exe" set "ROOT=%~dp0.."
cd /d "%ROOT%"
echo.
echo   ComfyUI low-VRAM mode (6GB / 8GB)
echo   Wait for: To see the GUI go to http://127.0.0.1:8188
echo.
"%ROOT%python_embeded\python.exe" -s "%ROOT%ComfyUI\main.py" --lowvram --use-pytorch-cross-attention --port 8188 --preview-method auto
if errorlevel 1 pause