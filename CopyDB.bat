@echo off

SET SIAP=e:\SIAP_MejC\siap.exe
SET PATHSICOSS=e:\SIAP_MejC\sijp12

echo Abra el SICOSS y luego siga las instrucciones. Presione enter para continuar (se abrira SIAP)...
pause > nul

start %SIAP%

echo Si ya abrio SICOSS, presione enter...
pause > nul

IF NOT EXIST sijp12\ mkdir sijp12

copy %PATHSICOSS%\SIJP12.mdb sijp12\

copy %PATHSICOSS%\SI220000.mdb sijp12\

echo Ya puede cerrar SIAP.
SET /P sMonth=Que mes desea calcular? (1-12):

ExportSICOSS.exe .\Recibos.dbc %sMonth% .\SICOSS-%sMonth%.txt e:\_Temp\RecibosMC\ExportSICOSS\ExportSICOSS\Recibo.xls