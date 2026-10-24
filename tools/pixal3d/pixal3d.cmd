@echo off
rem Pixal3D image -> GLB. Usage: pixal3d.cmd --check  ^|  --image in.png --output out.glb [--tris 20000] [--texture 1024] [--seed 42] [--fov 0.2] [--force]
rem gen.py lives in the repo (tools\pixal3d\gen.py); set PIXAL3D_GEN to use another checkout.
if not defined PIXAL3D_GEN set "PIXAL3D_GEN=\\wsl.localhost\Ubuntu\home\cj\roblox\martial-world\tools\pixal3d\gen.py"
call "D:\pixal3d\envrun.cmd" python "%PIXAL3D_GEN%" %*
