#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// ***************************************************************************
// **************** 			Main routine for loading ENVI Stack of ascii images
// ***************************************************************************
//
//

// *************************************************************
// ****		Load an ENVI Stack
// *************************************************************
//
//	Here is the header information: ; File Dimensions: 696 samples x 199 lines x 458 bands
// 													   696 X             199 Y            458 lambda
// There seems to be a blank line between the individual 696x458 matrices
//
//	The "samples" are the number of values in a single horizontal line of text, separated by 5 spaces. = NX
// 	The "lines" are the number of arrays = NY
// 	The "bands" are the number of horizontal lines of text. = WAVELENGTH

//	The "samples" = 696 = NX
// 	The "bands" = 458 = WAVELENGTH

// 	The "lines" = 199 = NY

//
// 	The following command loads a single array
// 			LoadWave/J/M/A=wave/E=1/K=0/V={" "," $",0,0} "KINGSTON:DATA:Cytoviva 1JULY15:Ascii single:Cell1_HYPER_100X_500ms_ascii_single_nohead.txt"


Function LoadENVIAsciiStack()

	InitializeStackBrowser()
	
	Variable FileRefNum, DataPos
	Variable NValues, NAxis, NX, NY, xx=0, yy=0, zz=0, s1, s2
	String ENVILine, ENVIList, ValStr
	String LoadedName, StackName, StackFolder = "root:SPHINX:Stacks"

	String OldDf = GetDataFolder(1)
	SetDataFolder root:SPHINX:Stacks
		
		// Open the ENVI stack
		Open /R/M="Choose an ENVI ascii file" FileRefNum
		LoadedName = StringFromList(0,S_Filename)
		
		// Read in the header lines and find the start of the data
		do
			FReadLine FileRefNum, ENVILine
			if (strlen(ENVILine) == 0)
				Close FileRefNum
				Print " 		aborted ENVI load: Unexpectedly, no more lines in file."
				return 0
			endif

			if (StrSearch(ENVILine,"File Dimensions",0) > -1)
				NX = ReturnNthNumber(ENVILine,1)
				NY = ReturnNthNumber(ENVILine,2)
				NAxis = ReturnNthNumber(ENVILine,3)
				if ((numtype(NAxis)!=0) && (numtype(NX)!=0) && (numtype(NY)!=0))
					Close FileRefNum
					Print " 		aborted ENVI load: Problem reading the file dimensions."
					return 0
				endif
			endif

			if (cmpstr(ENVILine[0,0],";")!=0)
				break 		// This line is not a header - does not start with a semicolon
			endif
			
			// Record the position of the start of the next line. 
			FStatus FileRefNum
			DataPos 	= V_filePos
		while(1)
		
		// Go to the start of the data lines
		FSetPos FileRefNum, DataPos
		
		Make /O/U/N=(NX) ENVIRow
		Make /O/U/N=(NX,NY,NAxis) ENVIMatrix=0
		
		// Read in the Stack
		// Loop through each of 199 Y-values
		for (yy=0;yy<NY;yy+=1)
		
			// Read a Single Image
			// Loop through each of 458 wavelengths
			for (zz=0;zz<NAxis;zz+=1)
			
				FReadLine FileRefNum, ENVILine
				if (strlen(ENVILine) == 0)
					Print " 		aborted ENVI load: Unexpectedly, no more lines in file."
					Close FileRefNum
					return 0
				endif
				
				// Each line contains 696 X-values ... 
				for (xx=0;xx<NX;xx+=1)
					ENVIRow[xx] 	= str2num(ENVILine[xx*7,xx*7+7])
				endfor
				
				// ... which should go into the matrix row at the YY'th column
				ENVIMatrix[][yy][zz] 	= ENVIRow[p]
			endfor
				
			// Read the next blank line
			FReadLine FileRefNum, ENVILine
				
		endfor
		Close FileRefNum
				
		StackName 	= StripSpacesAndSuffix(S_Filename,".")
		StackName 	= CleanUpDataName(StackName)
		Prompt StackName, "Name of imported stack"
		do
			DoPrompt "Please avoid odd characters and 'stack'!", StackName
			if (V_flag)
				return 0
			endif
			StackName 	= CleanUpDataName(StackName)
		while(StrSearch(StackName,"stack",0,2) > -1)

		// Rename the stack
		if (WaveExists($StackName) == 1)
			DoWindow /K StackBrowser
			RemoveDataFromAllWindows(StackName)
			KillWaves $StackName
		endif
		Rename ENVIMatrix, $StackName
		KillWaves /Z ENVIRow
		
		DisplayStackBrowser(StackName)
		
		Print " *** Loaded an ENVI stack: "+StackName+" from "+S_Filename
		Print " 		...	 (",NX,"x",NY,") images and ",NAxis," optical wavelength values."
		
	SetDataFolder $(OldDf)
End