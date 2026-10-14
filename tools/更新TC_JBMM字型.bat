@echo off
rem TC-JetBrainsMapleMono 字型一鍵更新（雙擊執行；會跳一次 UAC 請按「是」）
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-TCJBMM.ps1" %*
