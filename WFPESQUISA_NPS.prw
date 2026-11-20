#INCLUDE 'Protheus.ch'
#INCLUDE "rwmake.ch"
#INCLUDE "topconn.ch"

#DEFINE CLOGPATH 	"\logs\"
#DEFINE EMAILTO		"gestao.ti@chuasa.com,ti@chuasa.com,gestao.marketing@chuasa.com"
#DEFINE CTIPOMSG 	"Pesquisa Satisfa��o - Clientes"
#DEFINE CROTINA  	"MJOB011"
#DEFINE CDESCRICAO = "JOB para envio de Pesquisa de Satisfacao para clientes via Whatsapp"
#DEFINE NMESESCPR 6
#DEFINE CASSUNTO  "Pesquisa NPS 2026"
/*
+----------------------------------------------------------------------------+
|                        FICHA TECNICA DO PROGRAMA                           |
+----------------------------------------------------------------------------+
|   DADOS DO PROGRAMA                                                        |
+------------------+---------------------------------------------------------+
|Tipo              | JOB                                                     |
+------------------+---------------------------------------------------------+
|Nome da Fun��o    | WFPESQUI  - MJOB011                      		 		 |
+------------------+---------------------------------------------------------+
|Descricao         | 														 |
+------------------+---------------------------------------------------------+
|Parametros        |                                                         |
+------------------+---------------------------------------------------------+
|Retorno           | Nenhum                                                  |
+------------------+---------------------------------------------------------+
|Autor             | Rafael Bueno Galo - rbgalo@gmail.com  					 |
+------------------+---------------------------------------------------------+
|Contato           |                                                         |
+------------------+---------------------------------------------------------+
|Data de Criacao   | 27/05/2019		                                         |
+------------------+---------------------------------------------------------+
|   ATUALIZACOES                                                             |
+-------------------------------------------+-----------+-----------+--------+
|   Descricao detalhada da atualizacao      |Nome do    | Analista  |Data da |
|                                           |Solicitante| Respons.  |Atualiz.|
+-------------------------------------------+-----------+-----------+--------+


User Function WFPESFRMNPS()
	//+----------------------------------------------------+
	//| Declaracao Variaveis							   |
	//+----------------------------------------------------+
	Local 	bBlock 		:= ErrorBlock()
	Local 	nLenFil		:= 0
	Local 	nI			:= 1
	Private lAuto		:= .F.
	Private	aFiliais	:= {"02"}

	ErrorBlock( {|e| ChecErro(e)})

	//+----------------------------------------------------+
	//| Tratamento de Exce��o							   |
	//+----------------------------------------------------+
	BEGIN SEQUENCE


		nLenFil = Len ( aFiliais )

		//+---------------------------------------------------+
		//| Percorre array de filiais						  |
		//+---------------------------------------------------+
		For nI := 1 To nLenFil

			//+----------------------------------------------------+
			//| Testa se esta sendo rodado do menu	  			   |
			//+----------------------------------------------------+
			If	Select('SX2') == 0
				RPCSetType( 3 )//N�o consome licensa de uso
				RpcSetEnv('01',aFiliais[nI],,,,GetEnvServer(),{ "SD2","SA1","SC5" })
				ConOut('Pesquisa Clientes... '+Dtoc(DATE())+' - '+Time())
				lAuto := .T.
			EndIf

			If	( ! lAuto )
				LjMsgRun(OemToAnsi('Processando...'),,{|| execWF(aFiliais[nI])} )
			Else
				execWF(aFiliais[nI])
			EndIf

			If	( lAuto )
				RpcClearEnv()//Libera o Environment
				ConOut('Workflow Finalizado. '+Dtoc(DATE())+' - '+Time())
			EndIf

		Next nI
		//| Fim Percorre array de filiais					  |
		//+---------------------------------------------------+

		RECOVER
		ErrorBlock(bBlock)
	END SEQUENCE

Return ( Nil )


Static Function execWF(cFil)
	Local 	nQtdReg  	:= 0
	Local 	_cMsg		:= ""
	//Emails
	Local 	cCabeMsg	:= ""
	Local 	cFimMsg		:= ""
	Local 	lRet		:= .F. //Retorno envio email
	Local 	lRetAnt		:= .F. //Retorno envio email anterior
	Local 	cMsgEnv		:= ""
	Local   cMailAnt    := ""
	Local   cLink    := 'https://forms.monday.com/forms/769b8b50799d1411137442c588153849?r=use1'
	Local   cFont    := 'font-family:Arial, Helvetica, sans-serif;'
	Local   nX       := 0

	//+----------------------------------------------------+
//| Email											   |	
//| Cabe�alho da Mensagem							   |	
//+----------------------------------------------------+

	//+----------------------------------------------------+
	//| Email - Cabe�alho da Mensagem                      |
	//+----------------------------------------------------+
	cCabeMsg := '<!DOCTYPE html>' + CRLF
	cCabeMsg += '<html lang="pt-BR">' + CRLF
	cCabeMsg += '<head>' + CRLF
	cCabeMsg += '<meta charset="windows-1252">' + CRLF
	cCabeMsg += '<meta name="viewport" content="width=device-width, initial-scale=1.0">' + CRLF
	cCabeMsg += '<meta name="color-scheme" content="light">' + CRLF
	cCabeMsg += '<title>Chu� Distribuidora | Pesquisa de Satisfa��o</title>' + CRLF
	cCabeMsg += '<style>' + CRLF
	cCabeMsg += '@media only screen and (max-width: 620px) {' + CRLF
	cCabeMsg += '.container { width: 100% !important; }' + CRLF
	cCabeMsg += '.px { padding-left: 22px !important; padding-right: 22px !important; }' + CRLF
	cCabeMsg += '.h1 { font-size: 28px !important; line-height: 34px !important; }' + CRLF
	cCabeMsg += '.num a { font-size: 13px !important; padding: 9px 0 !important; }' + CRLF
	cCabeMsg += '}' + CRLF
	cCabeMsg += '</style>' + CRLF
	cCabeMsg += '</head>' + CRLF
	cCabeMsg += '<body style="margin:0; padding:0; background-color:#EEEDEB;">' + CRLF

	// Texto de pr�-visualiza��o (ao lado do assunto na caixa de entrada)
	cCabeMsg += '<div style="display:none; max-height:0; overflow:hidden; mso-hide:all;">Leva menos de 1 minuto. Sua resposta chega direto � nossa equipe.</div>' + CRLF

	// Estrutura externa
	cCabeMsg += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#EEEDEB;">' + CRLF
	cCabeMsg += '<tr><td align="center" style="padding:28px 12px;">' + CRLF
	cCabeMsg += '<table role="presentation" class="container" width="600" cellpadding="0" cellspacing="0" border="0" style="width:600px; background-color:#FFFFFF; border-radius:6px; overflow:hidden;">' + CRLF

	// Faixa laranja
	cCabeMsg += '<tr><td style="height:6px; background-color:#F26522; font-size:0; line-height:0;">&nbsp;</td></tr>' + CRLF

	// Cabe�alho
	cCabeMsg += '<tr><td class="px" style="padding:28px 40px 0 40px;">' + CRLF
	cCabeMsg += '<span style="' + cFont + ' font-size:26px; font-weight:bold; letter-spacing:1px; color:#6D6E71;">CHU�</span>' + CRLF
	cCabeMsg += '<span style="' + cFont + ' font-size:12px; color:#9A9B9E; padding-left:6px;">Al�m da distribui��o</span>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF

	// Abertura
	cCabeMsg += '<tr><td class="px" style="padding:30px 40px 0 40px; ' + cFont + '">' + CRLF
	cCabeMsg += '<p style="margin:0 0 10px 0; font-size:16px; color:#6D6E71;">Ol�!</p>' + CRLF
	cCabeMsg += '<h1 class="h1" style="margin:0; font-size:34px; line-height:40px; font-weight:bold; color:#2E2F31;">Como tem sido comprar com a Chu�?</h1>' + CRLF
	cCabeMsg += '<p style="margin:16px 0 0 0; font-size:16px; line-height:25px; color:#4A4B4E;">Queremos ouvir voc� para melhorar o que realmente faz diferen�a no seu neg�cio. S�o poucas perguntas e leva menos de 1 minuto.</p>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF

	// Escala NPS clic�vel
	cCabeMsg += '<tr><td class="px" style="padding:30px 40px 0 40px;">' + CRLF
	cCabeMsg += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#FFF4EC; border-radius:6px;">' + CRLF
	cCabeMsg += '<tr><td style="padding:22px 18px 8px 18px; ' + cFont + ' font-size:15px; line-height:22px; color:#2E2F31; font-weight:bold;">De 0 a 10, quanto voc� recomendaria a Chu� para outros varejistas?</td></tr>' + CRLF
	cCabeMsg += '<tr><td style="padding:8px 14px 0 14px;">' + CRLF
	cCabeMsg += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>' + CRLF

	For nX := 0 To 10
		cCabeMsg += '<td class="num" align="center" width="9%" style="padding:0 2px;">'
		cCabeMsg += '<a href="' + cLink + '" style="display:block; padding:11px 0; background-color:#FFFFFF; border:1px solid #F3B48C; border-radius:4px; ' + cFont + ' font-size:15px; font-weight:bold; color:#2E2F31; text-decoration:none;">'
		cCabeMsg += cValToChar(nX) + '</a></td>' + CRLF
	Next nX

	cCabeMsg += '</tr></table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF
	cCabeMsg += '<tr><td style="padding:8px 18px 20px 18px;">' + CRLF
	cCabeMsg += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0"><tr>' + CRLF
	cCabeMsg += '<td align="left" style="' + cFont + ' font-size:12px; color:#8A8B8E;">Nada prov�vel</td>' + CRLF
	cCabeMsg += '<td align="right" style="' + cFont + ' font-size:12px; color:#8A8B8E;">Muito prov�vel</td>' + CRLF
	cCabeMsg += '</tr></table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF
	cCabeMsg += '</table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF

	// Bot�o principal
	cCabeMsg += '<tr><td class="px" align="center" style="padding:28px 40px 0 40px;">' + CRLF
	cCabeMsg += '<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>' + CRLF
	cCabeMsg += '<td align="center" style="background-color:#F26522; border-radius:28px;">' + CRLF
	cCabeMsg += '<a href="' + cLink + '" style="display:inline-block; padding:16px 38px; ' + cFont + ' font-size:16px; font-weight:bold; color:#FFFFFF; text-decoration:none;">Responder a pesquisa</a>' + CRLF
	cCabeMsg += '</td></tr></table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF

	// O que acontece com a resposta / SAC
	cCabeMsg += '<tr><td class="px" style="padding:32px 40px 0 40px;">' + CRLF
	cCabeMsg += '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top:1px solid #E6E5E2;">' + CRLF
	cCabeMsg += '<tr><td style="padding:24px 0 0 0; ' + cFont + '">' + CRLF
	cCabeMsg += '<p style="margin:0 0 8px 0; font-size:15px; font-weight:bold; color:#2E2F31;">O que fazemos com a sua resposta</p>' + CRLF
	cCabeMsg += '<p style="margin:0; font-size:15px; line-height:24px; color:#4A4B4E;">Cada resposta � lida pela nossa equipe de Qualidade, que analisa os pontos levantados e trabalha para resolver os problemas apontados.</p>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF
	cCabeMsg += '<tr><td style="padding:22px 0 0 0; ' + cFont + '">' + CRLF
	cCabeMsg += '<p style="margin:0 0 8px 0; font-size:15px; font-weight:bold; color:#2E2F31;">Precisa falar com a gente?</p>' + CRLF
	cCabeMsg += '<p style="margin:0 0 14px 0; font-size:15px; line-height:24px; color:#4A4B4E;">Se quiser tratar algum problema diretamente, fale com o SAC Chu� pelo WhatsApp (33) 99876-8088 ou pelo telefone fixo (33) 3225-3126, das 8h �s 11h30 e das 13h �s 18h. Esse contato tamb�m est� dispon�vel no nosso site.</p>' + CRLF
	cCabeMsg += '<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>' + CRLF
	cCabeMsg += '<td align="center" style="border:1px solid #F26522; border-radius:24px;">' + CRLF
	cCabeMsg += '<a href="https://wa.me/5533998768088" style="display:inline-block; padding:10px 24px; ' + cFont + ' font-size:14px; font-weight:bold; color:#F26522; text-decoration:none;">Falar com o SAC no WhatsApp</a>' + CRLF
	cCabeMsg += '</td></tr></table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF
	cCabeMsg += '</table>' + CRLF
	cCabeMsg += '</td></tr>' + CRLF

	//+----------------------------------------------------+
	//| Finaliza��o da mensagem                            |
	//+----------------------------------------------------+
	// Assinatura
	cFimMsg := '<tr><td class="px" style="padding:28px 40px 36px 40px; ' + cFont + '">' + CRLF
	cFimMsg += '<p style="margin:0; font-size:15px; line-height:24px; color:#4A4B4E;">Obrigado pela parceria e por confiar na Chu�!</p>' + CRLF
	cFimMsg += '<p style="margin:6px 0 0 0; font-size:15px; font-weight:bold; color:#F26522;">#SomosUmaS�Chu�</p>' + CRLF
	cFimMsg += '</td></tr>' + CRLF

	// Rodap�
	cFimMsg += '<tr><td class="px" style="padding:22px 40px; background-color:#6D6E71; ' + cFont + ' font-size:12px; line-height:19px; color:#E9E9EA;">' + CRLF
	cFimMsg += '<strong style="color:#FFFFFF;">Chu� Distribuidora</strong><br>' + CRLF
	cFimMsg += 'R. Professor Jos� de Carvalho, 384 - Universit�rio - Governador Valadares - MG<br>' + CRLF
	cFimMsg += '<a href="https://chuadistribuidora.com.br" style="color:#FFFFFF; text-decoration:underline;">chuadistribuidora.com.br</a><br><br>' + CRLF
	cFimMsg += 'Voc� recebeu este e-mail por ser cliente da Chu� Distribuidora. Suas respostas s�o usadas exclusivamente para a melhoria dos nossos servi�os.' + CRLF
	cFimMsg += '</td></tr>' + CRLF

	// Fecha estrutura
	cFimMsg += '</table>' + CRLF
	cFimMsg += '</td></tr>' + CRLF
	cFimMsg += '</table>' + CRLF
	cFimMsg += '</body>' + CRLF
	cFimMsg += '</html>' + CRLF

	_cMsg := cCabeMsg + cFimMsg

	// Grava uma c�pia para conferir o layout no navegador
	MemoWrite(CLOGPATH + 'WF_PESQUISA_EMAIL.html', _cMsg)

	//+---------------------------------------------------+
	//| Query SQL busca Clientes						  |
	//+---------------------------------------------------+
	nQtdReg := Qry()

	If nQtdReg > 0

		//+----------------------------------------------------+
		//Processando Registros								   |
		//+----------------------------------------------------+
		While QRY->(!Eof())
			cCliente	:= QRY->A1_COD
			cNome		:= QRY->A1_NOME
			cEmail 		:= AllTrim(QRY->EMAIL)

			// Tratativa para nao enviar para o mesmo email
			// Se vazio eh o primeiro Envio
			// Envia uma vez por e-mail (query ordenada por EMAIL).
			// == � compara��o exata; != no AdvPL compara s� at� o tamanho do operando da direita.
			If Empty(cMailAnt) .Or. !(cMailAnt == cEmail)

				// PRODU��O: descomente a linha abaixo e comente a linha de TESTE
				//lRet := u_EnvMail1(cEmail,;									//_cPara
				lRet := u_EnvMail1("ti@chuasa.com",;							//_cPara TESTE
				,;																//_cCc
				"ti@chuasa.com",;												//_cBCC
				"Como tem sido comprar com a Chu�? - " + AllTrim(cNome) ,;		//Assunto
				,;																//_aAnexo
				_cMsg,;															//_cMsg
				.T.)

			EndIf

			//---------------------------------------------+
			//| Marca Z06 - Cliente como enviado		   |
			//---------------------------------------------+
			If ((lRet) .Or. ((cMailAnt == cEmail) .And. lRetAnt ))
				//Faz isso para gravar na Z06 mesmo sem ter enviado o email para o email repetido
				//Verificando se o email anterior foi enviado
				lRetAnt := lRet

				//+-------------------------------------------------+
				//| guarda os dados dos clientes que foram enviados |
				//| para enviar por email 						    |
				//+-------------------------------------------------+
				cMsgEnv += '<p>Enviado: ' + cCliente + '/' + AllTrim(cNome) + ' - ' + cEmail + '</p>' + CRLF

				dbSelectArea("Z06")
				If Reclock("Z06",.T.)
					Z06->Z06_FILIAL := XFilial("Z06")
					Z06->Z06_CLIENT := cCliente
					Z06->Z06_DATENV	:= DATE()
					Z06->Z06_ASSUNT := CASSUNTO
					MsUnlock("Z06")
				EndIf
				Sleep( 1000 )
			Else
				conout("Falha ao enviar email, nao gravou na Z06 - " + cCliente )
				cMsgEnv += '<p>FALHA: ' + cCliente + '/' + AllTrim(cNome) + ' - ' + cEmail + '</p>' + CRLF
				Sleep( 1000 )
			EndIf
			//Guarda valor do email
			cMailAnt := cEmail

			//---------------------------------------------+
			//| Proximo registro						   |
			//---------------------------------------------+
			QRY->(DbSkip())
		End
		//+---------------------------------------------+
		//| Fim do envio para Filial 					|
		//| Envia os dados dos enviados por email para  |
		//| acompanhamento								|
		//+---------------------------------------------+
		If (!Empty(cMsgEnv))
			u_EnvMail1(EMAILTO,;									//_cPara
			,;														//_cCc
			"ti@chuasa.com",;										//_cBCC
			"WorkFlow - Pesquisa de Satisfa��o -  ENVIADOS NO DIA" ,;
				,;														//_aAnexo
			cMsgEnv,;												//_cMsg
			.T.)

		EndIf
	EndIf
Return ( Nil )

//+----------------------------------------------------+
//| Qry												   |	
//| Ajuste 13/03/2025							       |
//+----------------------------------------------------+
Static Function Qry()
	Local cQuery  := ""
	Local nCnt    := 0
	Local cDtIni  := DToS(MonthSub(Date(), NMESESCPR))           // AAAAMMDD de 6 meses atr�s
	Local cAssunt := PadR(CASSUNTO, TamSX3("Z06_ASSUNT")[1])      // completa at� o tamanho do campo

	If Select("QRY") <> 0
		DbSelectArea("QRY")
		DbCloseArea()
	EndIf

	cQuery := " SELECT SA1.A1_COD, " + CRLF
	cQuery += "        SA1.A1_LOJA, " + CRLF
	cQuery += "        SA1.A1_NOME, " + CRLF
	cQuery += "        SA1.A1_MUN, " + CRLF
	cQuery += "        JSON_VALUE(IR.RESPONSE_DATA, '$.researchResponses.TELEFONE') AS TELEFONE, " + CRLF
	cQuery += "        JSON_VALUE(IR.RESPONSE_DATA, '$.researchResponses.EMAIL')    AS EMAIL " + CRLF
	cQuery += "   FROM IONV_SYNC.IONVR_RESEARCH_RESPONSES IR " + CRLF
	cQuery += "   INNER JOIN " + RetSqlName("SA1") + " SA1 ON IR.TARGET_ID = SA1.R_E_C_N_O_ " + CRLF
	cQuery += "          AND SA1.D_E_L_E_T_ = ' ' " + CRLF
	cQuery += " WHERE EXISTS ( SELECT 1 FROM " + RetSqlName("SF2") + " SF2 " + CRLF
	cQuery += "                 WHERE SF2.F2_FILIAL  = '" + xFilial("SF2") + "' " + CRLF
	cQuery += "                   AND SF2.F2_CLIENTE = SA1.A1_COD " + CRLF
	cQuery += "                   AND SF2.F2_LOJA    = SA1.A1_LOJA " + CRLF
	cQuery += "                   AND SF2.F2_TIPO    = 'N' " + CRLF
	cQuery += "                   AND SF2.F2_EMISSAO >= '" + cDtIni + "' " + CRLF
	cQuery += "                   AND SF2.D_E_L_E_T_ = ' ' ) " + CRLF
	cQuery += "   AND NOT EXISTS ( SELECT 1 FROM " + RetSqlName("Z06") + " Z06 " + CRLF
	cQuery += "                     WHERE Z06.Z06_CLIENT = SA1.A1_COD " + CRLF
	cQuery += "                       AND Z06.Z06_ASSUNT = '" + cAssunt + "' " + CRLF
	cQuery += "                       AND Z06.D_E_L_E_T_ = ' ' ) " + CRLF
	// Sem e-mail n�o h� o que enviar
	cQuery += "    AND NVL(TRIM(JSON_VALUE(IR.RESPONSE_DATA, '$.researchResponses.EMAIL')), ' ') <> ' ' " + CRLF
	cQuery += "  ORDER BY EMAIL, SA1.A1_COD, SA1.A1_LOJA "

	MemoWrite(CLOGPATH + 'WF_PESQUISA_FORM_NPS.sql', cQuery)

	cQuery := ChangeQuery(cQuery)
	DbUseArea(.T., "TOPCONN", TcGenQry(,,cQuery), "QRY", .T., .F.)

	DbSelectArea("QRY")
	DbGoTop()
	DbEval({|| nCnt++ })
	DbGoTop()

Return ( nCnt )
