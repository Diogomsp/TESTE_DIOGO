#INCLUDE 'PROTHEUS.CH'
#DEFINE SIMPLES Char( 39 )
#DEFINE DUPLAS  Char( 34 )


User Function COMPADIC()

	Local   aSay     := {}
	Local   aButton  := {}
	Local   aMarcadas:= {}
	Local   cTitulo  := 'ATUALIZAÇÃO DE DICIONÁRIOS E TABELAS'
	Local   cDesc1   := 'Esta rotina tem como função fazer  a atualização  dos dicionários do Sistema ( SX?/SIX )'
	Local   cDesc2   := 'Este processo deve ser executado em modo EXCLUSIVO, ou seja não podem haver outros'
	Local   cDesc3   := 'usuários  ou  jobs utilizando  o sistema.  É extremamente recomendavél  que  se  faça um'
	Local   cDesc4   := 'BACKUP  dos DICIONÁRIOS  e da  BASE DE DADOS antes desta atualização, para que caso '
	Local   cDesc5   := 'ocorra eventuais falhas, esse backup seja ser restaurado.'
	Local   cDesc6   := ''
	Local   cDesc7   := ''
	Local   lOk      := .F.

	Private oMainWnd  := NIL
	Private oProcess  := NIL

	#IFDEF TOP
	TCInternal( 5, '*OFF' ) // Desliga Refresh no Lock do Top
	#ENDIF

	__cInterNet := NIL
	__lPYME     := .F.

	Set Dele On

	// Mensagens de Tela Inicial
	aAdd( aSay, cDesc1 )
	aAdd( aSay, cDesc2 )
	aAdd( aSay, cDesc3 )
	aAdd( aSay, cDesc4 )
	aAdd( aSay, cDesc5 )

	// Botoes Tela Inicial
	aAdd(  aButton, {  1, .T., { || lOk := .T., FechaBatch() } } )
	aAdd(  aButton, {  2, .T., { || lOk := .F., FechaBatch() } } )

	FormBatch(  cTitulo,  aSay,  aButton )

	If lOk
		aMarcadas := EscEmpresa()

		If !Empty( aMarcadas )
			If  ApMsgNoYes( 'Confirma a atualização dos dicionários ?', cTitulo )
				oProcess := MsNewProcess():New( { | lEnd | lOk := FSTProc( @lEnd, aMarcadas ) }, 'Atualizando', 'Aguarde, atualizando ...', .F. )
				oProcess:Activate()

				If lOk
					Final( 'Atualização Concluída.' )
				Else
					Final( 'Atualização não Realizada.' )
				EndIf

			Else
				Final( 'Atualização não Realizada.' )

			EndIf

		Else
			Final( 'Atualização não Realizada.' )

		EndIf

	EndIf

Return NIL




Static Function FSTProc( lEnd, aMarcadas )
	Local   cTexto    := ''
	Local   cFile     := ''
	Local   cFileLog  := ''
	Local   cAux      := ''
	Local   cMask     := 'Arquivos Texto (*.TXT)|*.txt|'
	Local   nRecno    := 0
	Local   nI        := 0
	Local   nX        := 0
	Local   nPos      := 0
	Local   aRecnoSM0 := {}
	Local   aInfo     := {}
	Local   lOpen     := .F.
	Local   lRet      := .T.
	Local   oDlg      := NIL
	Local   oMemo     := NIL
	Local   oFont     := NIL

	Private aArqUpd   := {}

	If ( lOpen := MyOpenSm0Ex() )

		dbSelectArea( 'SM0' )
		dbGoTop()

		While !SM0->( EOF() )
			// So adiciona no aRecnoSM0 se a empresa for diferente
			If aScan( aRecnoSM0, { |x| x[2] == SM0->M0_CODIGO } ) == 0 ;
			.AND. aScan( aMarcadas, { |x| x[1] == SM0->M0_CODIGO } ) > 0
				aAdd( aRecnoSM0, { Recno(), SM0->M0_CODIGO } )
			EndIf
			SM0->( dbSkip() )
		End

		If lOpen

			For nI := 1 To Len( aRecnoSM0 )

				SM0->( dbGoTo( aRecnoSM0[nI][1] ) )

				RpcSetType( 2 )
				RpcSetEnv( SM0->M0_CODIGO, SM0->M0_CODFIL )

				lMsFinalAuto := .F.

				cTexto += Replicate( '-', 128 ) + CRLF
				cTexto += 'Empresa : ' + SM0->M0_CODIGO + '/' + SM0->M0_NOME + CRLF + CRLF

				oProcess:SetRegua1( 8 )

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX2         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de arquivos - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSX2()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX3         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				cTexto += FSAtuSX3()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SIX         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de índices - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...' )
				cTexto += FSAtuSIX()

				oProcess:IncRegua1( 'Dicionário de dados - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...' )
				oProcess:IncRegua2( 'Atualizando campos/índices')

				oProcess:SetRegua2( len(aArqUpd) )

				// Alteracao fisica dos arquivos
				__SetX31Mode( .F. )

				For nX := 1 To Len( aArqUpd )

					oProcess:IncRegua2( 'Atualizando ' + aArqUpd[nx])

					If Select( aArqUpd[nx] ) > 0
						dbSelectArea( aArqUpd[nx] )
						dbCloseArea()
					EndIf

					X31UpdTable( aArqUpd[nx] )

					If __GetX31Error()
						Alert( __GetX31Trace() )
						ApMsgStop( 'Ocorreu um erro desconhecido durante a atualização da tabela : ' + aArqUpd[nx] + '. Verifique a integridade do dicionário e da tabela.', 'ATENÇÃO' )
						cTexto += 'Ocorreu um erro desconhecido durante a atualização da estrutura da tabela : ' + aArqUpd[nx] + CRLF
					else
						dbSelectArea(aArqUpd[nx])
						(aArqUpd[nx])->(dbCloseArea())
					EndIf

				Next nX

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX1         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de parâmetros - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSX1()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX6         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de parâmetros - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSX6()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX7         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de gatilhos - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSX7()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SXA         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de pastas - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSXA()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SXB         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de consultas padrão - ' + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...'  )
				cTexto += FSAtuSXB()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX5         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de tabelas sistema - '  + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...' )
				cTexto += FSAtuSX5()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza o dicionário SX9         ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Dicionário de relacionamentos - '  + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...' )
				cTexto += FSAtuSX9()

				//ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿
				//³Atualiza os helps                 ³
				//ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ
				oProcess:IncRegua1( 'Helps de Campo - '  + SM0->M0_CODIGO + ' ' + SM0->M0_NOME + ' ...' )
				cTexto += FSAtuHlp()

				RpcClearEnv()

				If !( lOpen := MyOpenSm0Ex() )
					Exit
				EndIf

			Next nI

			If lOpen

				cAux += Replicate( '-', 128 ) + CRLF
				cAux += Replicate( ' ', 128 ) + CRLF
				cAux += 'LOG DA ATUALIZACAO DOS DICIONÁRIOS' + CRLF
				cAux += Replicate( ' ', 128 ) + CRLF
				cAux += Replicate( '-', 128 ) + CRLF
				cAux += CRLF
				cAux += ' Dados Ambiente'        + CRLF
				cAux += ' --------------------'  + CRLF
				cAux += ' Empresa / Filial...: ' + cEmpAnt + '/' + cFilAnt  + CRLF
				cAux += ' Nome Empresa.......: ' + Capital( AllTrim( GetAdvFVal( 'SM0', 'M0_NOMECOM', cEmpAnt + cFilAnt, 1, '' ) ) ) + CRLF
				cAux += ' Nome Filial........: ' + Capital( AllTrim( GetAdvFVal( 'SM0', 'M0_FILIAL' , cEmpAnt + cFilAnt, 1, '' ) ) ) + CRLF
				cAux += ' DataBase...........: ' + DtoC( dDataBase )  + CRLF
				cAux += ' Data / Hora........: ' + DtoC( Date() ) + ' / ' + Time()  + CRLF
				cAux += ' Environment........: ' + GetEnvServer()  + CRLF
				cAux += ' StartPath..........: ' + GetSrvProfString( 'StartPath', '' )  + CRLF
				cAux += ' RootPath...........: ' + GetSrvProfString( 'RootPath', '' )  + CRLF
				cAux += ' Versao.............: ' + GetVersao(.T.)  + CRLF
				//cAux += ' Modulo.............: ' + GetModuleFileName()  + CRLF
				cAux += ' Usuario Microsiga..: ' + __cUserId + ' ' +  cUserName + CRLF
				cAux += ' Computer Name......: ' + GetComputerName()  + CRLF

				aInfo   := GetUserInfo()
				If ( nPos    := aScan( aInfo,{ |x,y| x[3] == ThreadId() } ) ) > 0
					cAux += ' '  + CRLF
					cAux += ' Dados Thread' + CRLF
					cAux += ' --------------------'  + CRLF
					cAux += ' Usuario da Rede....: ' + aInfo[nPos][1] + CRLF
					cAux += ' Estacao............: ' + aInfo[nPos][2] + CRLF
					cAux += ' Programa Inicial...: ' + aInfo[nPos][5] + CRLF
					cAux += ' Environment........: ' + aInfo[nPos][6] + CRLF
					cAux += ' Conexao............: ' + AllTrim( StrTran( StrTran( aInfo[nPos][7], Chr( 13 ), '' ), Chr( 10 ), '' ) )  + CRLF
				EndIf
				cAux += Replicate( '-', 128 ) + CRLF
				cAux += CRLF

				cTexto := cAux + cTexto

				cFileLog := MemoWrite( CriaTrab( , .F. ) + '.log', cTexto )

				Define Font oFont Name 'Mono AS' Size 5, 12

				Define MsDialog oDlg Title 'Atualizacao concluida.' From 3, 0 to 340, 417 Pixel

				@ 5, 5 Get oMemo Var cTexto Memo Size 200, 145 Of oDlg Pixel
				oMemo:bRClicked := { || AllwaysTrue() }
				oMemo:oFont     := oFont

				Define SButton From 153, 175 Type  1 Action oDlg:End() Enable Of oDlg Pixel // Apaga
				Define SButton From 153, 145 Type 13 Action ( cFile := cGetFile( cMask, '' ), If( cFile == '', .T., ;
				MemoWrite( cFile, cTexto ) ) ) Enable Of oDlg Pixel // Salva e Apaga //'Salvar Como...'

				Activate MsDialog oDlg Center

			EndIf

		EndIf

	Else

		lRet := .F.

	EndIf

Return lRet








Static Function FSAtuSX2()
	Local aSX2      := {}
	Local aSX2Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SX2' + CRLF + CRLF
	Local cPath     := ''
	Local cEmpr     := ''

	aEstrut := { 'X2_CHAVE', 'X2_PATH'   , 'X2_ARQUIVO', 'X2_NOME', 'X2_NOMESPA', 'X2_NOMEENG', 'X2_DELET'  , ;
	'X2_MODO' , 'X2_MODOUN' , 'X2_MODOEMP', 'X2_TTS' , 'X2_ROTINA' , 'X2_PYME'   , 'X2_UNICO'  , 'X2_MODULO' }

	dbSelectArea( 'SX2' )
	SX2->( dbSetOrder( 1 ) )
	SX2->( dbGoTop() )
	cPath := SX2->X2_PATH
	cEmpr := Substr( SX2->X2_ARQUIVO, 4 )

	
	if File('sx2_virada.dtc')

		DbUseArea( .T., "CTREECDX" , 'sx2_virada.dtc', 'VIRASX2', .F., .F. )

		DbSelectArea("VIRASX2")
		DbGotop()
		While !Eof()

			aaddUpd(VIRASX2->X2_CHAVE)

			aSX2Cpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSX2Cpo,VIRASX2->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSX2,aSX2Cpo)

			DbSelectArea("VIRASX2")
			DbSkip()
		End

		DbCloseArea()  

		oProcess:SetRegua2( Len( aSX2 ) )

		dbSelectArea( 'SX2' )
		dbSetOrder( 1 )

		For nI := 1 To Len( aSX2 )

			If !SX2->( dbSeek( aSX2[nI][1] ) )

				If !( aSX2[nI][1] $ cAlias )
					cAlias += aSX2[nI][1] + '/'
					cTexto += 'Foi incluída a tabela ' + aSX2[nI][1] + CRLF
				EndIf

				RecLock( 'SX2', .T. )
				For nJ := 1 To Len( aSX2[nI] )
					If FieldPos( aEstrut[nJ] ) > 0
						If AllTrim( aEstrut[nJ] ) == 'X2_ARQUIVO'
							FieldPut( FieldPos( aEstrut[nJ] ), SubStr( aSX2[nI][nJ], 1, 3 ) + cEmpAnt +  '0' )
						Else
							FieldPut( FieldPos( aEstrut[nJ] ), aSX2[nI][nJ] )
						EndIf
					EndIf
				Next nJ
				dbCommit()
				MsUnLock()

				oProcess:IncRegua2( 'Atualizando Arquivos (SX2)...')

			EndIf

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SX2' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF

	endif

Return cTexto







Static Function FSAtuSX3()
	Local aSX3      := {}
	Local aSX3Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local nTamSeek  := Len( SX3->X3_CAMPO )
	Local cAlias    := ''
	Local cAliasAtu := ''
	Local cSeqAtu   := ''
	Local nSeqAtu   := 0
	Local _x        := 0
	Local cTexto    := 'Inicio da Atualizacao do SX3' + CRLF + CRLF

	aEstrut := { 'X3_ARQUIVO', 'X3_ORDEM'  , 'X3_CAMPO'  , 'X3_TIPO'   , 'X3_TAMANHO', 'X3_DECIMAL', ;
	'X3_TITULO' , 'X3_TITSPA' , 'X3_TITENG' , 'X3_DESCRIC', 'X3_DESCSPA', 'X3_DESCENG', ;
	'X3_PICTURE', 'X3_VALID'  , 'X3_USADO'  , 'X3_RELACAO', 'X3_F3'     , 'X3_NIVEL'  , ;
	'X3_RESERV' , 'X3_CHECK'  , 'X3_TRIGGER', 'X3_PROPRI' , 'X3_BROWSE' , 'X3_VISUAL' , ;
	'X3_CONTEXT', 'X3_OBRIGAT', 'X3_VLDUSER', 'X3_CBOX'   , 'X3_CBOXSPA', 'X3_CBOXENG', ;
	'X3_PICTVAR', 'X3_WHEN'   , 'X3_INIBRW' , 'X3_GRPSXG' , 'X3_FOLDER' , 'X3_PYME'   }

	if File('sx3_virada.dtc')
		//
		DbUseArea( .T., "CTREECDX", 'sx3_virada.dtc', 'VIRASX3', .F., .F. )

		DbSelectArea("VIRASX3")
		DbGotop()
		While !Eof()

			aaddUpd(VIRASX3->X3_ARQUIVO)

			aSX3Cpo := {}

			For _x := 1 To Len(aEstrut)                            
				aadd(aSX3Cpo,VIRASX3->( FieldGet(FieldPos(aEstrut[_x]))) )
			Next _x

			aadd(aSX3,aSX3Cpo)

			DbSelectArea("VIRASX3")
			DbSkip()
		End

		DbCloseArea()  
		DbSelectArea("SX3")

		aSort( aSX3,,, { |x,y| x[1]+x[2]+x[3] < y[1]+y[2]+y[3] } )

		oProcess:SetRegua2( Len( aSX3 ) )

		dbSelectArea( 'SX3' )
		dbSetOrder( 2 )
		cAliasAtu := ''

		For nI := 1 To Len( aSX3 )

			SX3->( dbSetOrder( 2 ) )

			If !SX3->( dbSeek( PadR( aSX3[nI][3], nTamSeek ) ) )

				If !( aSX3[nI][1] $ cAlias )
					cAlias += aSX3[nI][1] + '/'
					//aAdd( aArqUpd, aSX3[nI][1] )
				EndIf

				//
				// Busca ultima ocorrencia do alias
				//
				If ( aSX3[nI][1] <> cAliasAtu )
					cSeqAtu   := '00'
					cAliasAtu := aSX3[nI][1]

					dbSetOrder( 1 )
					SX3->( dbSeek( cAliasAtu + 'ZZ', .T. ) )
					dbSkip( -1 )

					If ( SX3->X3_ARQUIVO == cAliasAtu )
						cSeqAtu := SX3->X3_ORDEM
					EndIf

					nSeqAtu := Val( RetAsc( cSeqAtu, 3, .F. ) )
				EndIf

				nSeqAtu++
				cSeqAtu := RetAsc( Str( nSeqAtu ), 2, .T. )

				RecLock( 'SX3', .T. )
				For nJ := 1 To Len( aSX3[nI] )
					If     nJ == 2    // Ordem
						FieldPut( FieldPos( aEstrut[nJ] ), cSeqAtu )

					ElseIf FieldPos( aEstrut[nJ] ) > 0
						FieldPut( FieldPos( aEstrut[nJ] ), aSX3[nI][nJ] )

					EndIf
				Next nJ

				dbCommit()
				MsUnLock()

				cTexto += 'Criado o campo ' + aSX3[nI][3] + CRLF

			Else

				//
				// Verifica todos os campos
				//
				For nJ := 1 To Len( aSX3[nI] )

					//
					// Se o campo estiver diferente da estrutura
					//
					If aEstrut[nJ] == SX3->( FieldName( nJ ) ) .AND. ;
					PadR( StrTran( AllToChar( SX3->( FieldGet( nJ ) ) ), ' ', '' ), 250 ) <> ;
					PadR( StrTran( AllToChar( aSX3[nI][nJ] )           , ' ', '' ), 250 ) .AND. ;
					AllTrim( SX3->( FieldName( nJ ) ) ) <> 'X3_ORDEM'

						//If ApMsgNoYes( 'O campo ' + aSX3[nI][3] + ' está com o ' + SX3->( FieldName( nJ ) ) + ;
						//' com o conteúdo' + CRLF + ;
						//'[' + RTrim( AllToChar( SX3->( FieldGet( nJ ) ) ) ) + ']' + CRLF + ;
						//'que será substituido pelo NOVO conteúdo' + CRLF + ;
						//'[' + RTrim( AllToChar( aSX3[nI][nJ] ) ) + ']' + CRLF + ;
						//'Deseja substituir ? ', 'Confirmar substituição de conteúdo' )

							cTexto += 'Alterado o campo ' + aSX3[nI][3] + CRLF
							cTexto += '   ' + PadR( SX3->( FieldName( nJ ) ), 10 ) + ' de [' + AllToChar( SX3->( FieldGet( nJ ) ) ) + ']' + CRLF
							cTexto += '            para [' + AllToChar( aSX3[nI][nJ] )          + ']' + CRLF + CRLF

							RecLock( 'SX3', .F. )
							FieldPut( FieldPos( aEstrut[nJ] ), aSX3[nI][nJ] )
							dbCommit()
							MsUnLock()

							If !( aSX3[nI][1] $ cAlias )
								cAlias += aSX3[nI][1] + '/'
								//aAdd( aArqUpd, aSX3[nI][1] )
							EndIf

						//EndIf

					EndIf

				Next

			EndIf

			oProcess:IncRegua2( 'Atualizando Campos de Tabelas (SX3)...' )

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SX3' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF

	endif
Return cTexto








Static Function FSAtuSIX()
	Local cTexto    := 'Inicio da Atualizacao do SIX' + CRLF + CRLF
	Local cAlias    := ''
	Local lDelInd   := .F.
	Local aSIX      := {}
	Local aSIXCpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local lAlt      := .F.
	Local cSeq      := ''

	aEstrut := { 'INDICE' , 'ORDEM' , 'CHAVE', 'DESCRICAO', 'DESCSPA'  , ;
	'DESCENG', 'PROPRI', 'F3'   , 'NICKNAME' , 'SHOWPESQ' }

	
	if File('six_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'six_virada.dtc', 'VIRASIX', .F., .F. )

		DbSelectArea("VIRASIX")
		DbGotop()
		While !Eof()

			aaddUpd(AllTrim(VIRASIX->INDICE))

			aSIXCpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSIXCpo,VIRASIX->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSIX,aSIXCpo)

			DbSelectArea("VIRASIX")
			DbSkip()
		End

		DbCloseArea()  
		dbSelectArea( 'SIX' )

		oProcess:SetRegua2( Len( aSIX ) )

		dbSelectArea( 'SIX' )
		SIX->( dbSetOrder( 1 ) )

		For nI := 1 To Len( aSIX )
			lAlt := .F.

			If !SIX->( dbSeek( aSIX[nI][1] + aSIX[nI][2] ) )
				RecLock( 'SIX', .T. )
				lDelInd := .F.
				cTexto += 'Índice criado ' + aSIX[nI][1] + '/' + aSIX[nI][2] + ' - ' + aSIX[nI][3] + CRLF
			Else
				lDelInd := .F.
				If Upper(AllTrim(SIX->CHAVE)) <> Upper(AllTrim(aSIX[nI][3]))
					If Empty(aSIX[nI][9]) //Nickname em branco
						lDelInd := .T.
						RecLock( 'SIX', .F. )
					Else
						//Pega a proxima sequencia de indice
						SIX->(dbGoTop())
						SIX->( dbSeek( aSIX[nI][1] ) )
						While SIX->(!Eof()) .And. SIX->INDICE == aSIX[nI][1]
							cSeq := SIX->ORDEM
							SIX->(dbSkip())
						EndDo
						cSeq := Soma1(cSeq)
						lDelInd := .F.

						aSIX[nI][2] := cSeq

						RecLock( 'SIX', .T. )
						lDelInd := .F.
						cTexto += 'Índice criado ' + aSIX[nI][1] + '/' + aSIX[nI][2] + ' - ' + aSIX[nI][3] + CRLF
					EndIf
				Else
					lDelInd := .T.
					cTexto += 'Índice alterado ' + aSIX[nI][1] + '/' + aSIX[nI][2] + ' - ' + aSIX[nI][3] + CRLF
					lAlt := .T.
				EndIf
			EndIf

			If StrTran( Upper( AllTrim( CHAVE )       ), ' ', '') <> ;
			StrTran( Upper( AllTrim( aSIX[nI][3] ) ), ' ', '' )
				//aAdd( aArqUpd, aSIX[nI][1] )

				If !( aSIX[nI][1] $ cAlias )
					cAlias += aSIX[nI][1] + '/'
				EndIf

				For nJ := 1 To Len( aSIX[nI] )
					If FieldPos( aEstrut[nJ] ) > 0
						FieldPut( FieldPos( aEstrut[nJ] ), aSIX[nI][nJ] )
					EndIf
				Next nJ

				dbCommit()
				MsUnLock()

				If lDelInd
					TcInternal( 60, RetSqlName( aSIX[nI][1] ) + '|' + RetSqlName( aSIX[nI][1] ) + aSIX[nI][2] ) // Exclui sem precisar baixar o TOP
				EndIf

			EndIf

			oProcess:IncRegua2( 'Atualizando índices...' )

		Next nI

		cTexto += CRLF + CRLF + 'Final da Atualizacao do SIX' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto







Static Function FSAtuSX6()
	Local aSX6      := {}
	Local aSX6Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SX6' + CRLF + CRLF
	Local lReclock  := .T.
	Local lContinua := .T.

	aEstrut := { 'X6_FIL'    , 'X6_VAR'  , 'X6_TIPO'   , 'X6_DESCRIC', 'X6_DSCSPA' , 'X6_DSCENG' , 'X6_DESC1'  , 'X6_DSCSPA1',;
	'X6_DSCENG1', 'X6_DESC2', 'X6_DSCSPA2', 'X6_DSCENG2', 'X6_CONTEUD', 'X6_CONTSPA', 'X6_CONTENG', 'X6_PROPRI' }


	if File('sx6_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'sx6_virada.dtc', 'VIRASX6', .F., .F. )

		DbSelectArea("VIRASX6")
		DbGotop()
		While !Eof()

			aSX6Cpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSX6Cpo,VIRASX6->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSX6,aSX6Cpo)

			DbSelectArea("VIRASX6")
			DbSkip()
		End

		DbCloseArea()  

		oProcess:SetRegua2( Len( aSX6 ) )

		dbSelectArea( 'SX6' )
		dbSetOrder( 1 )

		For nI := 1 To Len( aSX6 )
			lContinua := .T.
			lReclock  := .T.

			If SX6->( dbSeek( PadR( aSX6[nI][1], 2 ) + PadR( aSX6[nI][2], Len( SX6->X6_VAR) ) ) )
				lReclock  := .F.

				//If StrTran( SX6->X6_CONTEUD, ' ', '' ) <> StrTran( aSX6[nI][13], ' ', '' )
				//	lContinua :=  ApMsgNoYes( 'O parâmetro ' + aSX6[nI][2] + ' está com o conteúdo' + CRLF + ;
				//	'[' + RTrim( StrTran( SX6->X6_CONTEUD, ' ', '' ) ) + ']' + CRLF + ;
				//	', que é será substituido pelo NOVO conteúdo ' + CRLF + ;
				//	'[' + RTrim( StrTran( aSX6[nI][13]   , ' ', ''  ) ) + ']' + CRLF + ;
				//	'Deseja substituir ? ', 'Confirmar substituição de conteúdo' )

					If lContinua
						cTexto += 'Foi alterado o parâmetro ' + aSX6[nI][1] + aSX6[nI][2] + ' de [' + ;
						AllTrim( SX6->X6_CONTEUD ) + ']' + ' para [' + AllTrim( aSX6[nI][13] ) + ']' + CRLF
					EndIf

				//Else
				//	lContinua := .F.
				//EndIf

			Else
				cTexto += 'Foi incluído o parâmetro ' + aSX6[nI][1] + aSX6[nI][2] + ' Conteúdo [' + AllTrim( aSX6[nI][13] ) + ']'+ CRLF

			EndIf

			If lContinua

				If !( aSX6[nI][1] $ cAlias )
					cAlias += aSX6[nI][1] + '/'
				EndIf

				RecLock( 'SX6', lReclock )
				For nJ := 1 To Len( aSX6[nI] )
					If FieldPos( aEstrut[nJ] ) > 0
						FieldPut( FieldPos( aEstrut[nJ] ), aSX6[nI][nJ] )
					EndIf
				Next nJ
				dbCommit()
				MsUnLock()

				oProcess:IncRegua2( 'Atualizando Arquivos (SX6)...')

			EndIf

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SX6' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto







Static Function FSAtuSX7()
	Local aSX7      := {}
	Local aSX7Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local nTamSeek  := Len( SX7->X7_CAMPO )
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SX7' + CRLF + CRLF

	aEstrut := { 'X7_CAMPO', 'X7_SEQUENC', 'X7_REGRA', 'X7_CDOMIN', 'X7_TIPO', 'X7_SEEK', ;
	'X7_ALIAS', 'X7_ORDEM'  , 'X7_CHAVE', 'X7_PROPRI', 'X7_CONDIC' }

	if File('sx7_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'sx7_virada.dtc', 'VIRASX7', .F., .F. )

		DbSelectArea("VIRASX7")
		DbGotop()
		While !Eof()

			aSX7Cpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSX7Cpo,VIRASX7->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSX7,aSX7Cpo)

			DbSelectArea("VIRASX7")
			DbSkip()
		End

		DbCloseArea()  

		oProcess:SetRegua2( Len( aSX7 ) )

		dbSelectArea( 'SX7' )
		dbSetOrder( 1 )

		For nI := 1 To Len( aSX7 )

			If !SX7->( dbSeek( PadR( aSX7[nI][1], nTamSeek ) + aSX7[nI][2] ) )

				If !( aSX7[nI][1] $ cAlias )
					cAlias += aSX7[nI][1] + '/'
					cTexto += 'Foi incluído o gatilho ' + aSX7[nI][1] + '/' + aSX7[nI][2] + CRLF
				EndIf

				RecLock( 'SX7', .T. )
			Else

				If !( aSX7[nI][1] $ cAlias )
					cAlias += aSX7[nI][1] + '/'
					cTexto += 'Foi alterado o gatilho ' + aSX7[nI][1] + '/' + aSX7[nI][2] + CRLF
				EndIf

				RecLock( 'SX7', .F. )
			EndIf

			For nJ := 1 To Len( aSX7[nI] )
				If FieldPos( aEstrut[nJ] ) > 0
					FieldPut( FieldPos( aEstrut[nJ] ), aSX7[nI][nJ] )
				EndIf
			Next nJ

			dbCommit()
			MsUnLock()


			//Atualiza o X3_TRIGGER
			dbSelectArea('SX3')
			SX3->(dbSetOrder(2))
			If SX3->(dbSeek(aSX7[nI][1]))
				SX3->(RecLock('SX3',.F.))
				SX3->X3_TRIGGER := 'S'
				SX3->(MsUnlock())
			EndIf

			oProcess:IncRegua2( 'Atualizando Arquivos (SX7)...')

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SX7' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto








Static Function FSAtuSXA()
	Local aSXA      := {}
	Local aSXACpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SXA' + CRLF + CRLF

	aEstrut := { 'XA_ALIAS', 'XA_ORDEM', 'XA_DESCRIC', 'XA_DESCSPA', 'XA_DESCENG', 'XA_PROPRI' }

	if File('sxa_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'sxa_virada.dtc', 'VIRASXA', .F., .F. )

		DbSelectArea("VIRASXA")
		DbGotop()
		While !Eof()

			aSXACpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSXACpo,VIRASXA->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSXA,aSXACpo)

			DbSelectArea("VIRASXA")
			DbSkip()
		End

		DbCloseArea()  

		oProcess:SetRegua2( Len( aSXA ) )

		dbSelectArea( 'SXA' )
		dbSetOrder( 1 )

		For nI := 1 To Len( aSXA )

			If !SXA->( dbSeek( aSXA[nI][1] + aSXA[nI][2] ) )

				If !( aSXA[nI][1] $ cAlias )
					cAlias += aSXA[nI][1] + '/'
				EndIf

				RecLock( 'SXA', .T. )
				For nJ := 1 To Len( aSXA[nI] )
					If FieldPos( aEstrut[nJ] ) > 0
						FieldPut( FieldPos( aEstrut[nJ] ), aSXA[nI][nJ] )
					EndIf
				Next nJ
				dbCommit()
				MsUnLock()

				cTexto += 'Foi incluída a pasta ' + aSXA[nI][1] + '/' + aSXA[nI][2]  + CRLF

				oProcess:IncRegua2( 'Atualizando Arquivos (SXA)...')

			EndIf

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SXA' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto








Static Function FSAtuSXB()
	Local aSXB      := {}
	Local aSXBCpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local cAlias    := 'Inicio da Atualizacao do SXB' + CRLF + CRLF
	Local cTexto    := ''

	aEstrut := { 'XB_ALIAS',  'XB_TIPO'   , 'XB_SEQ'    , 'XB_COLUNA' , ;
	'XB_DESCRI', 'XB_DESCSPA', 'XB_DESCENG', 'XB_CONTEM' }

	if File('sxb_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'sxb_virada.dtc', 'VIRASXB', .F., .F. )

		DbSelectArea("VIRASXB")
		DbGotop()
		While !Eof()

			aSXBCpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSXBCpo,VIRASXB->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSXB,aSXBCpo)

			DbSelectArea("VIRASXB")
			DbSkip()
		End

		DbCloseArea()  

		oProcess:SetRegua2( Len( aSXB ) )

		dbSelectArea( 'SXB' )
		dbSetOrder( 1 )

		For nI := 1 To Len( aSXB )

			If !Empty( aSXB[nI][1] )

				If !SXB->( dbSeek( PadR( aSXB[nI][1], Len( SXB->XB_ALIAS ) ) + aSXB[nI][2] + aSXB[nI][3] + aSXB[nI][4] ) )

					If !( aSXB[nI][1] $ cAlias )
						cAlias += aSXB[nI][1] + '/'
						cTexto += 'Foi incluída a consulta padrão ' + aSXB[nI][1] + CRLF
					EndIf

					RecLock( 'SXB', .T. )

					For nJ := 1 To Len( aSXB[nI] )
						If !Empty( FieldName( FieldPos( aEstrut[nJ] ) ) )
							FieldPut( FieldPos( aEstrut[nJ] ), aSXB[nI][nJ] )
						EndIf
					Next nJ

					dbCommit()
					MsUnLock()

				Else

					//
					// Verifica todos os campos
					//
					For nJ := 1 To Len( aSXB[nI] )

						//
						// Se o campo estiver diferente da estrutura
						//
						If aEstrut[nJ] == SXB->( FieldName( nJ ) ) .AND. ;
						StrTran( AllToChar( SXB->( FieldGet( nJ ) )  ), ' ', '' ) <> ;
						StrTran( AllToChar( aSXB[nI][nJ]             ), ' ', '' )

							//If ApMsgNoyes( 'A consulta padrao ' + aSXB[nI][1] + ' está com o ' + SXB->( FieldName( nJ ) ) + ;
						//	//' com o conteúdo' + CRLF + ;
							//'[' + RTrim( AllToChar( SXB->( FieldGet( nJ ) ) ) ) + ']' + CRLF + ;
							//', e este é diferente do conteúdo' + CRLF + ;
							//'[' + RTrim( AllToChar( aSXB[nI][nJ] ) ) + ']' + CRLF +;
							//'Deseja substituir ? ', 'Confirma substituição de conteúdo' )

								RecLock( 'SXB', .F. )
								FieldPut( FieldPos( aEstrut[nJ] ), aSXB[nI][nJ] )
								dbCommit()
								MsUnLock()

								If !( aSXB[nI][1] $ cAlias )
									cAlias += aSXB[nI][1] + '/'
									cTexto += 'Foi Alterada a consulta padrao ' + aSXB[nI][1] + CRLF
								EndIf

							//EndIf

						EndIf

					Next

				EndIf

			EndIf

			oProcess:IncRegua2( 'Atualizando Consultas Padroes (SXB)...' )

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SXB' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto








Static Function FSAtuSX5()
	Local cTexto    := 'Inicio Atualizacao SX5' + CRLF + CRLF
	Local cAlias    := ''
	Local aSX5      := {}
	Local aSX5Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0

	aEstrut := { 'X5_FILIAL', 'X5_TABELA', 'X5_CHAVE', 'X5_DESCRI', 'X5_DESCSPA', 'X5_DESCENG' }

	if File('sx5_virada.dtc')
		DbUseArea( .T., "CTREECDX", 'sx5_virada.dtc', 'VIRASX5', .F., .F. )

		DbSelectArea("VIRASX5")
		DbGotop()
		While !Eof()

			aSX5Cpo := {}

			For _x := 1 To Len(aEstrut)                            

				aadd(aSX5Cpo,VIRASX5->( FieldGet(FieldPos(aEstrut[_x]))) )

			Next _x

			aadd(aSX5,aSX5Cpo)

			DbSelectArea("VIRASX5")
			DbSkip()
		End

		DbCloseArea()  

		//
		// Atualizando dicionário
		//
		oProcess:SetRegua2( Len( aSX5 ) )

		dbSelectArea( 'SX5' )
		SX5->( dbSetOrder( 1 ) )

		For nI := 1 To Len( aSX5 )

			oProcess:IncRegua2( 'Atualizando tabelas...' )

			If !SX5->( dbSeek( aSX5[nI][1] + aSX5[nI][2] + aSX5[nI][3]) )
				cTexto += 'Item da tabela criado. Tabela '   + AllTrim( aSX5[nI][1] ) + aSX5[nI][2] + '/' + aSX5[nI][3] + CRLF
				RecLock( 'SX5', .T. )
			Else
				cTexto += 'Item da tabela alterado. Tabela ' + AllTrim( aSX5[nI][1] ) + aSX5[nI][2] + '/' + aSX5[nI][3] + CRLF
				RecLock( 'SX5', .F. )
			EndIf

			For nJ := 1 To Len( aSX5[nI] )
				If FieldPos( aEstrut[nJ] ) > 0
					FieldPut( FieldPos( aEstrut[nJ] ), aSX5[nI][nJ] )
				EndIf
			Next nJ

			MsUnLock()

			//aAdd( aArqUpd, aSX5[nI][1] )

			If !( aSX5[nI][1] $ cAlias )
				cAlias += aSX5[nI][1] + '/'
			EndIf

		Next nI

		cTexto += CRLF + 'Final da Atualizacao do SX5' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto







Static Function FSAtuSX9()
	Local aSX9      := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local nTamSeek  := Len( SX9->X9_DOM )
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SX9' + CRLF + CRLF

	aEstrut := { 'X9_DOM'   , 'X9_IDENT'  , 'X9_CDOM'   , 'X9_EXPDOM', 'X9_EXPCDOM' ,'X9_PROPRI', ;
	'X9_LIGDOM', 'X9_LIGCDOM', 'X9_CONDSQL', 'X9_USEFIL', 'X9_ENABLE' }

	cTexto += CRLF + 'Final da Atualizacao do SX9' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF

Return cTexto







Static Function FSAtuHlp()
	Local aHlpPor   := {}
	Local aHlpEng   := {}
	Local aHlpSpa   := {}
	Local cTexto    := 'Inicio da Atualizacao ds Helps de Campos' + CRLF + CRLF

	oProcess:IncRegua2(  'Atualizando Helps de Campos ...' )

	cTexto += CRLF + 'Final da Atualizacao dos Helps de Campos' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF

Return cTexto





Static Function EscEmpresa()
	Local   aSalvAmb := GetArea()
	Local   aSalvSM0 := {}
	Local   aRet     := {}
	Local   aVetor   := {}
	Local   oDlg     := NIL
	Local   oChkMar  := NIL
	Local   oLbx     := NIL
	Local   oMascEmp := NIL
	Local   oMascFil := NIL
	Local   oButMarc := NIL
	Local   oButDMar := NIL
	Local   oButInv  := NIL
	Local   oSay     := NIL
	Local   oOk      := LoadBitmap( GetResources(), 'LBOK' )
	Local   oNo      := LoadBitmap( GetResources(), 'LBNO' )
	Local   lChk     := .F.
	Local   lOk      := .F.
	Local   lTeveMarc:= .F.
	Local   cVar     := ''
	Local   cNomEmp  := ''
	Local   cMascEmp := '??'
	Local   cMascFil := '??'

	Local   aMarcadas  := {}


	If !MyOpenSm0Ex()
		ApMsgStop( 'Não foi possível abrir SM0 exclusivo.' )
		Return aRet
	EndIf


	dbSelectArea( 'SM0' )
	aSalvSM0 := SM0->( GetArea() )
	dbSetOrder( 1 )
	dbGoTop()

	While !SM0->( EOF() )

		If aScan( aVetor, {|x| x[2] == SM0->M0_CODIGO} ) == 0
			aAdd(  aVetor, { aScan( aMarcadas, {|x| x[1] == SM0->M0_CODIGO .and. x[2] == SM0->M0_CODFIL} ) > 0, SM0->M0_CODIGO, SM0->M0_CODFIL, SM0->M0_NOME, SM0->M0_FILIAL } )
		EndIf

		dbSkip()
	End

	RestArea( aSalvSM0 )

	Define MSDialog  oDlg Title '' From 0, 0 To 270, 396 Pixel

	oDlg:cToolTip := 'Tela para Múltiplas Seleções de Empresas/Filiais'

	oDlg:cTitle := 'Selecione a(s) Empresa(s) para Atualização'

	@ 10, 10 Listbox  oLbx Var  cVar Fields Header ' ', ' ', 'Empresa' Size 178, 095 Of oDlg Pixel
	oLbx:SetArray(  aVetor )
	oLbx:bLine := {|| {IIf( aVetor[oLbx:nAt, 1], oOk, oNo ), ;
	aVetor[oLbx:nAt, 2], ;
	aVetor[oLbx:nAt, 4]}}
	oLbx:BlDblClick := { || aVetor[oLbx:nAt, 1] := !aVetor[oLbx:nAt, 1], VerTodos( aVetor, @lChk, oChkMar ), oChkMar:Refresh(), oLbx:Refresh()}
	oLbx:cToolTip   :=  oDlg:cTitle
	oLbx:lHScroll   := .F. // NoScroll

	@ 112, 10 CheckBox oChkMar Var  lChk Prompt 'Todos'   Message 'Marca / Desmarca Todos' Size 40, 007 Pixel Of oDlg;
	on Click MarcaTodos( lChk, @aVetor, oLbx )

	@ 123, 10 Button oButInv Prompt '&Inverter'  Size 32, 12 Pixel Action ( InvSelecao( @aVetor, oLbx, @lChk, oChkMar ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
	Message 'Inverter Seleção' Of oDlg

	// Marca/Desmarca por mascara
	@ 113, 51 Say  oSay Prompt 'Empresa' Size  40, 08 Of oDlg Pixel
	@ 112, 80 MSGet  oMascEmp Var  cMascEmp Size  05, 05 Pixel Picture '@!'  Valid (  cMascEmp := StrTran( cMascEmp, ' ', '?' ), cMascFil := StrTran( cMascFil, ' ', '?' ), oMascEmp:Refresh(), .T. ) ;
	Message 'Máscara Empresa ( ?? )'  Of oDlg
	@ 123, 50 Button oButMarc Prompt '&Marcar'    Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .T. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
	Message 'Marcar usando máscara ( ?? )'    Of oDlg
	@ 123, 80 Button oButDMar Prompt '&Desmarcar' Size 32, 12 Pixel Action ( MarcaMas( oLbx, aVetor, cMascEmp, .F. ), VerTodos( aVetor, @lChk, oChkMar ) ) ;
	Message 'Desmarcar usando máscara ( ?? )' Of oDlg

	Define SButton From 111, 125 Type 1 Action ( RetSelecao( @aRet, aVetor ), oDlg:End() ) OnStop 'Confirma a Seleção'  Enable Of oDlg
	Define SButton From 111, 158 Type 2 Action ( IIf( lTeveMarc, aRet :=  aMarcadas, .T. ), oDlg:End() ) OnStop 'Abandona a Seleção' Enable Of oDlg
	Activate MSDialog  oDlg Center

	RestArea( aSalvAmb )
	dbSelectArea( 'SM0' )
	dbCloseArea()

Return  aRet





Static Function MarcaTodos( lMarca, aVetor, oLbx )
	Local  nI := 0

	For nI := 1 To Len( aVetor )
		aVetor[nI][1] := lMarca
	Next nI

	oLbx:Refresh()

Return NIL






Static Function InvSelecao( aVetor, oLbx )
	Local  nI := 0

	For nI := 1 To Len( aVetor )
		aVetor[nI][1] := !aVetor[nI][1]
	Next nI

	oLbx:Refresh()

Return NIL





Static Function RetSelecao( aRet, aVetor )
	Local  nI    := 0

	aRet := {}
	For nI := 1 To Len( aVetor )
		If aVetor[nI][1]
			aAdd( aRet, { aVetor[nI][2] , aVetor[nI][3], aVetor[nI][2] +  aVetor[nI][3] } )
		EndIf
	Next nI

Return NIL





Static Function MarcaMas( oLbx, aVetor, cMascEmp, lMarDes )
	Local cPos1 := SubStr( cMascEmp, 1, 1 )
	Local cPos2 := SubStr( cMascEmp, 2, 1 )
	Local nPos  := oLbx:nAt
	Local nZ    := 0

	For nZ := 1 To Len( aVetor )
		If cPos1 == '?' .or. SubStr( aVetor[nZ][2], 1, 1 ) == cPos1
			If cPos2 == '?' .or. SubStr( aVetor[nZ][2], 2, 1 ) == cPos2
				aVetor[nZ][1] :=  lMarDes
			EndIf
		EndIf
	Next

	oLbx:nAt := nPos
	oLbx:Refresh()

Return NIL






Static Function VerTodos( aVetor, lChk, oChkMar )
	Local lTTrue := .T.
	Local nI     := 0

	For nI := 1 To Len( aVetor )
		lTTrue := IIf( !aVetor[nI][1], .F., lTTrue )
	Next nI

	lChk := IIf( lTTrue, .T., .F. )
	oChkMar:Refresh()

Return NIL






Static Function MyOpenSM0Ex()

	Local lOpen := .F.
	Local nLoop := 0

	For nLoop := 1 To 20
		dbUseArea( .T., , 'SIGAMAT.EMP', 'SM0', .F., .F. )

		If !Empty( Select( 'SM0' ) )
			lOpen := .T.
			dbSetIndex( 'SIGAMAT.IND' )
			Exit
		EndIf

		Sleep( 500 )

	Next nLoop

	If !lOpen
		ApMsgStop( 'Não foi possível a abertura da tabela ' + ;
		'de empresas de forma exclusiva.', 'ATENÇÃO' )
	EndIf

Return lOpen







Static Function FSAtuSX1()
	Local aSX2      := {}
	Local aSX2Cpo   := {}
	Local aEstrut   := {}
	Local nI        := 0
	Local nJ        := 0
	Local cAlias    := ''
	Local cTexto    := 'Inicio da Atualizacao do SX2' + CRLF + CRLF
	Local cPath     := ''
	Local cEmpr     := ''
	Local aEstTemp
	Local nTotal, nx

	dbSelectArea( 'SX1' )
	aEstrut := SX1->(dbStruct())
	SX1->( dbSetOrder( 1 ) )
	SX1->( dbGoTop() )

	if File('sx1_virada.dtc')
		DbUseArea( .T., "CTREECDX" , 'sx1_virada.dtc', 'VIRASX1', .F., .F. )

		DbSelectArea("VIRASX1")
		Count to nTotal
		aEstTemp := VIRASX1->(dbStruct())
		VIRASX1->(DbGotop())

		oProcess:SetRegua2( nTotal )

		While !VIRASX1->(Eof())

			oProcess:IncRegua2( 'Atualizando Arquivos (SX1)...')

			if SX1->(dbSeek(VIRASX1->X1_GRUPO+VIRASX1->X1_ORDEM))
				RecLock("SX1",.F.)
			else
				RecLock("SX1",.T.)
			endif

			for nx := 1 to Len(aEstTemp)

				nPos := aScan(aEstrut,{|x|x[1] == aEstTemp[nx,1]})

				if nPos > 0
					SX1->&(aEstTemp[nx,1]) := VIRASX1->&(aEstTemp[nx,1])
				endif

			next

			SX1->(MsUnlock())

			VIRASX1->(DbSkip())

		End

		VIRASX1->(DbCloseArea())  

		cTexto += CRLF + 'Final da Atualizacao do SX1' + CRLF + Replicate( '-', 128 ) + CRLF + CRLF
	endif
Return cTexto





Static function aaddUpd(cAlias)
	if !EMPTY(cAlias) .and. aScan(aArqUpd,{|x| AllTrim(x) == AllTrim(cAlias)}) == 0
		aadd(aArqUpd,AllTrim(cAlias))
	endif
return