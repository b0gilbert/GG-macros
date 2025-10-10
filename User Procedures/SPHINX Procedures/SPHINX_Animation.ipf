#pragma rtGlobals=3		// Use modern global access method and strict wave access.



Function NewStackMovie()
	
	String StackFolder 	= "root:SPHINX:Stacks"
	String StackName, StackList = ReturnStackList(StackFolder)
	
	Variable i, NStacks= ItemsInList(StackList)
	
	if (NStacks == 0)
		return 0
	endif
	
	StackName 	= ChooseStack(" Choose the stack to delete","",1)
	if (cmpstr("all",StackName) == 0)
		DoAlert 0, "Cannot convert all stacks to movie animations"
		return 0
	else	
		WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+StackName)
		StackToMovie(SPHINXStack,StackName)
	endif
End

Function StackToMovie(SPHINXStack,StackName)
	Wave SPHINXStack
	String StackName
	
	Variable i
	Variable NumX = Dimsize(SPHINXStack,0)
	Variable NumY = Dimsize(SPHINXStack,1)
	Variable NumE = Dimsize(SPHINXStack,2)
	
	Make /O/D/N=(NumX,NumY,0,0) Frame

	Frame[][] = SPHINXStack[p][q][0]
	
	DoWindow/K MovieWindow
	Display/K=1/N=MovieWindow/W=(270,44,NumX+270,NumY+44)
	AppendImage Frame
	SetAxis/A/R/W=MovieWindow left
	ModifyGraph width={Plan,1,bottom,left} 
//	ModifyImage/W=MovieWindow Frame ctab={0,imageBitInfo,Grays,imageColorReverse}
	DoUpdate
    
	NewMovie/I/O/P=StackPath/F=20 as StackName+".mov"
	AddMovieFrame 
	
	for (i=1;i<NumE;i+=1)
		Frame[] 	= SPHINXStack[p][q][i]
		DoUpdate
		AddMovieFrame
	endfor
	
	CloseMovie
	DoWindow /K MovieWindow
	
	PlayMovie /P=StackPath as StackName+".mov"
	PlayMovieAction start
//	RemoveImage Frame
	
//	CtrlBackground
	
    
//    AppendImage M_Stack
//    SetAxis/A/R/W=stack_window left
//    ModifyGraph width={Plan,1,bottom,left} 
//    ModifyImage/W=stack_window M_Stack ctab={0,imageBitInfo,Grays,imageColorReverse}
//    DoUpdate
//    SetBackground file_IO#movieEffect()
//
//    SetWindow stack_window hook(keypress)=CommonUsage#mouseReadHook
//
//    KillWaves Frame
End




//Function MovieCtrlButtonProc(ctrlName) : ButtonControl
//    String ctrlName;
//
//    CommonUsage#play_stop_movie()
//
//    return 0
//End
//
//Function play_stop_movie()
//
//    NVAR isPlaying = root:IP_consts:isPlaying
//
//    if (Exists("root:images:M_Stack")==0)
//        return 1;
//    endif
//    doWindow stack_window
//    if (V_flag==0) // stack_window does not exist
//        return 2
//    endif 
//
//    if (isPlaying)
//        CtrlBackground stop
//        isPlaying = 0
//    else
//        CtrlBackground period=1,start
//        isPlaying = 1
//    endif
//	
//    return 0
//End
//
//Function stack2movieButtonProc(ctrlName) : ButtonControl
//    String ctrlName;
//
//    NVAR numImages = root:IP_consts:numImages
//    NVAR imageDType = root:IP_consts:imageDType 
//    NVAR imageColorReverse = root:IP_consts:imageColorReverse
//    WAVE M_Stack = root:images:M_Stack
//    NVAR dimX = root:IP_consts:dimX
//    NVAR dimY = root:IP_consts:dimY
//    
//    if (exists("M_Stack")==0)
//        return -1;
//    endif
//    Make/O/D/N=(dimX,dimY,0,0) Frame;
//
//    Variable imageBitInfo
//    switch (CommonUsage#checkImageDatatype("M_Stack"))
//        case 72: // 8 bit unsigned int
//            imageBitInfo = 255
//        break
//        case 80: // 16 bit unsigned int
//            imageBitInfo = 65535
//        break
//        default:
//            doAlert 0, "caution! the displayed stack is neither 8 bit nor 16 bit!"
//            ImageStats/M=1 M_Stack
//            imageBitInfo = V_max
//        break
//    endswitch
//
//    Frame[][] = M_Stack[p][q][0]
//    DoWindow/K stack_window
//    Display/K=1/N=stack_window/W=(270,44,dimX+270,dimY+44);AppendImage Frame
//    SetAxis/A/R/W=stack_window left
//    ModifyGraph width={Plan,1,bottom,left} 
//    ModifyImage/W=stack_window Frame ctab={0,imageBitInfo,Grays,imageColorReverse}
//    DoUpdate
//    
//    NewMovie/I/O/F=20 as "Movie"
//    AddMovieFrame 
//    
//    Variable i
//    for (i=1;i<numImages;i+=1)
//        Frame[][] = M_Stack[p][q][i]
//        DoUpdate
//        AddMovieFrame
//    endfor
//
//    closeMovie
//    RemoveImage Frame
//    AppendImage M_Stack
//    SetAxis/A/R/W=stack_window left
//    ModifyGraph width={Plan,1,bottom,left} 
//    ModifyImage/W=stack_window M_Stack ctab={0,imageBitInfo,Grays,imageColorReverse}
//    DoUpdate
//    SetBackground file_IO#movieEffect()
//
//    SetWindow stack_window hook(keypress)=CommonUsage#mouseReadHook
//
//    KillWaves Frame
//    return 0
//End