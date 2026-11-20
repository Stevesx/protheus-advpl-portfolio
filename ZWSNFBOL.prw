#Include "Protheus.ch"
#Include "TbiConn.ch"
#Include "TopConn.ch"
#Include "FileIO.ch"
#Include "RptDef.ch"
#Include "FWPrintSetup.ch"
#Include "RestFul.ch"

/*/{Protheus.doc} ZWSNFBOL
Endpoint REST que recebe filial e número da Nota Fiscal de Saída e devolve, em
JSON, o PDF da DANFE com o boleto anexado (quando aplicável), codificado em
Base64 - reaproveitando o mesmo motor nativo de impressão de DANFE
(U_DANFEProc) usado pelo ZIMPNFBOL.prw, que já aciona a impressão do boleto
quando MV_PAR21 = 2.

A série é sempre "1" (fixa, conforme definido para este endpoint).

IMPORTANTE: quem seleciona a empresa/filial do ambiente é o cabeçalho HTTP
"tenantId: <empresa>,<filial>" da requisição (prepareIn=ALL no appserver.ini).
O parâmetro 'filial' abaixo é apenas conferido contra o ambiente que o
tenantId efetivamente abriu (proteção contra tenantId/filial divergentes) e
não troca de filial dentro do método.

GET /rest/ZWSNFBOL/v1/gerar/?filial=X&nota=Y
Cabeçalho obrigatório: tenantId: <empresa>,X

Retorno (sucesso, HTTP 200):
{
    "sucesso": true,
    "filial": "X",
    "nota": "Y",
    "serie": "1",
    "nomeArquivo": "NF_Y_1_X.pdf",
    "arquivoBase64": "<conteúdo do PDF em base64>"
}

Retorno (falha): SetRestFault com 400 (parâmetro inválido), 404 (nota não
localizada) ou 500 (falha na geração/leitura do PDF).

@author Equipe de Desenvolvimento
@since 18/08/2026
@version 2.0
/*/
WSRESTFUL ZWSNFBOL DESCRIPTION "Emissão de PDF (Nota Fiscal + Boleto) e consulta de títulos" FORMAT APPLICATION_JSON

	WSDATA filial as String
	WSDATA nota   as String
	WSDATA tipo   as String
	WSDATA cnpj   as String

	WSMETHOD GET gerar;
		DESCRIPTION "Gera o PDF da nota (série fixa '1'), do boleto ou dos dois e devolve em Base64";
		WSSYNTAX "/ZWSNFBOL/v1/gerar/?filial={filial}&nota={nota}&tipo={tipo}";
		PATH "/ZWSNFBOL/v1/gerar";
		TTALK "v1"

	WSMETHOD GET titulos;
		DESCRIPTION "Lista títulos em aberto (E1_SALDO > 0.02, E1_TIPO = NF) de um cliente pelo CNPJ/CPF";
		WSSYNTAX "/ZWSNFBOL/v1/titulos/?cnpj={cnpj}";
		PATH "/ZWSNFBOL/v1/titulos";
		TTALK "v1"

END WSRESTFUL

/*-------------------------------------------------------------------------------*
 | Método: gerar                                                                 |
 | Desc:   Valida os parâmetros recebidos e devolve o PDF gerado em Base64.      |
 *-------------------------------------------------------------------------------*/
WSMETHOD GET gerar WSSERVICE ZWSNFBOL

	Local oJRet    := Nil
	Local cFilRest := ""
	Local cNumNota := ""
	Local cTipo    := ""
	Local lRet     := .T.
	Local nStatus  := 500

	::SetContentType("application/json")

	// WSDATA não preenchido chega como Nil em alguns builds - nunca aplicar
	// AllTrim()/Upper() direto sobre a propriedade sem checar o tipo.
	If ValType(::filial) == "C"
		cFilRest := AllTrim(Upper(::filial))
	EndIf

	If ValType(::nota) == "C"
		cNumNota := AllTrim(::nota)
	EndIf

	If ValType(::tipo) == "C"
		cTipo := Lower(AllTrim(::tipo))
	EndIf

	Default cTipo := "notaboleto" // compatibilidade com chamadas antigas sem o parâmetro
	If Empty(cTipo)
		cTipo := "notaboleto"
	EndIf

	If Empty(cFilRest)
		SetRestFault(400, "Parâmetro 'filial' não informado.")
		Return .F.
	EndIf

	If Empty(cNumNota)
		SetRestFault(400, "Parâmetro 'nota' não informado.")
		Return .F.
	EndIf

	If cTipo <> "notaboleto" .And. cTipo <> "boleto"
		SetRestFault(400, "Parâmetro 'tipo' inválido ('" + cTipo + "'). Valores aceitos: 'notaboleto' ou 'boleto'.")
		Return .F.
	EndIf

	oJRet := JsonObject():New()

	If fGerarPdfWS(cFilRest, cNumNota, cTipo, oJRet)
		::SetResponse(oJRet:ToJson())
	Else
		nStatus := IIf(ValType(oJRet['status']) == "N", oJRet['status'], 500)
		SetRestFault(nStatus, oJRet['mensagem'])
		lRet := .F.
	EndIf

	FreeObj(oJRet)
	oJRet := Nil

Return lRet

/*-------------------------------------------------------------------------------*
 | Func:  fGerarPdfWS                                                            |
 | Desc:  Confere se a filial informada corresponde à do ambiente (aberto via   |
 |        tenantId), localiza a nota fiscal (série fixa "1") na SF3, gera o PDF  |
 |        via U_DANFEProc, lê o arquivo gerado, devolve-o em Base64 dentro de    |
 |        oJRet e apaga o arquivo físico do servidor.                           |
 *-------------------------------------------------------------------------------*/
Static Function fGerarPdfWS(cFilRest, cNumNota, cTipo, oJRet)
	Local lOk          := .F.
	Local cErro        := ""
	Local nStatus      := 500
	Local cSerie       := "1"
	Local cAliasQry    := GetNextAlias()
	Local lAchou       := .F.
	Local cPasta       := "\pdftmp\"          // relativo ao RootPath (lServer = .T.)
	Local cNomeResp    := ""
	Local cNomeFis     := ""
	Local cArqCompleto := ""
	Local oDanfe       := Nil
	Local lExistNfe    := .F.
	Local cNfceMens    := ""
	Local cIdEnt       := ""
	Local nHandle      := 0
	Local nFSize       := 0
	Local cConteudo    := ""
	Local bErrOld      := Nil
	Local nTamFil      := 0

	// TODAS as MV_PARxx do grupo precisam existir como PRIVATE ANTES do Pergunte.
	// As que não forem declaradas aqui são criadas dentro do escopo do Pergunte e
	// deixam de existir quando ele retorna - o DANFEProc então falha com
	// "variable does not exist" ao ler MV_PAR09..MV_PAR20.
	Private MV_PAR01, MV_PAR02, MV_PAR03, MV_PAR04, MV_PAR05, MV_PAR06, MV_PAR07
	Private MV_PAR08, MV_PAR09, MV_PAR10, MV_PAR11, MV_PAR12, MV_PAR13, MV_PAR14
	Private MV_PAR15, MV_PAR16, MV_PAR17, MV_PAR18, MV_PAR19, MV_PAR20, MV_PAR21
	Private cNumBor := ""

	// PREPARE ENVIRONMENT e a reatribuição direta de cFilAnt não são mais permitidos
	// dentro de um WSMETHOD (ambos bloqueados pelo framework nesta versão). Com
	// prepareIn=ALL configurado no appserver.ini, quem seleciona a empresa/filial é
	// o cabeçalho HTTP "tenantId: <empresa>,<filial>" enviado na requisição - o broker
	// já instancia o ambiente (inclusive a SM0) na filial correta ANTES de chamar
	// este método. Aqui só validamos que o parâmetro 'filial' recebido corresponde ao
	// ambiente que o tenantId efetivamente abriu, para detectar um tenantId errado
	// enviado pelo cliente em vez de silenciosamente gerar o PDF da filial errada.
	nTamFil  := FWSizeFilial()
	cFilRest := PadR(cFilRest, nTamFil)

	If cFilRest <> cFilAnt
		oJRet['sucesso']  := .F.
		oJRet['status']   := 400
		oJRet['mensagem'] := "A filial informada ('" + AllTrim(cFilRest) + "') não corresponde à filial do ambiente atual ('" + AllTrim(cFilAnt) + "'). " + ;
			"Confirme o cabeçalho 'tenantId' enviado na requisição (formato 'empresa,filial')."
		Return .F.
	EndIf

	// Begin Sequence / Recover SOZINHO não captura erro de execução - só captura
	// Break(). Sem o ErrorBlock abaixo, qualquer erro dentro do DANFEProc derruba
	// a thread REST e o cliente recebe um 500 genérico sem mensagem.
	bErrOld := ErrorBlock({|oErr| cErro := "Erro interno: " + AllTrim(oErr:Description), ;
	                              ConOut("[ZWSNFBOL] " + cErro + " | " + ProcName(1) + " linha " + cValToChar(ProcLine(1))), ;
	                              Break(oErr) })

	Begin Sequence

		If cTipo == "notaboleto"
			// Abre/valida os aliases necessários. A AR1 (contratos) pode não existir em
			// todos os ambientes - DbSelectArea sobre alias inexistente gera erro fatal.
			If ! fChkAlias({"SF3", "SF2", "SF1", "SFT"})
				cErro   := "Tabelas fiscais (SF1/SF2/SF3/SFT) indisponíveis nesta filial."
				nStatus := 500
				Break
			EndIf
			fChkAlias({"AR1"}) // opcional - ignora se não existir no dicionário

			// Filtra só pelo número da nota (não pela série via SQL) para não repetir o
			// problema de bind VARCHAR2 x coluna CHAR no Oracle. A série é conferida em
			// ADVPL sobre o valor cru vindo da SF3.
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

			While ! (cAliasQry)->(Eof())
				If Empty((cAliasQry)->F3_DTCANC) .And. AllTrim((cAliasQry)->F3_SERIE) == cSerie
					lAchou := .T.
					Exit
				EndIf
				(cAliasQry)->(DbSkip())
			EndDo
			(cAliasQry)->(DbCloseArea())

			If ! lAchou
				nStatus := 404
				cErro   := "Nota fiscal " + cNumNota + "/" + cSerie + " não encontrada, cancelada ou não autorizada na filial " + AllTrim(cFilRest) + "."
				Break
			EndIf
		Else
			// tipo == "boleto": o boleto é emitido a partir da SE1 (RFINR03/04/BRADESCO),
			// não depende da SF3/XML do SPED.
			If ! fChkAlias({"SE1"})
				cErro   := "Tabela de títulos (SE1) indisponível nesta filial."
				nStatus := 500
				Break
			EndIf

			If ! fExisteTituloAberto(cNumNota)
				nStatus := 404
				cErro   := "Não foi encontrado título em aberto (E1_SALDO > 0) para a nota " + cNumNota + " na filial " + AllTrim(cFilRest) + "."
				Break
			EndIf
		EndIf

		If ! ExistDir(cPasta)
			MakeDir(cPasta)
		EndIf

		// Nome exposto ao cliente x nome físico. O físico leva ThreadID + timestamp
		// porque duas chamadas simultâneas da MESMA nota gravariam sobre o mesmo
		// arquivo, e uma leria o PDF da outra (ou o arquivo pela metade).
		cNomeResp    := IIf(cTipo == "boleto", "BOL_", "NF_") + cNumNota + "_" + cSerie + "_" + AllTrim(cFilRest)
		cNomeFis     := cNomeResp + "_" + cValToChar(ThreadID()) + "_" + StrZero(Int(Seconds() * 100), 8)
		cArqCompleto := cPasta + cNomeFis + ".pdf"

		// lServer = .T. (9º parâmetro) grava no servidor; lViewPDF = .F. (12º parâmetro) impede
		// a tentativa de abrir o PDF no SmartClient - não existe cliente em uma thread REST.
		oDanfe := FWMSPrinter():New(cNomeFis, IMP_PDF, .F., cPasta, .T., , , , .T., , , .F.)
		oDanfe:SetResolution(78)
		oDanfe:SetPortrait()
		oDanfe:SetPaperSize(DMPAPER_A4)
		oDanfe:SetMargin(60, 60, 60, 60)
		oDanfe:setCopies(1)
		oDanfe:cPathPDF := cPasta

		// Apenas leitura do borderô atual - NÃO avança o contador (MV_EANUBOR).
		cNumBor := GetMV("MV_EANUBOR")

		If cTipo == "notaboleto"

			Pergunte("NFSIGW", .F.)

			MV_PAR01 := cNumNota   // Nota inicial
			MV_PAR02 := cNumNota   // Nota final
			MV_PAR03 := PadR(cSerie, TamSX3("F3_SERIE")[1])
			MV_PAR04 := 2          // Operação: NF de Saída
			MV_PAR05 := 1          // Frente e verso
			MV_PAR06 := 2          // DANFE simplificado: Não
			MV_PAR07 := CToD("")   // Data de emissão inicial (sem filtro)
			MV_PAR08 := CToD("")   // Data de emissão final (sem filtro)
			// MV_PAR21 fica ZERADO de propósito: com ele = 2 o motor nativo (danfeii.prw)
			// anexaria o boleto E a Lista de Conferência de Motorista (u_relMot) sozinho -
			// documento interno de logística, sem sentido enviar para o cliente pelo
			// WhatsApp. Por isso, o DANFE e o boleto são montados em dois passos manuais
			// abaixo, no MESMO oDanfe, sem chamar u_relMot.
			MV_PAR21 := 0

			cIdEnt := RetIdEnti()
			If Empty(cIdEnt)
				cErro   := "Não foi possível obter o ID da entidade (RetIdEnti) para a filial " + AllTrim(cFilRest) + "."
				nStatus := 500
				Break
			EndIf

			U_DANFEProc(@oDanfe, .F., cIdEnt, cNumNota, cNumNota, @lExistNfe, .F., 0, @cNfceMens)

			If ! lExistNfe
				nStatus := 404
				cErro   := "Não foi possível gerar o PDF. Verifique se a nota " + cNumNota + "/" + cSerie + ;
					" está autorizada e possui XML disponível no SPED." + IIf(Empty(cNfceMens), "", " " + AllTrim(cNfceMens))
				Break
			EndIf

		EndIf

		// Anexa o boleto (ITAÚ/SICOOB/BRADESCO conforme SE1->E1_PORTADO, com fallback
		// no MV_XBCBOLE) ao mesmo oDanfe -
		// tanto para o tipo "boleto" (único conteúdo) quanto para "notaboleto" (páginas
		// extras após o DANFE). A existência do título já foi conferida acima.
		If ! fImprimeBoleto(oDanfe, cNumNota, cNumBor)
			nStatus := 500
			cErro   := "Boleto não disponível: empresa não configurada para emissão de boleto (SM0->M0_NOME diferente de 'CHUA')."
			Break
		EndIf

		// Preview() depende de sessão gráfica no SmartClient. Em thread REST, o
		// correto é Print(), que fecha o spool e grava o PDF em cPathPDF.
		oDanfe:Print()

		If ! File(cArqCompleto)
			cErro   := "O PDF não foi encontrado após a geração (" + cArqCompleto + ")."
			nStatus := 500
			Break
		EndIf

		nHandle := FOpen(cArqCompleto, FO_READ + FO_SHARED)
		If nHandle == -1
			cErro   := "O PDF foi gerado, mas não foi possível abrir o arquivo no servidor (FError " + cValToChar(FError()) + ")."
			nStatus := 500
			Break
		EndIf

		nFSize := FSeek(nHandle, 0, FS_END)
		FSeek(nHandle, 0, FS_SET)

		If nFSize <= 0
			FClose(nHandle)
			nHandle := 0
			cErro   := "O PDF gerado está vazio (0 bytes)."
			nStatus := 500
			Break
		EndIf

		cConteudo := Space(nFSize)
		FRead(nHandle, @cConteudo, nFSize)
		FClose(nHandle)
		nHandle := 0

		oJRet['sucesso']       := .T.
		oJRet['filial']        := AllTrim(cFilRest)
		oJRet['nota']          := cNumNota
		oJRet['serie']         := cSerie
		oJRet['tipo']          := cTipo
		oJRet['nomeArquivo']   := cNomeResp + ".pdf"
		oJRet['arquivoBase64'] := Encode64(cConteudo)

		lOk := .T.

	Recover
		lOk := .F.
		If Empty(cErro)
			cErro := "Erro inesperado ao gerar o PDF."
		EndIf

	End Sequence

	ErrorBlock(bErrOld)

	// ----- limpeza garantida em qualquer caminho de saída -----
	If nHandle > 0
		FClose(nHandle)
	EndIf

	If Select(cAliasQry) > 0
		(cAliasQry)->(DbCloseArea())
	EndIf

	If oDanfe <> Nil
		FreeObj(oDanfe)
		oDanfe := Nil
	EndIf

	If ! Empty(cArqCompleto) .And. File(cArqCompleto)
		FErase(cArqCompleto)
	EndIf

	If ! lOk
		oJRet['sucesso']  := .F.
		oJRet['status']   := nStatus
		oJRet['mensagem'] := cErro
	EndIf

Return lOk

/*-------------------------------------------------------------------------------*
 | Func:  fChkAlias                                                              |
 | Desc:  Garante que os aliases informados existam no dicionário e estejam      |
 |        abertos.                                                               |
 *-------------------------------------------------------------------------------*/
Static Function fChkAlias(aAlias)
	Local lOk := .T.
	Local nI  := 0

	For nI := 1 To Len(aAlias)
		If Select(aAlias[nI]) == 0
			If ! ChkFile(aAlias[nI])
				lOk := .F.
				Exit
			EndIf
		EndIf
	Next nI

Return lOk

/*-------------------------------------------------------------------------------*
 | Func:  fImprimeBoleto                                                        |
 | Desc:  Desenha as páginas do boleto (ITAÚ/SICOOB/BRADESCO) no MESMO objeto   |
 |        oDanfe recebido. O banco é escolhido primeiro pelo portador do        |
 |        título (SE1->E1_PORTADO): 341 = ITAÚ, 756 = SICOOB, 237 = BRADESCO.   |
 |        Só quando o portador vem em branco (ou com código não mapeado) é      |
 |        que cai no parâmetro MV_XBCBOLE. Mesma lógica de banco usada          |
 |        nativamente pelo danfeii.prw (MV_PAR21=2), só que sem a Lista de      |
 |        Conferência de Motorista (u_relMot), documento interno que não deve   |
 |        ir para o cliente via WhatsApp. Não verifica se o título existe -     |
 |        isso é responsabilidade do chamador (ver fExisteTituloAberto), pois   |
 |        RFINR03/04/BRADESCO não retornam sucesso/falha; apenas desenham o     |
 |        que encontrarem (ou nada).                                            |
 *-------------------------------------------------------------------------------*/
Static Function fImprimeBoleto(oDanfe, cNumNota, cNumBor)

	Local cPortad := ""
	Local cBanco  := ""

	If AllTrim(SM0->M0_NOME) <> "CHUA"
		Return .F.
	EndIf

	// Regra do banco: primeiro o portador do título (SE1->E1_PORTADO); só se ele
	// vier em branco (ou com código fora de 341/756/237) é que cai no MV_XBCBOLE.
	cPortad := fPortadorNota(cNumNota)

	Do Case
		Case cPortad == "341"
			cBanco := "ITAU"
		Case cPortad == "756"
			cBanco := "SICOOB"
		Case cPortad == "237"
			cBanco := "BRADESCO"
		OtherWise
			cBanco := AllTrim(Upper(GetMV("MV_XBCBOLE")))
	EndCase

	Do Case
		Case cBanco == "SICOOB"
			u_RFINR04(@oDanfe, cNumNota, cNumBor) // SICOOB
		Case cBanco == "BRADESCO"
			u_BRADESCO(@oDanfe, cNumNota, cNumBor) // BRADESCO
		OtherWise
			u_RFINR03(@oDanfe, cNumNota, cNumBor) // ITAÚ
	EndCase

Return .T.

/*-------------------------------------------------------------------------------*
 | Func:  fPortadorNota                                                         |
 | Desc:  Devolve o portador (SE1->E1_PORTADO, sem espaços) do primeiro         |
 |        título em aberto (E1_SALDO > 0) da nota informada na filial atual.    |
 |        Devolve "" quando não há título em aberto ou o portador vem vazio -   |
 |        nesse caso o chamador decide o banco pelo parâmetro MV_XBCBOLE.       |
 *-------------------------------------------------------------------------------*/
Static Function fPortadorNota(cNumNota)
	Local cAlias := GetNextAlias()
	Local cRet   := ""

	If ! fChkAlias({"SE1"})
		Return ""
	EndIf

	BeginSQL Alias cAlias
		SELECT SE1.E1_PORTADO
		FROM %table:SE1% SE1
		WHERE SE1.%notDel%
		AND SE1.E1_FILIAL = %xfilial:SE1%
		AND SE1.E1_NUM = %exp:cNumNota%
		AND SE1.E1_SALDO > 0
		ORDER BY SE1.E1_PREFIXO, SE1.E1_PARCELA
	EndSQL

	While ! (cAlias)->(Eof())
		If ! Empty((cAlias)->E1_PORTADO)
			cRet := AllTrim((cAlias)->E1_PORTADO)
			Exit
		EndIf
		(cAlias)->(DbSkip())
	EndDo
	(cAlias)->(DbCloseArea())

Return cRet

/*-------------------------------------------------------------------------------*
 | Func:  fExisteTituloAberto                                                    |
 | Desc:  Confere se existe ao menos um título em aberto (E1_SALDO > 0) para a   |
 |        nota informada na filial atual - mesmo filtro base usado pelo         |
 |        RFINR03 (E1_NUM = nota .And. E1_FILORIG = filial .And. E1_SALDO > 0). |
 *-------------------------------------------------------------------------------*/
Static Function fExisteTituloAberto(cNumNota)
	Local cAlias := GetNextAlias()
	Local lRet   := .F.

	BeginSQL Alias cAlias
		SELECT SE1.E1_NUM
		FROM %table:SE1% SE1
		WHERE SE1.%notDel%
		AND SE1.E1_FILIAL = %xfilial:SE1%
		AND SE1.E1_NUM = %exp:cNumNota%
		AND SE1.E1_SALDO > 0
	EndSQL

	lRet := ! (cAlias)->(Eof())
	(cAlias)->(DbCloseArea())

Return lRet

/*-------------------------------------------------------------------------------*
 | Método: titulos                                                              |
 | Desc:   Lista títulos em aberto (E1_SALDO > 0.02, E1_TIPO = 'NF') de um      |
 |         cliente, localizado pelo CNPJ/CPF (parâmetro 'cnpj', com ou sem      |
 |         formatação) na filial do ambiente atual (ver nota sobre tenantId).   |
 *-------------------------------------------------------------------------------*/
WSMETHOD GET titulos WSSERVICE ZWSNFBOL

	Local oJRet := Nil
	Local cCnpj := ""
	Local nStatus := 500
	Local lRet  := .T.

	::SetContentType("application/json")

	If ValType(::cnpj) == "C"
		cCnpj := AllTrim(::cnpj)
	EndIf

	If Empty(cCnpj)
		SetRestFault(400, "Parâmetro 'cnpj' não informado.")
		Return .F.
	EndIf

	oJRet := JsonObject():New()

	If fListaTitulosWS(cCnpj, oJRet)
		::SetResponse(oJRet:ToJson())
	Else
		nStatus := IIf(ValType(oJRet['status']) == "N", oJRet['status'], 500)
		SetRestFault(nStatus, oJRet['mensagem'])
		lRet := .F.
	EndIf

	FreeObj(oJRet)
	oJRet := Nil

Return lRet

/*-------------------------------------------------------------------------------*
 | Func:  fListaTitulosWS                                                        |
 | Desc:  Localiza o(s) cliente/loja pelo CNPJ/CPF (SA1.A1_CGC, comparado sem    |
 |        pontuação) e devolve, dentro de oJRet, a lista de títulos em aberto    |
 |        (SE1) desse(s) cliente(s) na filial atual.                            |
 *-------------------------------------------------------------------------------*/
Static Function fListaTitulosWS(cCnpj, oJRet)
	Local lOk        := .F.
	Local cErro      := ""
	Local nStatus    := 500
	Local cCgcLimpo  := fSoDigitos(cCnpj)
	Local cAliasSA1  := GetNextAlias()
	Local cAliasSE1  := GetNextAlias()
	Local aClientes  := {}
	Local aTitulos   := {}
	Local nI         := 0
	Local cCliCod    := ""
	Local cCliLoja   := ""
	Local bErrOld    := Nil
	Local oItem      := Nil

	If Empty(cCgcLimpo)
		oJRet['sucesso']  := .F.
		oJRet['status']   := 400
		oJRet['mensagem'] := "CNPJ/CPF informado está vazio após remover a formatação."
		Return .F.
	EndIf

	bErrOld := ErrorBlock({|oErr| cErro := "Erro interno: " + AllTrim(oErr:Description), ;
	                              ConOut("[ZWSNFBOL] " + cErro + " | " + ProcName(1) + " linha " + cValToChar(ProcLine(1))), ;
	                              Break(oErr) })

	Begin Sequence

		If ! fChkAlias({"SA1", "SE1"})
			cErro   := "Tabelas de clientes/títulos (SA1/SE1) indisponíveis nesta filial."
			nStatus := 500
			Break
		EndIf

		// A1_CGC já é gravado sem pontuação neste ambiente - cCgcLimpo (fSoDigitos)
		// garante que o lado do parâmetro também contenha só dígitos.
		BeginSQL Alias cAliasSA1
			SELECT SA1.A1_COD, SA1.A1_LOJA, SA1.A1_NOME
			FROM %table:SA1% SA1
			WHERE SA1.%notDel%
			AND SA1.A1_CGC = %exp:cCgcLimpo%
		EndSQL

		While ! (cAliasSA1)->(Eof())
			AAdd(aClientes, { (cAliasSA1)->A1_COD, (cAliasSA1)->A1_LOJA, AllTrim((cAliasSA1)->A1_NOME) })
			(cAliasSA1)->(DbSkip())
		EndDo
		(cAliasSA1)->(DbCloseArea())

		If Len(aClientes) == 0
			nStatus := 404
			cErro   := "Nenhum cliente encontrado para o CNPJ/CPF informado."
			Break
		EndIf

		For nI := 1 To Len(aClientes)

			cCliCod  := aClientes[nI][1]
			cCliLoja := aClientes[nI][2]

			// Sem filtro de filial de propósito: a SE1 é uma tabela única (Oracle/TOP),
			// e o cliente pode ter títulos em mais de uma filial. E1_FILORIG identifica
			// a filial de cada título - o chamador usa esse valor depois, como tenantId,
			// para chamar /gerar na filial correta daquele título específico.
			BeginSQL Alias cAliasSE1
				COLUMN E1_VENCTO AS DATE

				SELECT SE1.E1_FILORIG, SE1.E1_PREFIXO, SE1.E1_NUM, SE1.E1_PARCELA, SE1.E1_TIPO,
					SE1.E1_VENCTO, SE1.E1_VALOR, SE1.E1_SALDO
				FROM %table:SE1% SE1
				WHERE SE1.%notDel%
				AND SE1.E1_CLIENTE = %exp:cCliCod%
				AND SE1.E1_LOJA = %exp:cCliLoja%
				AND SE1.E1_SALDO > 0.02
				AND SE1.E1_TIPO = 'NF'
				ORDER BY SE1.E1_FILORIG, SE1.E1_VENCTO
			EndSQL

			While ! (cAliasSE1)->(Eof())
				oItem := JsonObject():New()
				oItem['cliente']       := AllTrim(cCliCod)
				oItem['loja']          := AllTrim(cCliLoja)
				oItem['nomeCliente']   := aClientes[nI][3]
				oItem['filial']        := AllTrim((cAliasSE1)->E1_FILORIG)
				oItem['prefixo']       := AllTrim((cAliasSE1)->E1_PREFIXO)
				oItem['numero']        := AllTrim((cAliasSE1)->E1_NUM)
				oItem['parcela']       := AllTrim((cAliasSE1)->E1_PARCELA)
				oItem['tipo']          := AllTrim((cAliasSE1)->E1_TIPO)
				oItem['vencimento']    := DtoC((cAliasSE1)->E1_VENCTO)
				oItem['valorOriginal'] := (cAliasSE1)->E1_VALOR
				oItem['saldo']         := (cAliasSE1)->E1_SALDO
				AAdd(aTitulos, oItem)
				(cAliasSE1)->(DbSkip())
			EndDo
			(cAliasSE1)->(DbCloseArea())

		Next nI

		oJRet['sucesso'] := .T.
		oJRet['titulos'] := aTitulos

		lOk := .T.

	Recover
		lOk := .F.
		If Empty(cErro)
			cErro := "Erro inesperado ao consultar títulos."
		EndIf

	End Sequence

	ErrorBlock(bErrOld)

	If Select(cAliasSA1) > 0
		(cAliasSA1)->(DbCloseArea())
	EndIf
	If Select(cAliasSE1) > 0
		(cAliasSE1)->(DbCloseArea())
	EndIf

	If ! lOk
		oJRet['sucesso']  := .F.
		oJRet['status']   := nStatus
		oJRet['mensagem'] := cErro
	EndIf

Return lOk

/*-------------------------------------------------------------------------------*
 | Func:  fSoDigitos                                                             |
 | Desc:  Remove tudo que não for dígito (pontos, barra, traço, espaços) de um   |
 |        CNPJ/CPF informado em qualquer formatação.                            |
 *-------------------------------------------------------------------------------*/
Static Function fSoDigitos(cTexto)
	Local cRet := ""
	Local nI   := 0
	Local cChr := ""

	For nI := 1 To Len(cTexto)
		cChr := SubStr(cTexto, nI, 1)
		If cChr >= "0" .And. cChr <= "9"
			cRet += cChr
		EndIf
	Next nI

Return cRet
