:: compile_shader.bat
@echo off
set QSB=D:/Programming/QT/6.10.1/mingw_64/bin/qsb.exe
mkdir shaders\qsb 2>nul
%QSB% ^
  --glsl "450" ^
  --qt6 ^
  -o ^
  shaders/qsb/transitions.frag.qsb shaders/transitions.frag

echo Shader compiled to shaders/qsb/transitions.frag.qsb