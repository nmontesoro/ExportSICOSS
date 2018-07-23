*TODO: Sueldo en 0?
*PREGUNTAR: Cifras en 0,01 en SICOSS; 0,00 aca
*PREGUNTAR: Ver detracciones de ORTUETA, ARANDA, TALAVERA, LESCANO (0 en SICOSS, 1200 aca)
*PREGUNTAR: (Febrero) Cepeda y Baigorria NQV (Sueldo en $0.00)
* TODO: Agrupar recibos

*#define testing

#define _SUELDO suebas + accid + susp + falta + enfer
#define _ADICIONALES adibas + antigu + pres
#define _SAC sac
#define _VACACIONES vacpag
#define _CONCEPTOS_NO_REMUNERATIVOS mandin + inddes + indpre + indvac

#define CODIGO_OOSS_COMERCIO "126205"

* MNI: Minimo no Imponible para detracciones
#define MNI 2664.52

* MAX_DETRACCION: Si bien la detraccion máxima es de 3600 en este momento,
* ese importe es solo para casos especiales. Ver más adelante.
#define MAX_DETRACCION 2400

#define CRLF CHR(13) + CHR(10)

LPARAMETERS sDB, sCurrentMonth, sOutFilename, sPathPlanilla
LOCAL xSQLConn, sPeriod, sQuery, sPathPlanilla, sPathSICOSSDB, sSQLStr, nRowCount, nDetraccion, nRem10

SET SAFETY OFF
SET TEXTMERGE ON

#ifdef testing
	CLEAR ALL
	sDB = ".\Recibos.dbc"
*	sCurrentMonth = MONTH(DATE()) - 1
	sCurrentMonth = "6"
	sOutFilename = ".\SICOSS.txt"
	sPathPlanilla = "e:\_Temp\RecibosMC\Recibo.xls"
#endif

OPEN DATABASE (sDB) SHARED NOUPDATE

USE recibo AGAIN IN 0

sPathSICOSSDB = ".\sijp12\sijp12.mdb"
TEXT TO sSQLStr NOSHOW
DRIVER=Microsoft Access Driver (*.mdb);DBQ=<<sPathSICOSSDB>>;PWD=naDdePraKciN
ENDTEXT

? "Accediendo a SICOSS..."

xSQLConn = SQLSTRINGCONNECT(sSQLStr)
sPeriod = "'" + ALLTRIM(STR(YEAR(DATE()))) + PADL(sCurrentMonth, 2, '0') + "'"
sQuery = "SELECT * FROM 22CUILes WHERE [Período]=" + sPeriod

IF xSQLConn >= 1
	IF ! SQLEXEC(xSQLConn, sQuery, "C_SICOSS") == 1
		MESSAGEBOX("No se pudo acceder a la DB de SICOSS. Saliendo...")
		CloseOnError("No pude acceder a SICOSS.")
	ENDIF
ENDIF

* STRTRAN Para compatibilizar con SICOSS
SELECT (STRTRAN(cuil, "-", "")) AS cuil, empl AS nombre, ;
	(_SUELDO) AS sueldo, ;
	(_ADICIONALES) AS adicionales, ;
	(_SAC) AS sac, ;
	(_VACACIONES) AS vac, ;
	(_CONCEPTOS_NO_REMUNERATIVOS) AS noremunerativos, ;
	(_SUELDO + _ADICIONALES + _SAC + _VACACIONES + _CONCEPTOS_NO_REMUNERATIVOS) AS remtot, ;
	(_SUELDO + _ADICIONALES + _SAC + _VACACIONES) AS remimpap, ;
	(0) AS remimpcont, ;
	(0) AS asigfam, ;
	(0) AS aportesijp, ;
	(0) AS aporteinssjp, ;
	(0) AS aporteadss, ;
	(_SUELDO + _ADICIONALES + _SAC + _VACACIONES) AS contos, ;
	(obrsoc + anssal) AS oossanssal, ;
	(2.5) AS jornada ;
	FROM recibo ;
	WHERE ALLTRIM(STR(MONTH(feclia)))==sCurrentMonth AND YEAR(feclia)==YEAR(DATE()) ;
	INTO CURSOR C_Rec READWRITE ;
	GROUP BY cuil ;
	ORDER BY cuil ASC

nRowCount = _TALLY

UPDATE C_Rec SET sueldo = 0.01 WHERE sueldo == 0 && Sueldo no puede ser 0 según SICOSS

InsertJornal(sPathPlanilla)

** Contador de puteadas a los devs de AFIP por los nombres de sus campos: 124
* Prefiero el nombre de SICOSS; no tiene acentos
SELECT C_Rec.*, C_SICOSS.Apellido_y_nombre AS empl, ;
	C_SICOSS.Cónyuge AS conyuge, C_SICOSS.Cantidad_de_Hijos AS hijos, C_SICOSS.Codigo_de_situación AS sit, C_SICOSS.Codigo_de_Condición AS cond, ;
	C_SICOSS.Código_de_Actividad AS actividad, C_SICOSS.Código_de_Zona AS zona, C_SICOSS.Porcentaje_de_Aporte_adicional_ss AS apoadi, ;
	C_SICOSS.Código_de_Modalidad_de_Contratacion AS codcon, C_SICOSS.Código_de_Obra_Social AS ooss, C_SICOSS.Cantidad_de_adherentes AS adherentes, ;
	C_SICOSS.Codigo_de_siniestrado AS codsin, C_SICOSS.Marca_de_corresponde_reduccion AS reduc, ;
	C_SICOSS.Situacion1 AS sit1, C_SICOSS.Situacion2 AS sit2, C_SICOSS.Situacion3 AS sit3, ;
	C_SICOSS.Dia1, C_SICOSS.Dia2, C_SICOSS.Dia3, C_SICOSS.DiasTrabajados AS diastr, C_SICOSS.MarcaSeguroVida AS segvid, ;
	C_SICOSS.Marcaconvencionado AS encct ;
	FROM C_Rec ;
	INNER JOIN C_SICOSS ;
	ON C_Rec.cuil == C_SICOSS.cuil ;
	INTO CURSOR C_Def

IF ! _TALLY == nRowCount
	MESSAGEBOX("Hay diferencias en las CUIL entre el Libro de Sueldos y SICOSS. Mostrando las CUIL conflictivas (presentes en el Libro de Sueldos)...")
	SELECT C_Rec.cuil, C_Rec.nombre ;
		FROM C_Rec ;
		LEFT JOIN C_SICOSS ON C_Rec.cuil == C_SICOSS.cuil ;
		WHERE C_SICOSS.cuil IS NULL
	CloseOnError("Diferencias en CUIL")
ENDIF

* 2.5 es el valor arbitrario que asigné más arriba.
* No tiene que quedar ningun row así después del llamado a InsertJornal.
SELECT cuil, empl FROM C_Def WHERE jornada == 2.5 INTO CURSOR C_Temp

IF _TALLY > 0
	MESSAGEBOX("Las siguientes CUIL no figuran en la planilla de jornadas ('" + sPathPlanilla + "'). No se puede continuar.")
	SELECT C_Temp
	BROWSE
	CloseOnError("CUIL no figuran en planilla")
ENDIF

? "Datos tomados. Creando *.txt..."
STRTOFILE("", sOutFilename, .F.)

SELECT C_Def
SCAN
	STRTOFILE(ALLTRIM(cuil), sOutFilename, .T.)
	STRTOFILE(FormatName(empl), sOutFilename, .T.)
	STRTOFILE(GetPersonalString(conyuge, hijos, sit, cond, actividad, zona), sOutFilename, .T.)
	STRTOFILE(GetOOSSString(apoadi, codcon, ooss, adherentes), sOutFilename, .T.)

	STRTOFILE(FormatMoney(remtot, 12), sOutFilename, .T.)
	STRTOFILE(FormatMoney(remimpap, 12), sOutFilename, .T.)
	STRTOFILE(FormatMoney(remimpcont, 9), sOutFilename, .T.)
	STRTOFILE(FormatMoney(asigfam, 9), sOutFilename, .T.)
	STRTOFILE(FormatMoney(aportesijp, 9), sOutFilename, .T.)
	STRTOFILE(FormatMoney(aporteinssjp, 9), sOutFilename, .T.)
	STRTOFILE(FormatMoney(aporteadss, 9), sOutFilename, .T.)

	STRTOFILE("Buenos Aires - Resto de la Provincia              ", sOutFilename, .T.)

	STRTOFILE(FormatMoney(contos, 12), sOutFilename, .T.) && Remuneracion Imponible 2
	STRTOFILE(FormatMoney(contos, 12), sOutFilename, .T.) && Remuneracion Imponible 3
	STRTOFILE(FormatMoney(contos / jornada, 12), sOutFilename, .T.) && Remuneracion Imponible 4
	STRTOFILE(PadString(codsin, 2, '0'), sOutFilename, .T.) && Codigo de siniestrado
	STRTOFILE("F", sOutFilename, .T.) && *TODO: Corresponde reduccion
	STRTOFILE("     0,001", sOutFilename, .T.) && *TODO: Recomposicion LRT
	STRTOFILE(FormatMoney(IIF(ooss == CODIGO_OOSS_COMERCIO, 100, 0), 9), sOutFilename, .T.) && Aporte adicional OOSS

	STRTOFILE(GetSitAndDayString(sit1, sit2, sit3, dia1, dia2, dia3), sOutFilename, .T.)
	STRTOFILE(FormatMoney(sueldo, 12), sOutFilename, .T.) && Sueldo + adicionales
	STRTOFILE(FormatMoney(sac, 12), sOutFilename, .T.) && SAC
	STRTOFILE("        0,00        0,00", sOutFilename, .T.) && *TODO: Hs. Extra, zona desfavorable
	STRTOFILE(FormatMoney(vac, 12), sOutFilename, .T.) && Vacaciones
	STRTOFILE(PadString(diastr, 9, '0'), sOutFilename, .T.) && Dias trabajados
	STRTOFILE(FormatMoney(contos, 12), sOutFilename, .T.) && *TODO: Remuneracion Imponible 5
	STRTOFILE(IIF(encct, "T", "F"), sOutFilename, .T.) && Trabajador convencionado (en CCT)

	STRTOFILE(FormatMoney(0, 12), sOutFilename, .T.) && Rem. Impo. 6
	STRTOFILE("0", sOutFilename, .T.) && Tipo de operacion
	STRTOFILE(FormatMoney(adicionales, 12), sOutFilename, .T.) && Adicionales
	STRTOFILE(FormatMoney(0, 12), sOutFilename, .T.) && Premios
	STRTOFILE(FormatMoney(contos / jornada, 12), sOutFilename, .T.) && *TODO: Dec 788/05, Rem. Impo. 8
	STRTOFILE(FormatMoney(0, 12), sOutFilename, .T.) && *TODO: Rem. Impo. 7

	STRTOFILE("000", sOutFilename, .T.) && *TODO: Cantidad Hs. Extra

	STRTOFILE(FormatMoney(noremunerativos, 12), sOutFilename, .T.) && No remunerativos

	STRTOFILE("        0,00     0,00", sOutFilename, .T.) && *TODO: Maternidad, rectificacion de remuneracion

	STRTOFILE(FormatMoney(remtot, 12), sOutFilename, .T.) && Remuneracion Imponible 9

	STRTOFILE("     0,00000", sOutFilename, .T.) && *TODO: Contribucion tarea diferencial

	STRTOFILE(IIF(segvid, 'T', 'F'), sOutFilename, .T.) && Con cobertura de seguro colectivo de vida obligatorio

	nDetraccion = jornada * MAX_DETRACCION

	nRem10 = contos - nDetraccion

	IF nRem10 < MNI
		nDetraccion = 0
	ENDIF

	STRTOFILE(FormatMoney(nDetraccion, 12), sOutFilename, .T.) && Detraccion

	STRTOFILE(CRLF, sOutFilename, .T.)
ENDSCAN

MESSAGEBOX("Archivo creado con exito", 64)

CLOSE DATABASES

FUNCTION FormatName(sName)
*	RETURN PADR(UPPER(ALLTRIM(sName)), 30, " ")
	RETURN PADR(ALLTRIM(sName), 30, " ")
ENDFUNC

FUNCTION FormatMoney(fValue, nLength)
	* nLength: Longitud total (con decimales y padding)
	RETURN STRTRAN(STR(fValue, nLength, 2), ".", ",")
ENDFUNC

FUNCTION GetPersonalString(conyuge, hijos, sit, cond, act, zona)
	LOCAL sPersonalString

	sPersonalString = IIF(conyuge, "T", "F")
	sPersonalString = sPersonalString + PADL(hijos, 2, '0')
	sPersonalString = sPersonalString + PADL(sit, 2, '0')
	sPersonalString = sPersonalString + PADL(cond, 2, '0')
	sPersonalString = sPersonalString + PADL(act, 3, '0')
	sPersonalString = sPersonalString + PADL(zona, 2, '0')

	RETURN sPersonalString
ENDFUNC

FUNCTION GetOOSSString(apoadi, codcon, ooss, adh)
	LOCAL sOOSSString

	sOOSSString = FormatMoney(apoadi, 5)
	sOOSSString = sOOSSString + PADL(ALLTRIM(STR(codcon)), 3, '0')
	sOOSSString = sOOSSString + PADL(ALLTRIM(ooss), 6, '0')
	sOOSSString = sOOSSString + PADL(ALLTRIM(STR(adh)), 2, '0')

	RETURN sOOSSString
ENDFUNC

FUNCTION PadString(sStr, nPadLength, cChar)
	RETURN PADL(ALLTRIM(STR(sStr)), nPadLength, cChar)
ENDFUNC

FUNCTION GetSitAndDayString(sit1, sit2, sit3, dia1, dia2, dia3)
	LOCAL aSitDay, sSitAndDayString

	DIMENSION aSitDay(3,2)
	aSitDay(1,1) = IIF(sit1 == -1, 1, sit1)
	aSitDay(1,2) = dia1
	aSitDay(2,1) = IIF(sit2 == -1, 1, sit2)
	aSitDay(2,2) = dia2
	aSitDay(3,1) = IIF(sit3 == -1, 1, sit3)
	aSitDay(3,2) = dia3

	sSitAndDayString = '1' && *TODO: Ver por que empieza en 1

	FOR i = 1 TO 3
		sSitAndDayString = sSitAndDayString + PadString(aSitDay(i,1), 2, '0') + PadString(aSitDay(i,2), 2, '0')
	NEXT

	RETURN sSitAndDayString
ENDFUNC

FUNCTION InsertJornal(sPathPlanilla)
	LOCAL oXL, oRange, nCol, sCUIL, nJornal

*	oXL = GETOBJECT(sPathPlanilla)
	oXL = CREATEOBJECT("Excel.Application")
	oXL.Application.Workbooks.Open(sPathPlanilla)

	IF VARTYPE(oXL) == "O"
		oXL.Visible = .F.
		oXL.DisplayAlerts = .F.

		oRange = oXL.Worksheets("Empleados").Cells(1,1).Currentregion

		nCol = 4

		SELECT C_Rec

		*sCUIL = STRTRAN(oRange.Cells(6, nCol).Value, "-", "")
		sCUIL = "CUIT EJEMPLO"
		DO WHILE ! sCUIL == ""
			IF nCol == 1000 && Proteccion de loop infinito
				EXIT
			ENDIF

			sCUIL = STRTRAN(oRange.Cells(6, nCol).Value, "-", "")
			nJornal = oRange.Cells(27, nCol).Value
			UPDATE C_Rec SET jornada = nJornal WHERE cuil == sCUIL
			nCol = nCol + 1
		ENDDO

		oXL.Workbooks.Close()

		RELEASE oXL
	ENDIF
ENDFUNC

FUNCTION CloseOnError(sMsg)
#ifndef testing
	STRTOFILE(DTOC(DATE()) + "   " + TIME() + " - " + sMsg + CRLF, ".\ErrorLog.txt", .T.)
	CLOSE DATABASES
	QUIT
#else
	RETURN 0
#endif
ENDFUNC
