@echo off

FOR /L %%i IN (1,1,6) DO (
	ExportSICOSS_t.exe .\Recibos.dbc %%i .\SICOSS-%%i.txt)