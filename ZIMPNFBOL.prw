#Include "Protheus.ch"
#Include "TbiConn.ch"
#Include "Colors.ch"
#Include "RptDef.ch"
#Include "FWPrintSetup.ch"
#Include "TopConn.ch"

/*/{Protheus.doc} ZIMPNFBOL
Pede a filial e o n�mero da Nota Fiscal de Sa�da e gera, em C:\Dev, o PDF da
DANFE com o boleto anexado (quando aplic�vel), reaproveitando o motor nativo
de impress�o de DANFE (NFE_2025/20251215/danfeii.prw -> U_DANFEProc), que por
sua vez j� aciona a impress�o do boleto (RFINR03/RFINR04/BRADESCO) quando
MV_PAR21 = 2 e a empresa � a CHUA.

Restri��o: a filial informada precisa ser aquela em que o usu�rio est�
logado (cFilAnt), pois o motor nativo de DANFE sempre filtra pela filial da
sess�o atual (xFilial()), n�o havendo como gerar de outra filial sem trocar
de ambiente.

@Gabriel Esteves
@since 18/08/2026
@version 1.0
@type function
/*/
User Function ZIMPNFBOL()
	Local cFilialDig := cFilAnt
	Local cNumNota    := Space(TamSX3("F2_DOC")[1])
	Local oDlg
	Local oGetFilial, oGetNumero
	Local lConfirma  := .F.

	DEFINE MSDIALOG oDlg TITLE "Gerar PDF - Nota Fiscal + Boleto" FROM 000, 000 TO 130, 340 PIXEL

		@ 012, 010 SAY "Filial:"           SIZE 060, 010 OF oDlg PIXEL
		@ 010, 080 GET  oGetFilial VAR cFilialDig SIZE 060, 012 OF oDlg PIXEL

		@ 032, 010 SAY "N�mero da Nota:"   SIZE 060, 010 OF oDlg PIXEL
		@ 030, 080 GET  oGetNumero VAR cNumNota PICTURE "@!" SIZE 080, 012 OF oDlg PIXEL

		@ 060, 070 BUTTON "OK"       SIZE 050, 015 ACTION (lConfirma := .T., oDlg:End()) OF oDlg PIXEL
		@ 060, 130 BUTTON "Cancelar" SIZE 050, 015 ACTION (lConfirma := .F., oDlg:End()) OF oDlg PIXEL

	ACTIVATE MSDIALOG oDlg CENTERED

	If ! lConfirma
		Return Nil
	EndIf

	cFilialDig := AllTrim(cFilialDig)
	cNumNota   := AllTrim(cNumNota)

	If Empty(cNumNota)
		MsgStop("Informe o n�mero da nota.", "Aten��o")
		Return Nil
	EndIf

	If cFilialDig <> AllTrim(cFilAnt)
		MsgStop("Voc� est� logado na filial " + AllTrim(cFilAnt) + "." + CRLF + ;
			"Para gerar o PDF da filial " + cFilialDig + ", troque de filial no Protheus e execute a rotina novamente.", ;
			"Filial inv�lida")
		Return Nil
	EndIf

	fGerarPdf(cNumNota)

Return Nil

/*-------------------------------------------------------------------------------*
 | Func:  fGerarPdf                                                              |
 | Desc:  Resolve a s�rie da nota na SF3 (tabela de controle usada pelo motor    |
 |        de DANFE), monta o objeto de impress�o em PDF e chama U_DANFEProc,     |
 |        que desenha a nota e, quando aplic�vel, anexa o boleto no mesmo PDF.   |
 *-------------------------------------------------------------------------------*/
Static Function fGerarPdf(cNumNota)
	Local aArea      := GetArea()
	Local cAliasQry  := GetNextAlias()
	Local aSeries    := {}
	Local aSeriesRaw := {}
	Local cNumNotaRaw:= ""
	Local cSerie     := ""
	Local cSerieRaw  := ""
	Local nOpc       := 0
	Local nIdxSel    := 0
	Local cPasta     := "C:\Dev\"
	Local cNomeArq   := ""
	Local oDanfe
	Local lExistNfe  := .F.
	Local cNfceMens  := ""
	Local cIdEnt     := ""
	Local cMsgErro   := ""

	Private MV_PAR01, MV_PAR02, MV_PAR03, MV_PAR04, MV_PAR05, MV_PAR06, MV_PAR07, MV_PAR08, MV_PAR21
	Private cNumBor  := ""

	DbSelectArea("SF3")
	DbSelectArea("SF2")
	DbSelectArea("SF1")
	DbSelectArea("SFT")
	DbSelectArea("AR1")

	BeginSQL Alias cAliasQry
		COLUMN F3_DTCANC AS DATE

		SELECT SF3.F3_SERIE, SF3.F3_NFISCAL, SF3.F3_DTCANC
		FROM %table:SF3% SF3
		WHERE SF3.%notDel%
		AND SF3.F3_FILIAL = %xfilial:SF3%
		AND SF3.F3_NFISCAL = %exp:cNumNota%
		AND SUBSTRING(SF3.F3_CFO, 1, 1) >= '5'
		AND SF3.F3_ESPECIE IN ('SPED', 'NFCE')
	EndSQL

	DbSelectArea(cAliasQry)
	While ! (cAliasQry)->(Eof())
		If Empty((cAliasQry)->F3_DTCANC) .And. AScan(aSeries, AllTrim((cAliasQry)->F3_SERIE)) == 0
			AAdd(aSeries, AllTrim((cAliasQry)->F3_SERIE))
			// Mantidos sem AllTrim - usados apenas no diagn�stico SPED (fDiagSped),
			// que precisa reproduzir a mesma chave (S�rie+N�mero) usada internamente
			// por U_DANFEProc, no formato exato gravado na SF3 (com padding).
			AAdd(aSeriesRaw, (cAliasQry)->F3_SERIE)
			cNumNotaRaw := (cAliasQry)->F3_NFISCAL
		EndIf
		(cAliasQry)->(DbSkip())
	EndDo
	(cAliasQry)->(DbCloseArea())

	If Len(aSeries) == 0
		MsgStop("Nenhuma nota fiscal de sa�da autorizada encontrada com o n�mero " + cNumNota + ;
			" na filial " + AllTrim(cFilAnt) + ".", "Nota n�o encontrada")
		RestArea(aArea)
		Return Nil
	ElseIf Len(aSeries) == 1
		nIdxSel := 1
		cSerie := aSeries[nIdxSel]
	Else
		// Mais de uma s�rie encontrada para o mesmo n�mero: o usu�rio escolhe qual gerar
		nOpc := Achoice(008, 005, 018, 060, aSeries)
		If nOpc == 0
			RestArea(aArea)
			Return Nil
		EndIf
		nIdxSel := nOpc
		cSerie := aSeries[nIdxSel]
	EndIf

	cSerieRaw := aSeriesRaw[nIdxSel]

	If ! ExistDir(cPasta)
		MakeDir(cPasta)
	EndIf

	cNomeArq := "NF_" + cNumNota + "_" + cSerie

	oDanfe := FWMSPrinter():New(cNomeArq, IMP_PDF, .F., , .T.)
	oDanfe:SetResolution(78)
	oDanfe:SetPortrait()
	oDanfe:SetPaperSize(DMPAPER_A4)
	oDanfe:SetMargin(60, 60, 60, 60)
	oDanfe:lServer   := .T.
	oDanfe:setCopies(1)
	oDanfe:nDevice   := IMP_PDF
	oDanfe:cPathPDF  := cPasta

	// Apenas leitura do border� atual - N�O avan�a o contador (MV_EANUBOR),
	// pois esta impress�o � s� uma via avulsa da nota + boleto e n�o faz
	// parte do fluxo oficial de gera��o de border�.
	cNumBor := GetMV("MV_EANUBOR")

	// Mesma chamada que U_PrtNfeSef faz antes de montar os MV_PAR* - garante
	// que qualquer estado adicional exigido pelo motor de DANFE (al�m dos
	// MV_PAR* que sobrescrevemos abaixo) fique inicializado como no fluxo nativo.
	Pergunte("NFSIGW", .F.)

	MV_PAR01 := cNumNota   // Nota inicial
	MV_PAR02 := cNumNota   // Nota final
	// S�rie: PadR para o tamanho cheio do campo F3_SERIE. O motor de DANFE compara
	// internamente "SF3.F3_SERIE = ?" via bind (VARCHAR2). No Oracle, bind VARCHAR2
	// contra coluna CHAR usa compara��o SEM blank-padding, ent�o uma s�rie truncada
	// (ex.: "1") nunca bate com o valor gravado ("1  "), e a nota n�o � encontrada.
	MV_PAR03 := PadR(cSerie, TamSX3("F3_SERIE")[1])
	MV_PAR04 := 2          // Opera��o: NF de Sa�da
	MV_PAR05 := 1          // Frente e verso
	MV_PAR06 := 2          // DANFE simplificado: N�o
	MV_PAR07 := CToD("")   // Data de emiss�o inicial (sem filtro)
	MV_PAR08 := CToD("")   // Data de emiss�o final (sem filtro)
	MV_PAR21 := 2          // Aciona a impress�o do boleto junto com a DANFE

	// ID da entidade SPED da empresa/filial atualmente logada. RetIdEnti() �
	// a fun��o padr�o do m�dulo SPED-NFe para obter esse ID (a mesma usada por
	// U_PrtNfeSef quando chamado a partir da tela padr�o de impress�o).
	cIdEnt := RetIdEnti()

	U_DANFEProc(@oDanfe, .F., cIdEnt, cNumNota, cNumNota, @lExistNfe, .F., 0, @cNfceMens)

	If lExistNfe
		oDanfe:Preview() // Com nDevice = IMP_PDF, grava o arquivo em cPathPDF
		MsgInfo("PDF gerado com sucesso em:" + CRLF + cPasta + cNomeArq + ".pdf", "Sucesso")
	Else
		cMsgErro := "N�o foi poss�vel gerar o PDF. Verifique se a nota " + cNumNota + "/" + cSerie + ;
			" est� autorizada e possui XML dispon�vel no SPED."

		If GetNewPar("MV_IMPDIR", .F.)
			cMsgErro += CRLF + CRLF + ;
				"Diagn�stico: o par�metro MV_IMPDIR est� ativo (.T.) neste ambiente. " + ;
				"Com ele ativo, a rotina nativa de DANFE (DANFEProc) pula por completo " + ;
				"o trecho que localiza a nota e, por isso, nada � encontrado, mesmo com a " + ;
				"nota autorizada. Provavelmente essa � a causa; vale conferir " + ;
				"esse par�metro com a equipe de configura��o."
		EndIf

		If Empty(cIdEnt)
			cMsgErro += CRLF + CRLF + ;
				"Diagn�stico: RetIdEnti() retornou vazio - a empresa/filial atual pode " + ;
				"n�o ter uma entidade SPED cadastrada/ativa."
		EndIf

		cMsgErro += CRLF + CRLF + "--- Diagn�stico SPED (tempor�rio) ---" + CRLF + ;
			fDiagSped(cIdEnt, cSerieRaw, cNumNotaRaw)

		MsgStop(cMsgErro, "Falha na gera��o")
	EndIf

	FreeObj(oDanfe)
	oDanfe := Nil

	RestArea(aArea)
Return Nil

/*-------------------------------------------------------------------------------*
 | Func:  fDiagSped                                                              |
 | Desc:  DIAGN�STICO TEMPOR�RIO - reproduz isoladamente a mesma consulta que    |
 |        U_DANFEProc faz ao web service do SPED (NFeSBRA/RETORNANOTASNX) para a |
 |        nota informada e retorna o resultado bruto (achou ou n�o achou         |
 |        registro, protocolo, tamanho do XML). Serve apenas para confirmar se   |
 |        o cIdEnt (RetIdEnti()) usado por esta rotina � o mesmo que o fluxo     |
 |        convencional usa. Remover depois que a causa raiz for confirmada.      |
 *-------------------------------------------------------------------------------*/
Static Function fDiagSped(cIdEnt, cSerieRaw, cNumNotaRaw)
	Local cURL       := PadR(GetNewPar("MV_SPEDURL", "http://localhost:8080/sped"), 250)
	Local cChave     := cSerieRaw + cNumNotaRaw
	Local cDiag      := ""
	Local cRetorno   := ""
	Local cDHRecbto  := ""
	Local cRetDPEC   := ""
	Local cCodStat   := ""
	Local cCodRetNFE := ""
	Local cMsgNFE    := ""
	Local cAviso     := ""
	Local cErro      := ""
	Local nPos       := 0
	Local aWsErro    := {}
	Local oWS
	Local oXmlProt
	Local oXmlNfe
	Local oXmlDpec

	cDiag += "cID_ENT usado: [" + AllTrim(cIdEnt) + "]" + CRLF
	cDiag += "Chave enviada (S�rie+NFiscal): [" + cChave + "]" + CRLF
	cDiag += "URL: " + AllTrim(cURL) + "/NFeSBRA.apw" + CRLF

	Begin Sequence

		oWS := WSNFeSBRA():New()
		oWS:cUSERTOKEN        := "TOTVS"
		oWS:cID_ENT           := cIdEnt
		oWS:nDIASPARAEXCLUSAO := 0
		oWS:_URL              := AllTrim(cURL) + "/NFeSBRA.apw"
		oWS:oWSNFEID          := NFESBRA_NFES2():New()
		oWS:oWSNFEID:oWSNotas := NFESBRA_ARRAYOFNFESID2():New()
		AAdd(oWS:oWSNFEID:oWSNotas:oWSNFESID2, NFESBRA_NFESID2():New())
		ATail(oWS:oWSNFEID:oWSNotas:oWSNFESID2):cID := cChave

		If oWS:RETORNANOTASNX() .And. Len(oWS:oWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5) > 0

			cRetorno  := oWS:oWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5[1]:oWSNFE:CXML
			cDHRecbto := oWS:oWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5[1]:oWSNFE:CXMLPROT
			If ValType(oWS:OWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5[1]:OWSDPEC) == "O"
				cRetDPEC := oWS:oWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5[1]:oWSDPEC:CXML
			EndIf

			cDiag += "Protocolo: [" + oWS:oWSRETORNANOTASNXRESULT:OWSNOTAS:OWSNFES5[1]:oWSNFE:CPROTOCOLO + "]" + CRLF
			cDiag += "Tamanho XML NFe: " + AllTrim(Str(Len(cRetorno))) + " caracteres" + CRLF
			cDiag += "Tamanho XML DPEC: " + AllTrim(Str(Len(cRetDPEC))) + " caracteres" + CRLF

			// cStat do protocolo de autoriza��o - mesma extra��o que executeRetorna faz.
			// ValAtrib() n�o est� dispon�vel fora do danfeii.prw (fun��o privada do m�dulo
			// SPED), ent�o o acesso ao XML � feito com Begin Sequence para n�o travar caso
			// algum n� n�o exista.
			oXmlProt := XmlParser(cDHRecbto, "", "", "")
			cCodStat := ""
			Begin Sequence
				cCodStat := oXmlProt:_ProtNFE:_INFPROT:_CSTAT:TEXT
			Recover
				cCodStat := ""
			End Sequence
			cDiag += "cStat do protocolo: [" + cCodStat + "]" + IIf(cCodStat == "100", " (100 = Autorizado)", " (ESPERADO: 100)") + CRLF

			// Segunda checagem que DANFEProc faz antes de liberar o desenho: MONITORFAIXA
			oWS:cIdInicial := cChave
			oWS:cIdFinal   := cChave
			If oWS:MONITORFAIXA()
				If !Empty(cCodStat)
					aWsErro := oWS:OWSMONITORFAIXARESULT:OWSMONITORNFE[1]:OWSERRO:OWSLOTENFE
					cDiag += "MONITORFAIXA - itens na fila de retorno: " + AllTrim(Str(Len(aWsErro))) + CRLF
					For nPos := 1 To Len(aWsErro)
						If Alltrim(aWsErro[nPos]:CCODRETNFE) == Alltrim(cCodStat)
							Exit
						EndIf
					Next
					If nPos > 0 .And. nPos <= Len(aWsErro)
						cCodRetNFE := aWsErro[nPos]:CCODRETNFE
						cMsgNFE    := aWsErro[nPos]:CMSGRETNFE
						cDiag += "-> Item que bate com o cStat: CCODRETNFE=[" + AllTrim(cCodRetNFE) + "] Msg=[" + AllTrim(cMsgNFE) + "]" + CRLF
					ElseIf Len(aWsErro) > 0
						cCodRetNFE := aWsErro[Len(aWsErro)]:CCODRETNFE
						cMsgNFE    := aWsErro[Len(aWsErro)]:CMSGRETNFE
						cDiag += "-> NENHUM item da fila bate com o cStat desta nota; a rotina nativa usaria " + ;
							"o �LTIMO item da fila (pode ser de OUTRA nota/lote): CCODRETNFE=[" + AllTrim(cCodRetNFE) + ;
							"] Msg=[" + AllTrim(cMsgNFE) + "]" + CRLF
					Else
						cDiag += "-> Fila de retorno (OWSLOTENFE) veio vazia." + CRLF
					EndIf
				Else
					cDiag += "cStat vazio - a rotina nativa pularia a compara��o do MONITORFAIXA tamb�m." + CRLF
				EndIf
			Else
				cDiag += "Falha ao chamar MONITORFAIXA: " + IIf(Empty(GetWscError(3)), GetWscError(1), GetWscError(3)) + CRLF
			EndIf

			// Parse do XML da NFe (mesma chamada que alimenta o desenho do DANFE)
			oXmlNfe := XmlParser(cRetorno, "_", @cAviso, @cErro)
			cDiag += "Parse do XML da NFe -> Aviso=[" + AllTrim(cAviso) + "] Erro=[" + AllTrim(cErro) + "]" + CRLF

			// Parse do XML do DPEC (normalmente vazio para nota sem conting�ncia). Na rotina
			// nativa, o Aviso/Erro deste SEGUNDO parse SOBRESCREVE o do parse acima antes
			// de decidir se desenha o DANFE (If Empty(cAviso) .And. Empty(cErro)).
			oXmlDpec := XmlParser(cRetDPEC, "_", @cAviso, @cErro)
			cDiag += "Parse do XML do DPEC -> Aviso=[" + AllTrim(cAviso) + "] Erro=[" + AllTrim(cErro) + "]" + CRLF
			cDiag += "=> Esse �ltimo Aviso/Erro (do DPEC) � o que decide se o DANFE � desenhado." + CRLF

		Else
			cDiag += "SPED n�o retornou registro para essa chave/entidade (RETORNANOTASNX)." + CRLF
		EndIf

		FreeObj(oWS)
		oWS := Nil

	Recover
		cDiag += "O diagn�stico n�o p�de ser executado por completo (erro durante a consulta)." + CRLF

	End Sequence

Return cDiag
