@echo off
rem Runs a command inside the Pixal3D env (MSVC + CUDA 12.4 + Python 3.10).
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%"
if exist "D:\pixal3d\BuildTools\VC\Auxiliary\Build\vcvars64.bat" call "D:\pixal3d\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
set "CUDA_HOME=D:\pixal3d\env"
set "CUDA_PATH=D:\pixal3d\env"
set "PATH=D:\pixal3d\env;D:\pixal3d\env\Scripts;D:\pixal3d\env\bin;D:\pixal3d\env\Library\bin;%PATH%"
set "HF_HOME=D:\pixal3d\hf"
set "TORCH_HOME=D:\pixal3d\torch"
set "PIP_CACHE_DIR=D:\pixal3d\pipcache"
set "TORCH_CUDA_ARCH_LIST=7.5"
set "DISTUTILS_USE_SDK=1"
set "ATTN_BACKEND=sdpa"
set "PYTHONUTF8=1"
%*
