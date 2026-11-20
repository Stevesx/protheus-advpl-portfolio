#Include "topconn.ch"
#Include "Protheus.ch"
#include "tbiconn.ch"

#DEFINE	CMAILTO  	"comercial.gv@chuasa.com,patricia.faria@chuasa.com,notafiscal@chuasa.com,fiscal@chuasa.com,apoio.vendas.gv@chuasa.com,ayrton.rodrigues@chuasa.com,guilherme.viana@chuasa.com,supervisao.ci@chuasa.com"
#DEFINE CEMAILCC	"gestao.fiscal@chuasa.com"
#DEFINE EMAILBCC	"ti@chuasa.com,gestao.ti@chuasa.com"

/*
+----------------------------------------------------------------------------+
|                        FICHA TECNICA DO PROGRAMA                           |
+----------------------------------------------------------------------------+
|   DADOS DO PROGRAMA                                                        |
+------------------+---------------------------------------------------------+
|Tipo              | Ponto de Entrada                                        |
+------------------+---------------------------------------------------------+
|Modulo            | Compras	  											 |
+------------------+---------------------------------------------------------+
|Nome da Fun��o    | A010TOK                                     		     |
+------------------+---------------------------------------------------------+
|Descricao         | Valida��o para inclus�o ou altera��o do Produto		 |
|				   | LOCALIZA��O : Function A010TudoOK - Fun��o de Valida��o |
|				   | para inclus�o ou altera��o do Produto.					 |
|				   | EM QUE PONTO: No in�cio das valida��es ap�s a confir-   |
|				   | ma��o da inclus�o ou altera��o, antes da grava��o do    |
|				   | Produto; deve ser utilizado para valida��es adicionais  |
|				   | para a INCLUS�O ou ALTERA��O do Produto.			     |
+------------------+---------------------------------------------------------+
|Parametros        | INCLUI/ALTERA/			                                 |
+------------------+---------------------------------------------------------+
|Retorno           | Nenhum                                                  |
+------------------+---------------------------------------------------------+
|Autor             | Max Rocha   											 |
+------------------+---------------------------------------------------------+
|Contato           |                                                         |
+------------------+---------------------------------------------------------+
|Data de Criacao   | 30/10/2018		                                         |
+------------------+---------------------------------------------------------+
|   ATUALIZACOES                                                             |
+-------------------------------------------+-----------+-----------+--------+
|   Descricao detalhada da atualizacao      |Nome do    | Analista  |Data da |
|                                           |Solicitante| Respons.  |Atualiz.|
+-------------------------------------------+-----------+-----------+--------+
| Cria��o do cabe�alho do fonte             |           |Rafael Galo|24/01/19|
+-------------------------------------------+-----------+-----------+--------+

+-------------------------------------------+-----------+-----------+--------+
| Justificativa Desativao/Bloqueio -        |           |Gabriel	|31/08/2026| 
|                                           |           |           |
+-------------------------------------------+-----------+-----------+--------+
*/


User Function A010TOK()
	//+----------------------------------------------------+
	//| Declaracao Variaveis							   |
	//+----------------------------------------------------+
	Local aAreaBkp	:= {}
	Local cCodUser 	:= "" //Retorna o Codigo do Usuario
	Local cNamUser 	:= "" //Retorna o nome do usuario
	Local cAmbiente	:= "" //Retorno o nome do ambiente
	Local lForalin	:= .F.  //Controlar o que foi alterado
	Local lDesativ  := .F. //Controlar o que foi alterado
	Local lDes02    := .F. //Controlar o que foi alterado
	Local lDes05    := .F. //Controlar o que foi alterado
	Local lBloq		:= .F.  //Controlar o que foi alterado
	Local lTes01	:= .F. //TES 01
	Local lTes02	:= .F. //TES 02
	Local lTes05	:= .F. //TES 05
	Local lPreco	:= .F. //Pre�o venda
	Local lUm		:= .F. // Unidade Medida
	Local lSegUm	:= .F. // Segunda Unidade Medida
	Local lConv		:= .F. // Fator Conversao
	Local lDesc		:= .F. // Descricao Produto
	Local lRefFab	:= .F. // Referencia Fabrica
	Local lMva		:= .F. // MVA
	Local lMvaEnt	:= .F. // MVA Entrada
	Local lClasfis	:= .F. // Classifica��o Fiscal
	Local lGrtrib	:= .F. // Grupo Tribut�rio
	Local lFECP		:= .F. // FCP
	Local lST		:= .F. // Situa��o Tribut�ria
	Local lRet 	:= .T. //Returno do PE
	Local cNomeEmp	:= AllTrim(FWSM0Util():GetSM0Data(cEmpAnt, cFilAnt, {'M0_NOME'})[1][2])
	Local cError    := ""
	Local bError	:= {|| }


	//+----------------------------------------------------+
	//| Justificativa Desativa��o/Bloqueio - Gabriel       |
	//| 31/08/2026										   |
	//+----------------------------------------------------+
	Local oBtnSalvar
	Local oBtnVoltar
	Local lVaiDesativ	:= .F.	// Produto est� SENDO desativado nesta altera��o
	Local lVaiBloq		:= .F.	// Produto est� SENDO bloqueado nesta altera��o
	Local lPedeJustif	:= .F.	// Indica se a tela de justificativa deve aparecer
	Local lConfirmaJust	:= .F.	// Usu�rio clicou em "Salvar" na tela de justificativa
	Local lErroValid	:= .F.
	Local oDlgJust
	Local nLinAtu		:= 0
	Local nAltDlg		:= 0
	Local lVaiDesGer	:= .F.	// Desat. Geral (B1_DESATIV) sendo marcado agora
	Local lVaiDesGV		:= .F.	// Desativar GV (B1_DES02) sendo marcado agora
	Local lVaiDesJF		:= .F.	// Desat JF05 (B1_DES05) sendo marcado agora
	Local cTxtAcao      := ""

	// Grupo Desativa��o
	Local cMotivoDesativ := Space(80)
	Local cMotivoBloq    := Space(80)
	Local cJustific     := Space(200)

	Static cForaLin	:= ""
	Static cDesativ := ""
	Static cDes02   := ""
	Static cDes05   := ""
	Static cBloq	:= ""
	Static cTes01   := ""
	Static cTes02   := ""
	Static cTes05   := ""
	Static cPreco	:= ""
	Static cUm		:= ""
	Static cSegUm	:= ""
	Static cConv	:= ""
	Static cDesc	:= ""
	Static cRefFab	:= ""

	Begin Sequence

		cError	:= ""
		bError 	:= ErrorBlock({|oError| integracao.Winthor.u_getErrorBlock(oError,@cError) } )
		//+--------------------------------------------------------+
		//| Backup das �reas atuais								   |
		//+--------------------------------------------------------+
		aEval({"SB1"}, { |area| aAdd(aAreaBkp, (area)->(GetArea()) ) } )
		aAdd(aAreaBkp, GetArea())

		//Max Rocha:  30/10/2018
		//Reenvia dados ao WMS
		If cNomeEmp == "CHUA" .AND. GetMV("MV_WMSWINT") .and. M->B1_WMSEXP=="S" //WMS Habilitado e envio de Cadastros habilitado

			IF M->B1_WMSSTAT=="2"
				Alert("ATEN��O: Os dados deste produto ser�o reenviados para o WMS Winthor... Obrigat�rio avisar a mesa de opera��o!")
			EndIF
			M->B1_WMSSTAT := "1" //Altera status para reintegrar
			M->B1_WMSDATE := Ctod("  /  /  ")

			DBSelectArea("SB1")
			DBSetOrder(1)
			IF DbSeek(xFilial("SB1")+M->B1_COD)
				If RecLock("SB1", .F.)
					Replace SB1->B1_WMSSTAT With "1" //Altera status para reintegrar
					Replace SB1->B1_WMSDATE With Ctod("  /  /  ")
					MsUnlock()
				EndIF
			EndIF

			integracao.Winthor.u_gravaLog(.T., "A010TOK", "Produto " + SB1->B1_COD + " - " + Alltrim(SB1->B1_DESC) + " marcado para reintegrar com o Winthor." )
		EndIF

		//Max Rocha - 18-11-2019
		If (M->B1_ST = "S")
			if Empty(M->B1_CEST)
				//Help(NIL, NIL, "HELP", NIL, "Campo CEST obrigat�rio para produtos [Com] S.Tribut�ria!", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Favor preencher o campo C�digo CEST..."})
				Alert("CEST Obrigat�rio!!!")
				lRet :=  .F.
			EndIF
		EndIf
		If (M->B1_ST <> "S")
			if ! Empty(M->B1_CEST)
				//Help(NIL, NIL, "HELP", NIL, "Campo CEST preenchido para produtos [Sem] S.Tribut�ria!", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Favor deixar em branco o campo C�digo CEST..."})
				Alert("Favor n�o preencher CEST!!!")
				// lRet :=  .F.
			EndIF
		EndIf
		//Fim



		If cNomeEmp == "CHUA"
			//+----------------------------------------------------+
			//| Verificar obrigatoriedade Pre�o venda			   |
			//| Para produtos do Tipo ME						   |
			//| Rafael Bueno Galo - 29/03/2019					   |
			//+----------------------------------------------------+
			If (M->B1_TIPO == 'ME') .And. (M->B1_PRV1 <= 0)
				Help(NIL, NIL, "HELP", NIL, "Campo pre�o de venda obrigat�rio.", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Favor preencher o campo pre�o de venda."})
				lRet :=  .F.
			EndIf

			//+----------------------------------------------------+
			//| Na inclusao perguntar se esta substituindoalgum    |
			//| produto. Se sim pedir para preencher campo codigo  |
			//| Anterior.										   |
			//| Rafael Bueno Galo								   |
			//+----------------------------------------------------+
			If (INCLUI)
				SBM->(dbSelectArea("SBM"))
				SBM->(dbSetOrder(1))
				If SBM->( dbSeek(xFilial("SBM")+AllTrim(M->B1_GRUPO)))
					If ( SBM->BM_WMSEXP == 'S' )
						If Empty(M->B1_CODANT)
							integracao.Winthor.u_showLogInConsole("A01TOK" + M->B1_CODANT)
							If(MsgYesNo("Esse produto est� substitundo algum outro?","Cadastro Produto"))
								//Help( ,, 'HELP',, 'Favor preencher o campo C�gigo anterior na aba Outros. B1_CODANT.","Cadastro Produto', 1, 0)
								Help(NIL, NIL, "HELP", NIL, "Campo C�digo anterior obrigat�rio.", 1, 0, NIL, NIL, NIL, NIL, NIL, {"Favor preencher o campo C�digo anterior B1_CODANT na aba Outros."})
								lRet :=  .F.
							EndIf
						Else
							lRet := .T.
						EndIf
					EndIf
				EndIf
			EndIf
			//| Final Inclui									   |
			//+----------------------------------------------------+

			//+----------------------------------------------------+
			//| Envio de email, informando quando for alterado     |
			//| Campos principais do cadastro de produtos    	   |
			//| Rafael Galo - 24/01/2019						   |
			//+----------------------------------------------------+
			If (ALTERA )
				SBM->(dbSelectArea("SBM"))
				SBM->(dbSetOrder(1))
				If SBM->( dbSeek(xFilial("SBM")+AllTrim(B1_GRUPO)))
					If ( SBM->BM_WMSEXP == 'S' )
						//Se for Altera�ao
						SB1->(DBSelectArea( "SB1" ))
						SB1->(DBSetOrder(1))
						If SB1-> ( DbSeek(xFilial("SB1")+M->B1_COD) )
							If M->B1_FORALIN <> SB1->B1_FORALIN
								lForalin := .T.
								cForaLin := "Anterior: " + IIF(SB1->B1_FORALIN == 'S','Sim','N�o') + " - Atual: " + IIF(M->B1_FORALIN == 'S','Sim','N�o')
							EndIf
							If M->B1_DESATIV <> SB1->B1_DESATIV
								lDesativ := .T.
								cDesativ := "Anterior: " + IIF(SB1->B1_DESATIV == 'S','Sim','N�o') + " - Atual: " + IIF(M->B1_DESATIV == 'S','Sim','N�o')
							EndIf
							If M->B1_DES02 <> SB1->B1_DES02
								lDes02 := .T.
								cDes02 := "Anterior: " + IIF(SB1->B1_DES02 == 'S','Sim','N�o') + " - Atual: " + IIF(M->B1_DES02 == 'S','Sim','N�o')
							EndIf
							If M->B1_DES05 <> SB1->B1_DES05
								lDes05 := .T.
								cDes05 := "Anterior: " + IIF(SB1->B1_DES05 == 'S','Sim','N�o') + " - Atual: " + IIF(M->B1_DES05== 'S','Sim','N�o')
							EndIf
							If M->B1_MSBLQL <> SB1->B1_MSBLQL
								lBloq := .T.
								cBloq := "Anterior: " + IIF(SB1->B1_MSBLQL == '1','S','N�o') + " - Atual: " + IIF(M->B1_MSBLQL == '1','S','N�o')
							EndIf

							If M->B1_TSBONIF <> SB1->B1_TSBONIF
								lTes01 := .T.
								cTes01 := "Anterior: " + SB1->B1_TSBONIF + " - Atual: " + M->B1_TSBONIF
							EndIf

							If M->B1_TS02 <> SB1->B1_TS02
								lTes02 := .T.
								cTes02 := "Anterior: " + SB1->B1_TS02 + " - Atual: " + M->B1_TS02
							EndIf
							If M->B1_TS05 <> SB1->B1_TS05
								lTes05 := .T.
								cTes05 := "Anterior: " + SB1->B1_TS05 + " - Atual: " + M->B1_TS05
							EndIf
							If M->B1_PRV1 <> SB1->B1_PRV1
								lPreco := .T.
								cPreco := "Anterior: " + AllTrim(Transform(SB1->B1_PRV1, '@E 9,999,999.9999')) + " - Atual: " + AllTrim(Transform(M->B1_PRV1, '@E 9,999,999.9999'))
							EndIf
							//20/05/2024
							If M->B1_UM <> SB1->B1_UM
								lUm 	:= .T.
								cUm 	:= "Anterior: " + AllTrim(SB1->B1_UM) + " - Atual: " + AllTrim(M->B1_UM)
							EndIf
							If M->B1_SEGUM <> SB1->B1_SEGUM
								lSegUm 	:= .T.
								cSegUm 	:= "Anterior: " + AllTrim(SB1->B1_SEGUM) + " - Atual: " + AllTrim(M->B1_SEGUM)
							EndIf
							If M->B1_CONV <> SB1->B1_CONV
								lConv 	:= .T.
								cConv 	:= "Anterior: " + AllTrim(SB1->B1_CONV) + " - Atual: " + AllTrim(M->B1_CONV)
							EndIf

							//B1_DESC, SB1.B1_REFFAB
							If M->B1_DESC <> SB1->B1_DESC
								lDesc 	:= .T.
								cDesc 	:= "Anterior: " + AllTrim(SB1->B1_DESC) + " - Atual: " + AllTrim(M->B1_DESC)
							EndIf
							If M->B1_REFFAB <> SB1->B1_REFFAB
								lRefFab := .T.
								cRefFab := "Anterior: " + AllTrim(SB1->B1_REFFAB) + " - Atual: " + AllTrim(M->B1_REFFAB)
							EndIf
							If M->B1_PICMRET <> SB1->B1_PICMRET
								lMva := .T.
								cMva := "Anterior: " + AllTrim(SB1->B1_PICMRET) + " - Atual: " + AllTrim(M->B1_PICMRET)
							EndIf
							If M->B1_PICMENT <> SB1->B1_PICMENT
								lMvaEnt := .T.
								cMvaEnt := "Anterior: " + AllTrim(SB1->B1_PICMENT) + " - Atual: " + AllTrim(M->B1_PICMENT)
							EndIf
							If M->B1_CLASFIS <> SB1->B1_CLASFIS
								lClasfis := .T.
								cClasfis := "Anterior: " + AllTrim(SB1->B1_CLASFIS) + " - Atual: " + AllTrim(M->B1_CLASFIS)
							EndIf
							If M->B1_GRTRIB <> SB1->B1_GRTRIB
								lGrtrib := .T.
								cGrtrib := "Anterior: " + AllTrim(SB1->B1_GRTRIB) + " - Atual: " + AllTrim(M->B1_GRTRIB)
							EndIf
							If M->B1_XFECP <> SB1->B1_XFECP
								lFECP := .T.
								cFECP := "Anterior: " + AllTrim(SB1->B1_XFECP) + " - Atual: " + AllTrim(M->B1_XFECP)
							EndIf
							If M->B1_ST <> SB1->B1_ST
								lST := .T.
								cST := "Anterior: " + AllTrim(SB1->B1_ST) + " - Atual: " + AllTrim(M->B1_ST)
							EndIf

							//+--------------------------------------------------------+
							//| Se for um produto ST, ent�o ele atualiza os dados trib.|
							//+--------------------------------------------------------+
							// If M->B1_ST == "S"

							// 	u_AtTribPr("COD", M->B1_COD) // Utilizado para atualizar tributos (par�metros: campo, valor)

							// EndIf

							//+--------------------------------------------------------------------+
							//| Se algum dos campos referentes ao regime especial for alterado     |
							//+-------------------------------------------------------------------+
							If lMva .Or. lMvaEnt .Or. lClasfis .Or. lGrtrib .Or. lFECP .Or. lST .Or. lTes01 .Or. lTes02 .Or. lTes05
								U_PRREEmail(lMva, lMvaEnt, lClasfis, lGrtrib, lFECP, lST, lTes02, lTes05)
							EndIf

							//+--------------------------------------------------------+
							//| Se algum dos campos foram alterados envia o email      |
							//+--------------------------------------------------------+
							If lForalin .Or. lDesativ .Or. lDes02 .Or. lDes05 .Or. lBloq .Or. lTes01 .Or. lTes02 .Or. lTes05 .Or. lPreco .Or. lUm .Or. lConv .Or. lSegUm .Or. lRefFab .Or. lDesc .Or. lMva .Or. lFECP .Or. lST
								U_A010TOKEmail(lForalin, lDesativ, lDes02, lDes05, lBloq, lTes02, lTes01, lTes05, lPreco, lUm, lSegUm, lConv, lDesc, lRefFab, lMva, lFECP, lST)
							EndIf
						EndIf
					EndIf
				EndIf

				//+---------------------------------------------------------+
				//| Tratativa pra colocar uma obs ao desativar ou 	         |
				//| bloquear o Produto - Gabriel - 31/08/2026               |
				//| Exige motivo (F3) + justificativa sempre que o produto  |
				//| ESTIVER SENDO desativado (B1_DESATIV/B1_DES02/B1_DES05) |
				//| ou bloqueado (B1_MSBLQL) nesta altera��o e grava o      |
				//| hist�rico na Z65. Vale para TODO produto, independente  |
				//| do grupo ter WMS habilitado.                            |
				//+---------------------------------------------------------+
				//+--------------------------------------------------+
				//| A desativa��o acontece em tr�s campos            |
				//| independentes: Desat. Geral (B1_DESATIV),        |
				//| Desativar GV (B1_DES02) e Desat JF05 (B1_DES05). |
				//| Basta um deles passar para "S" nesta altera��o   |
				//| para exigir a justificativa de desativa��o.      |
				//+--------------------------------------------------+
				lVaiDesGer := (M->B1_DESATIV == "S") .And. (SB1->B1_DESATIV <> "S")
				lVaiDesGV  := (M->B1_DES02   == "S") .And. (SB1->B1_DES02   <> "S")
				lVaiDesJF  := (M->B1_DES05   == "S") .And. (SB1->B1_DES05   <> "S")

				lVaiDesativ := lVaiDesGer .Or. lVaiDesGV .Or. lVaiDesJF

				lVaiBloq    := (M->B1_MSBLQL == "1") .And. (SB1->B1_MSBLQL <> "1")

				lPedeJustif := lVaiDesativ .Or. lVaiBloq
				If lPedeJustif

					//+--------------------------------------------------+
					//| Tela com o(s) motivo(s) + justificativa          |
					//| Layout muda de tamanho conforme o cen�rio, para   |
					//| nunca cortar conte�do.                            |
					//+--------------------------------------------------+
					cMotivoDesativ := Space(80)
					cMotivoBloq    := Space(80)
					cJustific      := Space(200)
					lConfirmaJust  := .F.

					// Cada operacao abre uma tela propria com a consulta F3 da SX5.
					If lVaiDesativ
						cMotivoDesativ := A010SelSX5("Z6")
					EndIf
					If lVaiBloq .And. (!lVaiDesativ .Or. !Empty(cMotivoDesativ))
						cMotivoBloq := A010SelSX5("Z7")
					EndIf
					If (lVaiDesativ .And. Empty(cMotivoDesativ)) .Or. ;
							(lVaiBloq .And. Empty(cMotivoBloq))
						lRet := .F.
					Else
						//+--------------------------------------------------+
						//| Calcula a altura do di�logo ANTES de cri�-lo.     |
						//| A cl�usula FROM/TO do MSDIALOG usa uma escala     |
						//| ~2x maior que a dos controles PIXEL, por isso o   |
						//| total precisa ser multiplicado por 2.             |
						//+--------------------------------------------------+
						nAltDlg := 28				// faixa do topo (SAY do produto)

						If lVaiDesativ
							nAltDlg += 30			// r�tulo + motivo
						EndIf

						If lVaiBloq
							nAltDlg += 30			// r�tulo + motivo
						EndIf

						nAltDlg += 38				// bloco da justificativa complementar
						nAltDlg += 30				// bot�es + margem inferior

						nAltDlg := nAltDlg * 2

						cTxtAcao := ""

						If lVaiDesativ
							cTxtAcao := "DESATIVADO ("
							If lVaiDesGer
								cTxtAcao += "Geral "
							EndIf
							If lVaiDesGV
								cTxtAcao += "GV "
							EndIf
							If lVaiDesJF
								cTxtAcao += "JF05 "
							EndIf
							cTxtAcao := AllTrim(cTxtAcao) + ")"
						EndIf

						If lVaiBloq
							If !Empty(cTxtAcao)
								cTxtAcao += " e "
							EndIf
							cTxtAcao += "BLOQUEADO"
						EndIf

						DEFINE MSDIALOG oDlgJust TITLE "Justificativa - Desativa��o/Bloqueio de Produto" FROM 0,0 TO nAltDlg,700 PIXEL

						@ 10, 10 SAY "Produto: " + M->B1_COD + " ser� " + cTxtAcao SIZE 320, 10 OF oDlgJust PIXEL

						nLinAtu := 28

						If lVaiDesativ
							@ nLinAtu, 10 SAY "Motivo da Desativa��o:" SIZE 200, 8 OF oDlgJust PIXEL
							nLinAtu += 10
							@ nLinAtu, 10 SAY "Selecionado: " + AllTrim(cMotivoDesativ) SIZE 320, 12 OF oDlgJust PIXEL
							nLinAtu += 20
						EndIf

						If lVaiBloq
							@ nLinAtu, 10 SAY "Motivo do Bloqueio:" SIZE 200, 8 OF oDlgJust PIXEL
							nLinAtu += 10
							@ nLinAtu, 10 SAY "Selecionado: " + AllTrim(cMotivoBloq) SIZE 320, 12 OF oDlgJust PIXEL
							nLinAtu += 20
						EndIf

						@ nLinAtu, 10 SAY "Justificativa complementar:" SIZE 200, 8 OF oDlgJust PIXEL
						nLinAtu += 10
						@ nLinAtu, 10 GET cJustific SIZE 320, 14 OF oDlgJust PIXEL
						nLinAtu += 26

						nLinAtu += 8

						@ nLinAtu, 120 BUTTON oBtnSalvar PROMPT "Salvar" SIZE 50, 14 ACTION {|| A010ConfirmaJust(cJustific, @lConfirmaJust, oDlgJust)} OF oDlgJust PIXEL
						@ nLinAtu, 180 BUTTON oBtnVoltar PROMPT "Voltar" SIZE 50, 14 ACTION {|| lConfirmaJust := .F., oDlgJust:End()} OF oDlgJust PIXEL

						ACTIVATE MSDIALOG oDlgJust CENTERED

						//+--------------------------------------------------+
						//| Valida��o: cada status alterado exige motivo +   |
						//| justificativa complementar preenchidos.          |
						//+--------------------------------------------------+
						lErroValid := .F.

						If !lConfirmaJust
							lErroValid := .T.
						Else
							If lVaiDesativ .And. Empty(AllTrim(cMotivoDesativ))
								lErroValid := .T.
							EndIf
							If lVaiBloq .And. Empty(AllTrim(cMotivoBloq))
								lErroValid := .T.
							EndIf
							If Len(AllTrim(cJustific)) <= 10
								lErroValid := .T.
							EndIf
						EndIf

						If lErroValid
							Alert("Informe o motivo de cada status alterado e uma justificativa com pelo menos 11 caracteres.")
							lRet := .F.
						ElseIf lRet
							// Grava o historico somente se o produto passou nas demais validacoes.
							If !A010GrvZ65(lVaiDesGer, lVaiDesGV, lVaiDesJF, lVaiBloq, cMotivoDesativ, cMotivoBloq, cJustific)
								lRet := .F.
							EndIf
						EndIf

					EndIf // selecao de motivos
				EndIf // lPedeJustif
				//| Final tratativa Justificativa Desat/Bloq	   |
				//+----------------------------------------------+

			EndIf
			//| Final Altera									   |
			//+----------------------------------------------------+
		EndIf
		//| Final If cNomeEmp == "CHUA"					   |
		//+----------------------------------------------------+

		//+--------------------------------------------------------+
		//| Restaura as �reas anteriores						   |
		//+--------------------------------------------------------+
		aEval(aAreaBkp, {|area| RestArea(area)})
	End Sequence

	ErrorBlock(bError)

	If !Empty(cError)
		Alert("Erro na validacao do produto (A010TOK): " + cError)
		lRet := .F.
	EndIf

Return( lRet )
//| Final P.E. 	A010TOK								   |
//+----------------------------------------------------+




// Inclui o historico da desativacao/bloqueio na Z65.
Static Function A010GrvZ65(lDesGer, lDesGV, lDesJF, lBloq, cMotDes, cMotBlq, cJust)
	Local aArea   := GetArea()
	Local cCodZ65 := ""
	Local cUser   := RetCodUsr()
	Local lDesat  := lDesGer .Or. lDesGV .Or. lDesJF
	Local lOk     := .F.

	cCodZ65 := NextNumero("Z65", 1, "Z65_COD", .T.)
	//cCodZ65 := GetSx8Num("Z65", "Z65_COD")

	DbSelectArea("Z65")
	

	If Empty(cCodZ65)
		Alert("Nao foi possivel gerar o codigo do historico (Z65_COD).")
	ElseIf !RecLock("Z65", .T.)
		//RollBackSx8()
		Alert("Nao foi possivel incluir o historico na Z65.")
	Else
		Z65->Z65_FILIAL := xFilial("Z65")
		Z65->Z65_COD    := cCodZ65
		Z65->Z65_PROD   := M->B1_COD
		Z65->Z65_DESCPR := Left(M->B1_DESC, 60)
		Z65->Z65_USER   := Left(cUser, 10)
		Z65->Z65_NOMUSR := Left(UsrRetName(cUser), 30)
		Z65->Z65_DATA   := Date()
		Z65->Z65_HORA   := Time()
		Z65->Z65_DESAT  := IIf(lDesat,  "S", "N")
		Z65->Z65_DESGER := IIf(lDesGer, "S", "N")
		Z65->Z65_DESGV  := IIf(lDesGV,  "S", "N")
		Z65->Z65_DESJF  := IIf(lDesJF,  "S", "N")
		Z65->Z65_BLOQ   := IIf(lBloq,   "S", "N")
		Z65->Z65_MOTDES := IIf(lDesat, AllTrim(cMotDes), "")
		Z65->Z65_MOTBLQ := IIf(lBloq,  AllTrim(cMotBlq), "")
		Z65->Z65_JUST   := AllTrim(cJust)
		Z65->(MsUnlock())
		//ConfirmSx8()
		lOk := .T.
	EndIf

	RestArea(aArea)
Return lOk



// Exige pelo menos 11 caracteres antes de fechar a justificativa.
Static Function A010ConfirmaJust(cJustific, lConfirmaJust, oDlgJust)
	If Len(AllTrim(cJustific)) <= 10
		Alert('A justificativa complementar deve ter pelo menos 11 caracteres.')
		Return .F.
	EndIf
	lConfirmaJust := .T.
	oDlgJust:End()
Return .T.

// Seleciona a chave via F3 e guarda a descricao do motivo.
Static Function A010SelSX5(cTabela)
	Local aArea := GetArea()
	Local cCodigo := Space(6)
	Local cDescricao := Space(200)
	Local cMotivo := ""
	Local cTitulo := "Selecione o motivo do bloqueio"
	Local lConfirma := .F.
	Local oDlg
	Local oGet
	Local oDesc
	Local oBtnOk
	Local oBtnVoltar

	If cTabela == "Z6"
		cTitulo := "Selecione o motivo da desativa��o"
	EndIf

	DEFINE MSDIALOG oDlg TITLE cTitulo FROM 0,0 TO 250,540 PIXEL
	@ 14, 14 SAY "Dados do motivo" SIZE 245, 12 OF oDlg PIXEL
	@ 38, 14 SAY "C�digo*" SIZE 70, 10 OF oDlg PIXEL
	@ 38, 72 SAY "Motivo" SIZE 170, 10 OF oDlg PIXEL
	If cTabela == "Z6"
		@ 52, 14 MSGET oGet VAR cCodigo SIZE 45, 15 OF oDlg PIXEL F3 "Z6MOT" VALID A010MostraDesc(cTabela, cCodigo, @cDescricao, oDesc) PICTURE "@!" HASBUTTON
	Else
		@ 52, 14 MSGET oGet VAR cCodigo SIZE 45, 15 OF oDlg PIXEL F3 "Z7MOT" VALID A010MostraDesc(cTabela, cCodigo, @cDescricao, oDesc) PICTURE "@!" HASBUTTON
	EndIf
	@ 52, 72 MSGET oDesc VAR cDescricao SIZE 170, 15 OF oDlg READONLY PIXEL
	@ 78, 14 SAY "Pressione F3 ou clique na lupa para selecionar." SIZE 245, 10 OF oDlg PIXEL
	@ 100, 140 BUTTON oBtnVoltar PROMPT "Sair" SIZE 55, 14 ACTION {|| lConfirma := .F., oDlg:End()} OF oDlg PIXEL
	@ 100, 205 BUTTON oBtnOk PROMPT "Confirmar" SIZE 55, 14 ACTION {|| lConfirma := .T., oDlg:End()} OF oDlg PIXEL
	ACTIVATE MSDIALOG oDlg CENTERED

	If lConfirma
		cCodigo := AllTrim(cCodigo)
		If Empty(cCodigo)
			Alert("Selecione um motivo na consulta F3.")
		Else
			cMotivo := A010MotDesc(cTabela, cCodigo)
			If Empty(cMotivo)
				Alert("Codigo de motivo nao encontrado na tabela generica " + cTabela + ".")
			EndIf
		EndIf
	EndIf

	RestArea(aArea)
Return cMotivo

// Atualiza somente o campo visual com a descricao da chave informada.
Static Function A010MostraDesc(cTabela, cCodigo, cDescricao, oDesc)
	cDescricao := PadR(A010MotDesc(cTabela, cCodigo), Len(cDescricao))
	oDesc:Refresh()
Return .T.

// Busca a descricao na SX5 sem alterar o posicionamento das areas abertas.
Static Function A010MotDesc(cTabela, cCodigo)
	Local aArea := GetArea()
	Local aAreaSX5 := {}
	Local cDescricao := ""
	Local cChave := AllTrim(cCodigo)

	If Empty(cChave)
		Return ""
	EndIf

	If Select("SX5") == 0
		ChkFile("SX5")
	EndIf
	If Select("SX5") > 0
		DbSelectArea("SX5")
		aAreaSX5 := GetArea()
		SX5->(DbSetOrder(1))
		If SX5->(DbSeek(xFilial("SX5") + cTabela + PadR(cChave, Len(SX5->X5_CHAVE))))
			If SX5->X5_TABELA == cTabela .And. AllTrim(SX5->X5_CHAVE) == cChave
				cDescricao := AllTrim(SX5->X5_DESCRI)
			EndIf
		EndIf
		RestArea(aAreaSX5)
	EndIf

	RestArea(aArea)
Return cDescricao
//+--------------------------------------------------------+
//| Prepara e envia email                                  |
//+--------------------------------------------------------+
User Function A010TOKEmail(lForalin,lDesativ,lDes02,lDes05,lBloq, lTes02, lTes01, lTes05, lPreco, lUm, lSegUm, lConv, lDesc, lRefFab, lMva, lFECP, lST)
	cCodUser 	:= RetCodUsr() 				//Retorna o Codigo do Usuario
	cNamUser 	:= UsrRetName( cCodUser )	//Retorna o nome do usuario
	cAmbiente 	:= GetEnvServer()
	cMsg 		:= "<html> " + CRLF
	cMsg	 	+= "<head> " + CRLF
	cMsg 		+= "<p>Altera��o no Cadastro de Produtos.</p>" + CRLF
	cMsg 		+= '<table width="100%" border="1"> ' + CRLF
	cMsg 		+= "<tr>" + CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Produto </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Fora Linha </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Des.Geral </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Des.GV </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Des.JF </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Bloqueado </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">TES 01 </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">TES 02 </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">TES 05 </font></strong></div></td>' 		+ CRLF
	//Novos campos - 20/05/2024
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Unid.Medid </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Fator </font></strong></div></td>' 			+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Seg.Unid. </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Descri��o </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Ref.Fabrica </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">MVA </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">FECP </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">ST </font></strong></div></td>' 	+ CRLF

	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Pre�o Venda </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Respons�vel </font></strong></div></td>' 	+ CRLF
	cMsg 		+= "</tr>" + CRLF

	cMsg 		+= "<tr>" + CRLF
	cMsg 		+= "<td>&nbsp;" + SB1->B1_COD + " - " + SB1->B1_DESC + 	"</td>" + CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lForalin	,cForaLin,"")	+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lDesativ	,cDesativ,"")	+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lDes02	,cDes02,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lDes05	,cDes05,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lBloq		,cBloq,"")		+ 	"</td> "	+ CRLF

	cMsg 		+= "<td>&nbsp;" + IIF(lTes01	,cTes01,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lTes02	,cTes02,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lTes05	,cTes05,"")		+ 	"</td> "	+ CRLF

	// 20/05/2024 - Novos campos
	cMsg 		+= "<td>&nbsp;" + IIF(lUm	,cUm,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lConv	,cConv,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lSegUm	,cSegUm,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lDesc	,cDesc,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lRefFab,cRefFab,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lMva	,cMva,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lFECP	,cFECP,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lST		,cST,"")			+ 	"</td> "	+ CRLF

	cMsg 		+= "<td>&nbsp;" + IIF(lPreco	,cPreco,"")		+ 	"</td> "	+ CRLF

	cMsg 		+= "<td>&nbsp;" + cNamUser + " - AMBIENTE: " + cAmbiente	+ 	"</td>" 	+ CRLF
	cMsg 		+= "</tr>" + CRLF
	cMsg 		+= "</table>" + CRLF

	//+----------------------------------------------------+
	//| Finalizacao da mensagem							   |
	//+----------------------------------------------------+
	//cFimMsg := "</table>" + CRLF
	cMsg 		+= '<hr style="-moz-box-sizing: content-box;box-sizing: content-box;height: 0;border-top: 1px solid #FF4000"/>' + CRLF
	cMsg 		+= '<p>&nbsp;</p>'
	cMsg 		+= "<p><b><u>Esse e-mail � enviado pelo sistema de forma autom�tica, favor n�o responder.</u></b></p>" + CRLF
	cMsg 		+= '<p>&nbsp;</p>'
	cMsg 		+= "<p>Atenciosamente,</p>" + CRLF
	cMsg 		+= "<p><strong>Chua Distribuidora SA</strong></p>" + CRLF
	cMsg 		+= '<hr style="-moz-box-sizing: content-box;box-sizing: content-box;height: 0;border-top: 1px solid #009241"/>' + CRLF
	cMsg	 	+= "</html>" + CRLF

	u_EnvMail1(CMAILTO,;										//_cPara //
	CEMAILCC,;															//_cCc
	EMAILBCC,;													//_cBCC
	"WorkFlow - Altera��o Cadastro de Produto - " + SB1->B1_COD + " - " + SB1->B1_DESC,; //_cTitulo - apagar o email do cliente depois
	,;															//_aAnexo
	cMsg,;														//_cMsg
	.T.,;
		"locaweb")

Return ( Nil )

User Function PRREEmail(lMva, lMvaEnt, lClasfis, lGrtrib, lFECP, lST, lTes02, lTes05)
	cCodUser 	:= RetCodUsr() 				//Retorna o Codigo do Usuario
	cNamUser 	:= UsrRetName( cCodUser )	//Retorna o nome do usuario
	cAmbiente 	:= GetEnvServer()
	cMsg 		:= "<html> " + CRLF
	cMsg	 	+= "<head> " + CRLF
	cMsg 		+= "<p>Altera��o no Cadastro de Produtos Que Podem Impactar o Regime Especial Foram Realizadas</p>" + CRLF
	cMsg 		+= '<table width="100%" border="1"> ' + CRLF
	cMsg 		+= "<tr>" + CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Produto </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">TES 02 </font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">TES 05 </font></strong></div></td>' 		+ CRLF
	//Novos campos - 20/05/2024
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Grupo de Tributa��o</font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">CST</font></strong></div></td>' 		+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">MVA Entrada</font></strong></div></td>' 	+ CRLF

	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">MVA Sa�da </font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">FECP?</font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">ST?</font></strong></div></td>' 	+ CRLF
	cMsg 		+= '<td bgcolor="#FF4000"><div align="center"><strong><font color="#FFFFFF">Respons�vel </font></strong></div></td>' 	+ CRLF
	cMsg 		+= "</tr>" + CRLF

	cMsg 		+= "<tr>" + CRLF
	cMsg 		+= "<td>&nbsp;" + SB1->B1_COD + " - " + SB1->B1_DESC + 	"</td>" + CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lTes02	,cTes02,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lTes05	,cTes05,"")		+ 	"</td> "	+ CRLF

	// 20/05/2024 - Novos campos
	cMsg 		+= "<td>&nbsp;" + IIF(lGrtrib	,cGrtrib,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lClasfis	,cClasfis,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lMvaEnt,cMvaEnt,"")		+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lMva	,cMva,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lFECP	,cFECP,"")			+ 	"</td> "	+ CRLF
	cMsg 		+= "<td>&nbsp;" + IIF(lST		,cST,"")			+ 	"</td> "	+ CRLF

	cMsg 		+= "<td>&nbsp;" + cNamUser + " - AMBIENTE: " + cAmbiente	+ 	"</td>" 	+ CRLF
	cMsg 		+= "</tr>" + CRLF
	cMsg 		+= "</table>" + CRLF

	//+----------------------------------------------------+
	//| Finalizacao da mensagem							   |
	//+----------------------------------------------------+
	//cFimMsg := "</table>" + CRLF
	cMsg 		+= '<hr style="-moz-box-sizing: content-box;box-sizing: content-box;height: 0;border-top: 1px solid #FF4000"/>' + CRLF
	cMsg 		+= '<p>&nbsp;</p>'
	cMsg 		+= "<p><b><u>Esse e-mail � enviado pelo sistema de forma autom�tica, favor n�o responder.</u></b></p>" + CRLF
	cMsg 		+= '<p>&nbsp;</p>'
	cMsg 		+= "<p>Atenciosamente,</p>" + CRLF
	cMsg 		+= "<p><strong>Chua Distribuidora SA</strong></p>" + CRLF
	cMsg 		+= '<hr style="-moz-box-sizing: content-box;box-sizing: content-box;height: 0;border-top: 1px solid #009241"/>' + CRLF
	cMsg	 	+= "</html>" + CRLF

	u_EnvMail1(CMAILTO,;										//_cPara //
	CEMAILCC,;															//_cCc
	EMAILBCC,;													//_cBCC
	"WorkFlow - Altera��o Cadastro de Produto com impacto no Regime Especial - " + SB1->B1_COD + " - " + SB1->B1_DESC,; //_cTitulo - apagar o email do cliente depois
	,;															//_aAnexo
	cMsg,;														//_cMsg
	.T.,;
		"locaweb")

Return ( Nil )


/*

Local cRegTXT := ""

dbSelectArea("SB1")
dbGoTop()
dbSetOrder(1)


If M->B1_GRUPO == "1006"

	dbSelectArea("SX3")   Max
	dbGoTop()
	dbSeek("SB1")

	While !Eof() .And. SX3->X3_ARQUIVO == "SB1"

		dbSelectArea("SB1")

		// Verifica se existe o campo no Banco
		If Type("M->"+&("SX3->X3_CAMPO"))<>"U"

			Do Case
			 	Case (SX3->X3_TIPO == "N")
//					cRegTXT += Right ( Transform(&("M->"+&("SX3->X3_CAMPO")),Trim(SX3->X3_PICTURE))    , SX3->X3_TAMANHO )
					cRegTXT += Str  (   &("M->"+&("SX3->X3_CAMPO"))   , SX3->X3_TAMANHO, SX3->X3_DECIMAL  )
				Case (SX3->X3_TIPO == "D")
					cRegTXT += DToC(&("M->"+&("SX3->X3_CAMPO")))
				OtherWise
					cRegTXT += &("M->"+&("SX3->X3_CAMPO"))
			EndCase

		EndIf

	   	dbSelectArea("SX3")
	   	dbSkip()
	End
    bbbb := 0
	If INCLUI
		If !dbSeek(xFilial("SB1")+SB1->B1_COD)
			ConfirmSX8()
		EndIf
		cArquiv := "I" + Substr(DtoC(Date()),4,2) + Left(DtoC(Date()),2)+Left(Time(),2)+Substr(Time(),4,2)+Substr(Time(),7,2)+"SB1"
		cArquiv += ".TXT"
	ElseIf ALTERA
		cArquiv := "A" + Substr(DtoC(Date()),4,2) + Left(DtoC(Date()),2)+Left(Time(),2)+Substr(Time(),4,2)+Substr(Time(),7,2)+"SB1"
		cArquiv += ".TXT"
	ElseIf EXCLUI
		cArquiv := "E" + Substr(DtoC(Date()),4,2) + Left(DtoC(Date()),2)+Left(Time(),2)+Substr(Time(),4,2)+Substr(Time(),7,2)+"SB1"
		cArquiv += ".TXT"
	EndIf

	nHdlArq := fCreate("\Integracao\Chua\Importa\Produto\"+cArquiv,0)
	fWrite(nHdlArq,cRegTXT)
	fClose(nHdlArq)

EndIf
*/
