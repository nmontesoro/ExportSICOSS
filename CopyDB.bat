@echo off

SET SIAP=%1
SET PATHEMPRESA=%2
SET PATHSICOSS=%3
SET PATHEXPORT=%4

echo Abra el SICOSS y luego siga las instrucciones. Presione enter para continuar (se abrira SIAP)...
pause > nul

start %SIAP%

echo.
echo Si ya abrio SICOSS, presione enter...
pause > nul

IF NOT EXIST %PATHEMPRESA%\sijp12\ MKDIR %PATHEMPRESA%\sijp12
IF NOT EXIST %PATHEXPORT% MKDIR %PATHEXPORT%

copy %PATHSICOSS%\SIJP12.mdb sijp12\

copy %PATHSICOSS%\SI220000.mdb sijp12\

echo Ya puede cerrar SIAP.
SET /P MONTH=Que mes desea calcular? (1-12):

%PATHEMPRESA%\ExportSICOSS.exe %PATHEMPRESA%\Recibos.dbc %MONTH% %PATHEXPORT%\SICOSS-%MONTH%.txt %PATHEMPRESA%\Recibo.xls

IF EXIST %PATHEXPORT%\SICOSS-%MONTH%.txt (
    explorer %PATHEXPORT%
)