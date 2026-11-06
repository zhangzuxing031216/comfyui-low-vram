@echo off
setlocal
set "ROOT=%~dp0"
if not exist "%ROOT%python_embeded\python.exe" set "ROOT=%~dp0.."
cd /d "%ROOT%"
echo.
echo   ComfyUI 4GB mode (--novram, slower but safer)
echo   Wait for: To see the GUI go to http://127.0.0.1:8188
echo.
"%ROOT%python_embeded\python.exe" -s "%ROOT%ComfyUI\main.py" --novram --use-pytorch-cross-attention --reserve-vram 0.3 --port 8188 --preview-method auto
if errorlevel 1 pause