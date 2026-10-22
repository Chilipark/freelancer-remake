@echo off
REM Use this if the game shows a black screen or will not start
REM (older or integrated graphics without Vulkan).
start "" "%~dp0StarlaneRogue.exe" --rendering-method gl_compatibility
