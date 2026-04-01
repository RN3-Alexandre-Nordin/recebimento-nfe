@echo off
set "SCRIPT_DIR=%~dp0Script"
set PYTHON_EXE=python

echo Iniciando Processamento de XML...
%PYTHON_EXE% "%SCRIPT_DIR%\nfe_xml_to_csv.py"
echo Processamento concluído. Verifique os logs na pasta Logs.
pause
