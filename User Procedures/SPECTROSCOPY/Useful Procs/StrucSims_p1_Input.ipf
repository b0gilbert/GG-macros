#pragma rtGlobals=1		// Use modern global access method.

// ***************************************************************************
// **************** 			Input of P1 Unit Cell files
// ***************************************************************************
//
//	Important assumptions about the formating of the p1 file. 
//		Elements and Sites will be grouped together
//		The Element, Site Number and Site Instance will be give thus: 
//				"Fe1_1"
//		The lack of site instances is irrelevant, but other changes may be fatal. 
// 	
// 	*** Assume that positions are CRYSTALLOGRAPHIC and are converted to Cartesians
// 	*** Loader routine is based on the Coordinates output of crystalmaker. 

Function LoadP1UnitCell()
	
	MakeVectorsAndRotationMatrices(4)
	
	Variable InvertX, InvertY, InvertZ, NoSitesFlag, refNum
	String FullPath="", message = "Please locate the P1 unit cell '.cif' file"
	
	NewDataFolder /O/S root:StrucSims
	NewDataFolder /O/S root:StrucSims:p1UnitCell
	
		String /G gP1FileType
	
		String P1FileType=gP1FileType
		Prompt P1FileType, "Unit Cell file type", popup, "GenX3;Crystal Maker coordinates;Atoms p1;Cerius p1;PDFGui cif;"
		DoPrompt "P1 Unit Cell import", P1FileType
		if (V_flag)
			SetDataFolder root:
			return 0
		endif
		
		gP1FileType 	= P1FileType
	
		// Prompt for the location of the P1 file
		Open /R/D/M=message/R/T="????" refNum
		FullPath = S_fileName
		if (strlen(S_fileName) == 0)
			return 0
		endif
			
		String p1Name = ReturnP1MaterialName(S_fileName,NoSitesFlag,InvertX, InvertY, InvertZ)
		if (cmpstr("_quit!_",p1Name) == 0)
			return 0
		endif
		
		if (cmpstr("PDFGui cif",P1FileType) == 0)
//			LoadCIFP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
		elseif (cmpstr("GenX3",P1FileType) == 0)
			LoadGenX3XYZ(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
		elseif (cmpstr("Atoms p1",P1FileType) == 0)
			LoadAtomsP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
		elseif (cmpstr("Cerius p1",P1FileType) == 0)
			LoadCeriusXtlFile(FullPath,p1Name,1)
		else
			LoadCMP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
		endif
		
	SetDataFolder root:		
End

Function /T ReturnP1MaterialName(S_fileName,NoSites,InvX,InvY,InvZ)
	String S_fileName
	Variable &NoSites, &InvX,&InvY,&InvZ
	
	String CNNAme
	Variable NoSitesFlag, InvertX, InvertY, InvertZ
	
	
	CNNAme = ParseFilePath(3, S_fileName, ":", 0, 0)
	CNNAme = ParseFilePath(0, CNNAme, "_", 0, 0)
	
	Prompt CNNAme, "p1 material name"
	Prompt InvertX, "Invert X?", popup, "no;yes"
	Prompt InvertY, "Invert Y?", popup, "no;yes"
	Prompt InvertZ, "Invert Z?", popup, "no;yes"
	Prompt NoSitesFlag, "Keep site numbers?", popup, "yes;no;"
	
	do
		DoPrompt "p1 load information", CNNAme, NoSitesFlag, InvertX, InvertY, InvertZ
		if (V_flag)
			return "_quit!_"
		endif
		
		InvX 	= (InvertX == 2) ? 1 : 0
		InvY 	= (InvertY == 2) ? 1 : 0
		InvZ 	= (InvertZ == 2) ? 1 : 0
		NoSites 	= (NoSitesFlag == 2) ? 1 : 0
		
	while(strlen(CNNAme)>14)
	
	return CNNAme
End

Function TestScanf(testline,format)
	String testline,format
	
	Variable a, b, c
	String str
	
	sscanf testline,format, str
	
	print str
	
End

// ***************************************************************************
// **************** 			Read the output of WebAtoms - WHICH, precisely? 
// ***************************************************************************
Function LoadGenX3XYZ(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
	String FullPath,p1Name
	Variable NoSitesFlag,InvertX, InvertY, InvertZ
	
//	String AtomTag, P1Line, SpaceGroup, CIFString, p1Folder
//	Variable i=0, j=0, loading=1, refNum, NColumns, NumUnitAtoms=0
//	Variable Unita=0, Unitb=0, Unitc=0, Alpha=0, Betta=0, Gama=0, NElements = 1, CubicFlag = -1, startOfAtoms=-1

	Variable j, refNum, NumUnitAtoms
	Variable Unita=0, Unitb=0, Unitc=0, Alpha=90, Betta=90, Gama=90
	String AtomTag, P1Line, CIFString, p1Folder
	
	Open/R refNum as FullPath
	if (refNum == 0)
		return -1
	endif

	FReadLine refNum, P1Line
	if (strlen(P1Line) == 0)
		Close refNum
		return 0
	endif
	
	NumUnitAtoms = str2num(P1Line)
	if (NumType(NumUnitAtoms) != 0)
		Close refNum
		return 0
	endif
	
	FReadLine refNum, P1Line
	P1Line 	= ReplaceString(" ",ReturnTextAfterNthChar(P1Line,":",1),"")
	sscanf P1Line, "a=%fb=%fc=%f", Unita,Unitb,Unitc
	
	Make /O/D/N=(NumUnitAtoms) Unitx, Unity, Unitz, UnitOcc=1, UnitBf=0.001, UnitAtomicNumber, UnitCharge=0
	Make /O/T/N=(NumUnitAtoms) UnitElement, UnitTag

	for (j=0;j<NumUnitAtoms;j+=1)
		FReadLine refNum, P1Line
		if (strlen(P1Line) == 0)
			break
		endif

		CIFString 		= StripRepeatedChars(P1Line," ")
		CIFString 		= StripLeadingChars(CIFString," ")
		CIFString 		= ReplaceString(" ",CIFString,";")
		
		UnitElement[j] 		= StringFromList(0,CIFString)
		UnitX[j] 				= str2num(StringFromList(1,CIFString))
		UnitY[j] 				= str2num(StringFromList(2,CIFString))
		UnitZ[j] 				= str2num(StringFromList(3,CIFString))

		AtomTag 			= UnitElement[j]
		UnitTag[j] 			= AtomTag
	endfor
	Close refNum
	
	// Allow for mirror inversions
	Unitx[] 			= (InvertX) ? (1-Unitx[p]) :  Unitx[p]
	Unity[] 			= (InvertY) ? (1-Unity[p]) :  Unity[p]
	Unitz[]			= (InvertZ) ? (1-Unitz[p]) :  Unitz[p]
	
//	if ((Unita * Unitb * Unitc * Alpha * Betta * Gama) == 0)
	if ((Unita * Unitb * Unitc) == 0)
		Print "*** Error in data load: Could not read in at least one unit cell parameter."
		return 0
	endif

	Print " *** Successfully loaded the unit cell information from",S_fileName,"with",NumUnitAtoms,"atoms. "
	Print "          The name of the material structure is",p1Name
//	Print "          The original space group is",SpaceGroup
	
	// Strip off extraneous spaces from the text
	UnitElement[]			= ReplaceString(" ", UnitElement[p], "")
	UnitAtomicNumber[] 	= AtomToZNumber(UnitElement[p],1)
	
	// Remove Site Instances, e.g. transform "Fe1_1" and "Fe1_2" both into Fe1" and "Fe1"
	UnitTag[]		= StripSpacesAndSuffix(UnitTag[p], "_")

	// Convert GenX (X,Y,Z) coordinates to (A,B ,C)
	UnitX /= Unita
	UnitY /= Unitb
	UnitZ /= Unitc
	// Put unit cell atomic positions into array in Crystallographic coords
	Make /O/D/N=(NumUnitAtoms,3) UnitABC
	CoordVectorsToXYZMatrix(NumUnitAtoms,UnitX,UnitY,UnitZ,UnitABC)
	
	p1Folder 	=  CreateNewp1Folder(p1Name,Unita,Unitb,Unitc,Alpha,Betta,Gama,UnitABC,UnitAtomicNumber,UnitOcc, UnitBf, UnitCharge,UnitTag)

	// Save the cell parameter vectors. 
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",0)
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",1)
	KillAllWavesInFolder("","Unit*")
	
	DisplayUCParameters(p1Name,p1Folder)
		
	return 1
End

// ***************************************************************************
// **************** 			Read the output of WebAtoms - WHICH, precisely? 
// ***************************************************************************
Function LoadAtomsP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
	String FullPath,p1Name
	Variable NoSitesFlag,InvertX, InvertY, InvertZ
	
	String AtomTag, P1Line, SpaceGroup, CIFString, p1Folder
	Variable i=0, j=0, loading=1, refNum, NColumns, NumUnitAtoms=0
	Variable Unita=0, Unitb=0, Unitc=0, Alpha=0, Betta=0, Gama=0, NElements = 1, CubicFlag = -1, startOfAtoms=-1

	Open/R refNum as FullPath
	if (refNum == 0)
		return -1
	endif
		
	do
		FReadLine refNum, P1Line
		if (strlen(P1Line) == 0)
			break
		endif
		
		if (startOfAtoms > -1)
			NumUnitAtoms += 1
		endif
		
		if (StrSearch(P1Line,"space",-1) > -1)
			SpaceGroup 	= ReplaceString("\t",ReturnLastSuffix(P1Line,":"),"")
		else	
			P1Line 	= ReplaceString(" ",P1Line,"")
			P1Line 	= ReplaceString("\t",P1Line,"")
		endif
		
		if (StrSearch(P1Line,"alpha=",-1) > -1)
			sscanf P1Line, "alpha=%fbeta=%fgamma=%f", Alpha,Betta,Gama
		elseif (StrSearch(P1Line,"a=",-1) > -1)
			sscanf P1Line, "a = %f b = %f c = %f", Unita,Unitb,Unitc
		endif
		
		if (StrSearch(P1Line,"!elem",-1) > -1)
			FStatus refNum
			startOfAtoms = V_filePos
		endif
	while(1)
	
	if (startOfAtoms == -1)
		Print " *** Could not find the start of the atomic coordinates!"
		return 0
	endif
	
	Make /O/D/N=(NumUnitAtoms) Unitx, Unity, Unitz, UnitOcc=1, UnitBf=0.001, UnitAtomicNumber, UnitCharge=0
	Make /O/T/N=(NumUnitAtoms) UnitElement, UnitTag

	FSetPos refnum, startOfAtoms
//	FReadLine refNum, P1Line
	do
		FReadLine refNum, P1Line
		if (strlen(P1Line) == 0)
			break
		endif

		CIFString 	= StripRepeatedChars(P1Line," ")
		CIFString 	= StripLeadingChars(CIFString," ")
		CIFString 	= ReplaceString(" ",CIFString,";")
		
		AtomTag 			= StringFromList(4,CIFString)
		AtomTag 			= StripSuffixBySeparator(AtomTag,"_")
		if (NoSitesFlag)
			AtomTag 		= ReturnTextBeforeNumber(AtomTag) + "1"
		endif
		UnitTag[j] 			= AtomTag
		
		UnitElement[j] 		= StringFromList(0,CIFString)
		Unitx[j] 			= str2num(StringFromList(1,CIFString))
		Unity[j] 			= str2num(StringFromList(2,CIFString))
		Unitz[j] 			= str2num(StringFromList(3,CIFString))
//		UnitBf[j] 			= str2num(StringFromList(5,CIFString))
//		UnitOcc[j] 			= str2num(StringFromList(7,CIFString))
		
		j += 1
	while(1)
	Close refNum
	
	// Allow for mirror inversions
	Unitx[] 			= (InvertX) ? (1-Unitx[p]) :  Unitx[p]
	Unity[] 			= (InvertY) ? (1-Unity[p]) :  Unity[p]
	Unitz []				= (InvertZ) ? (1-Unitz[p]) :  Unitz[p]
	
	if ((Unita * Unitb * Unitc * Alpha * Betta * Gama) == 0)
		Print "*** Error in data load: Could not read in at least one unit cell parameter."
		return 0
	endif

	Print " *** Successfully loaded the unit cell information from",S_fileName,"with",NumUnitAtoms,"atoms. "
	Print "          The name of the material structure is",p1Name
	Print "          The original space group is",SpaceGroup
	
	// Strip off extraneous spaces from the text
	UnitElement[]			= ReplaceString(" ", UnitElement[p], "")
	UnitAtomicNumber[] 	= AtomToZNumber(UnitElement[p],1)
	
	// Remove Site Instances, e.g. transform "Fe1_1" and "Fe1_2" both into Fe1" and "Fe1"
	UnitTag[]		= StripSpacesAndSuffix(UnitTag[p], "_")

	// Put unit cell atomic positions into array in Crystallographic coords
	NumUnitAtoms 	= numpnts(Unitx)
	Make /O/D/N=(NumUnitAtoms,3) UnitABC
	CoordVectorsToXYZMatrix(NumUnitAtoms,Unitx,Unity,Unitz,UnitABC)
	
	p1Folder 	=  CreateNewp1Folder(p1Name,Unita,Unitb,Unitc,Alpha,Betta,Gama,UnitABC,UnitAtomicNumber,UnitOcc, UnitBf, UnitCharge,UnitTag)

	// Save the cell parameter vectors. 
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",0)
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",1)
	KillAllWavesInFolder("","Unit*")
	
	DisplayUCParameters(p1Name,p1Folder)
		
	return 1
End

// ***************************************************************************
// **************** 			Read the CIF-style output of PDFGui
// ***************************************************************************
Function LoadCIFP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
	String FullPath,p1Name
	Variable NoSitesFlag,InvertX, InvertY, InvertZ
	
	String AtomTag, P1Line, CIFString, p1Folder, message = "Please locate the P1 unit cell '.cif' file"
	Variable i=0, j=0, loading=1, refNum, NColumns, NumUnitAtoms
	Variable Unita=0, Unitb=0, Unitc=0, Alpha=0, Betta=0, Gama=0, NElements = 1, CubicFlag = -1
	
	Make /O/D/N=(1000) Unitx, Unity, Unitz, UnitOcc, UnitBf, UnitAtomicNumber, UnitCharge=0
	Make /O/T/N=(1000) UnitElement, UnitTag

	Open/R refNum as FullPath
	if (refNum == 0)
		return -1
	endif
		
	do
		FReadLine refNum, P1Line
		if (strlen(P1Line) == 0)
			break
		endif
		
		if (StrSearch(P1Line,"_cell_length_a",-1) > -1)
			Unita 	= ReturnNumberFromText(1,P1Line)
		elseif (StrSearch(P1Line,"_cell_length_b",-1) > -1)
			Unitb 	= ReturnNumberFromText(1,P1Line)
		elseif (StrSearch(P1Line,"_cell_length_c",-1) > -1)
			Unitc 	= ReturnNumberFromText(1,P1Line)
		elseif (StrSearch(P1Line,"_cell_angle_alpha",-1) > -1)
			Alpha 	= ReturnNumberFromText(1,P1Line)
		elseif (StrSearch(P1Line,"_cell_angle_beta",-1) > -1)
			Betta 	= ReturnNumberFromText(1,P1Line)
		elseif (StrSearch(P1Line,"_cell_angle_gamma",-1) > -1)
			Gama 	= ReturnNumberFromText(1,P1Line)
		endif

		NColumns = CountNumbersInString(P1Line,1)
		if (NColumns > 3)
			do
				CIFString 	= StripRepeatedChars(P1Line," ")
				CIFString 	= StripLeadingChars(CIFString," ")
				CIFString 	= ReplaceString(" ",CIFString,";")
				
				AtomTag 			= StringFromList(0,CIFString)
				if (NoSitesFlag)
					AtomTag 		= ReturnTextBeforeNumber(AtomTag) + "1"
				endif
				UnitTag[j] 			= AtomTag
				
				UnitElement[j] 		= StringFromList(1,CIFString)
				Unitx[j] 			= str2num(StringFromList(2,CIFString))
				Unity[j] 			= str2num(StringFromList(3,CIFString))
				Unitz[j] 			= str2num(StringFromList(4,CIFString))
				UnitBf[j] 			= str2num(StringFromList(5,CIFString))
				UnitOcc[j] 			= str2num(StringFromList(7,CIFString))
				
				j += 1
				
				FReadLine refNum, P1Line
				if (strlen(P1Line) == 0)
					loading = 0
					break
				endif
				
			while(1)
		endif
		
		i += 1
	while(loading)
	Close refNum
	
	Redimension /N=(j)  Unitx, Unity, Unitz, UnitOcc, UnitBf, UnitAtomicNumber, UnitCharge
	Redimension /N=(j)  UnitElement, UnitTag
	
	// Allow for mirror inversions
	Unitx[] 			= (InvertX) ? (1-Unitx[p]) :  Unitx[p]
	Unity[] 			= (InvertY) ? (1-Unity[p]) :  Unity[p]
	Unitz []				= (InvertZ) ? (1-Unitz[p]) :  Unitz[p]
	
	// Sort the positions based upon 'height' in z?
//		Sort /R Unitz, Unitx, Unity, Unitz, UnitElement, UnitTag

	// Sort the positions based upon site
//	Sort /A UnitTag, Unitx, Unity, Unitz, UnitElement, UnitTag
	
	if ((Unita * Unitb * Unitc * Alpha * Betta * Gama) == 0)
		Print "*** Error in data load: Could not read in at least one unit cell parameter."
		return 0
	endif

	Print " *** Successfully loaded the unit cell information from",S_fileName,"with",j,"atoms. "
	Print "          The name of the material structure is",p1Name
	
	// Strip off extraneous spaces from the text
	UnitElement[]			= ReplaceString(" ", UnitElement[p], "")
	UnitAtomicNumber[] 	= AtomToZNumber(UnitElement[p],1)
	
	// Remove Site Instances, e.g. transform "Fe1_1" and "Fe1_2" both into Fe1" and "Fe1"
	UnitTag[]		= StripSpacesAndSuffix(UnitTag[p], "_")

	// Put unit cell atomic positions into array in Crystallographic coords
	NumUnitAtoms 	= numpnts(Unitx)
	Make /O/D/N=(NumUnitAtoms,3) UnitABC
	CoordVectorsToXYZMatrix(NumUnitAtoms,Unitx,Unity,Unitz,UnitABC)
	
	p1Folder 	=  CreateNewp1Folder(p1Name,Unita,Unitb,Unitc,Alpha,Betta,Gama,UnitABC,UnitAtomicNumber,UnitOcc, UnitBf, UnitCharge,UnitTag)

	// Save the cell parameter vectors. 
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",0)
	DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",1)
	KillAllWavesInFolder("","Unit*")
	
	DisplayUCParameters(p1Name,p1Folder)
		
	return 1
End



// ***************************************************************************
// **************** 			Read the Crystal Maker coordinates file
// ***************************************************************************

Function LoadCMP1File(FullPath,p1Name,NoSitesFlag,InvertX, InvertY, InvertZ)
	String FullPath,p1Name
	Variable NoSitesFlag,InvertX, InvertY, InvertZ
	
	Variable FileRefNum, i, j, DimLine, AngleLine, CoordsStart
	Variable FindCoordsFlag=0, FindDimFlag=0, FindAnglesFlag=0, ErrorFlag=0
//	String message, FullPath="", p1Folder
	
	DoWindow /K P1UnitCell
	
//	// Prompt for the location of the P1 file
//	DoWindow /K P1UnitCell
//	message = "Please locate the P1 unit cell file"
//	Open /R/Z=2/M=message/R/T="????" FileRefNum
//	if (V_Flag==0)
//		FullPath = S_fileName
//		Close FileRefNum
//	elseif (strlen(FullPath) == 0)
//		return 0
//	endif
	
	String OldDF = getDataFolder(1)
	NewDataFolder /O/S root:StrucSims
	NewDataFolder /O/S root:StrucSims:p1UnitCell
		
//		String p1Name = ReturnP1MaterialName(S_fileName,NoSitesFlag,InvertX, InvertY, InvertZ)
//		if (cmpstr("_quit!_",p1Name) == 0)
//			return 0
//		endif
		String DimStr 	= "Unit"
		String AngStr 	= "alph"
		String ElmtStr 	= "Elmt"
		
		// Load the P1 file as a read-only Notebook. No user prompt, find it using the full path. 
		OpenNotebook  /R /V=0/N=P1UnitCell/T="????" FullPath
		if (V_flag != 0)
			Print " *** An error trying to open the P1 text file"
			return 0
		else	
			i=0
			do
				// Define the selected text location
				Notebook P1UnitCell selection={(i, 0), (i, 4)}
				// Get the selected text
				GetSelection Notebook, P1UnitCell, 2 
				
				// Find where the unit cell dimensions are
				if (cmpstr(S_selection,DimStr)==0)
					DimLine = i+1
					FindDimFlag = 1
				endif			
				// Find where the unit cell angles
				if (cmpstr(S_selection,AngStr)==0)
					AngleLine = i
					FindAnglesFlag = 1
				endif
				// Find where the atomic coordinates begin
				if (cmpstr(S_selection,ElmtStr)==0)
					// F*cking CrystalMaker writers keep fucking around with format. 
					CoordsStart = i+1
					FindCoordsFlag=1
				endif
				
				if (i>1000)
					ErrorFlag=1
					break
				endif
				i+=1
			while(FindCoordsFlag==0)
			
		endif
		
		if (ErrorFlag==1)
			Print "*** Error in data load: Could not find any atomic coordinates in the 1st 1000 lines of the file."
			return 0
		elseif (FindDimFlag==0)
			Print " *** Error in data load: Could not find the unit cell dimensions."
			return 0
		elseif (FindAnglesFlag==0)
			Print " *** Error in data load: Could not find the unit cell angles"
			return 0
		endif
		
		Variable Unita, Unitb, Unitc, Alpha, Betta, Gama, NElements = 1, CubicFlag = -1
		
		// Extract the unit cell dimensions
		Notebook P1UnitCell selection={(DimLine, 0), (DimLine+1, 0)}
		GetSelection Notebook, P1UnitCell, 2
		Unita 	= ReturnNumberFromText(1,S_selection)
		Unitb 	= ReturnNumberFromText(2,S_selection)
		Unitc 	= ReturnNumberFromText(3,S_selection)
		
		// Extract the unit cell angles
		Notebook P1UnitCell selection={(AngleLine,0), (AngleLine+1, 0)}
		GetSelection Notebook, P1UnitCell, 2
		Alpha 	= ReturnNumberFromText(1,S_selection)
		Betta 	= ReturnNumberFromText(2,S_selection)
		Gama 	= ReturnNumberFromText(3,S_selection)
		
		DoWindow /K P1UnitCell
		
		// Load the unit cell atomic coordinates
		KillNNamedWaves("wave",15)
		LoadWave /Q/A/J/D/K=0/V={" "," $",0,0}/L={0,CoordsStart,0,0,0} FullPath
		
		Variable NumUnitAtoms = numpnts(wave1)
		Make /O/D/N=(NumUnitAtoms) Unitx, Unity, Unitz, UnitOcc, UnitAtomicNumber, UnitCharge=0, UnitBFactor=0.001
		Make /O/T/N=(NumUnitAtoms) UnitElement, UnitTag

		WAVE /T wave0 	= $("wave0")		// Element
		WAVE /T wave1		= $("wave1")		// Tag
		WAVE wave2 		= $("wave2")		// Crystallographic "x"
		WAVE wave3 		= $("wave3")		// Crystallographic "y"
		WAVE wave4 		= $("wave4")		// Crystallographic "z"
		
		UnitElement 		= wave0
		UnitTag				= wave1
		
		// Allow for mirror inversions
		Unitx[] 			= (InvertX) ? (1-wave2[p]) :  wave2[p]
		Unity[] 			= (InvertY) ? (1-wave3[p]) :  wave3[p]
		Unitz []				= (InvertZ) ? (1-wave4[p]) :  wave4[p]
		
		// Sort the positions based upon 'height' in z
//		Sort /R Unitz, Unitx, Unity, Unitz, UnitElement, UnitTag
		// Sort the positions based upon site
//		Sort /A UnitTag, Unitx, Unity, Unitz, UnitElement, UnitTag
		
		// This must be set to unity. It is the equivalent of atom_occ for structures, but only unity values make sense for a unit cell. 
		UnitOcc 			= 1

		KillNNamedWaves("wave",15)
		
		Print " *** Successfully loaded the unit cell information from",S_fileName
		Print "          The name of the material structure is",p1Name
		
		// Strip off extraneous spaces from the text
		UnitElement[]			= ReplaceString(" ", UnitElement[p], "")
		UnitAtomicNumber[] 	= AtomToZNumber(UnitElement[p],1)
		
		// Remove Site Instances, e.g. transform "Fe1_1" and "Fe1_2" both into Fe1" and "Fe1"
		UnitTag[]		= StripSpacesAndSuffix(UnitTag[p], "_")

		// Put unit cell atomic positions into array in Crystallographic coords
		NumUnitAtoms 	= numpnts(Unitx)
		Make /O/D/N=(NumUnitAtoms,3) UnitABC
		CoordVectorsToXYZMatrix(NumUnitAtoms,Unitx,Unity,Unitz,UnitABC)
		
		String p1Folder 	=  CreateNewp1Folder(p1Name,Unita,Unitb,Unitc,Alpha,Betta,Gama,UnitABC,UnitAtomicNumber,UnitOcc, UnitBFactor, UnitCharge,UnitTag)

		// Save the cell parameter vectors. 
		DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",0)
		DuplicateAllWavesInDataFolder("",p1Folder,"*Unit*",1)
		KillAllWavesInFolder("","Unit*")
		
		DisplayUCParameters(p1Name,p1Folder)
		
	SetDataFolder $(OldDf)
	return 1
End

Function /T DuplicateUnitCell(StructureName,NewStructureName,StructureType)
	String StructureName, NewStructureName, StructureType
	
	String OldStructureFolder 	= "root:StrucSims:" + CheckFolderColon(StructureType) + StructureName
	String NewStructureFolder 	= "root:StrucSims:" + CheckFolderColon(StructureType) + NewStructureName
	
	NewDataFolder /O $(NewStructureFolder)
	
	DuplicateAllWavesInDataFolder(OldStructureFolder,NewStructureFolder,"*",0)
	DuplicateAllWavesInDataFolder(OldStructureFolder,NewStructureFolder,"*",1)	// Include text waves. 
	TransferStrsAndVars(OldStructureFolder,NewStructureFolder,"*")
	
	return NewStructureFolder
End

// The input is in FRACTIONAL coordinates
Function /T CreateNewp1Folder(p1Name,a,b,c,Alp,Bet,Gam,UnitABC,Ua,Uo,Ub,Uq,Ut)
	String p1Name
	Variable a,b,c,Alp,Bet,Gam
	Wave UnitABC, Ua, Uo, Ub, Uq
	Wave /T Ut
	
	WAVE Matrix 	= root:StrucSims:Arrays:DetMatrix
	
	String UCFolder		= "root:StrucSims:p1UnitCell"
	String p1Folder		= "root:StrucSims:p1UnitCell:" + ReturnUniqueStructureName("p1UnitCell",p1Name)

	String OldDF = getDataFolder(1)
	NewDataFolder /O/S $(UCFolder)
	
		NewDataFolder /O/S $(p1Folder)
		
			Variable /G gUnita = a, gUnitb = b, gUnitc = c
			Variable /G gAlpha = Alp, gBeta = Bet, gGamma = Gam, gCubicFlag = -1
			
			Variable /G gNElements, gNAtoms=Dimsize(UnitABC,0)
			Make /O/D/N=(gNAtoms) UnitA, UnitB, UnitC
			UnitA[] 	= UnitABC[p][0]
			UnitB[] 	= UnitABC[p][1]
			UnitC[] 	= UnitABC[p][2]
			
			SpaceGroupMatrices(a,b,c,Alp,Bet,Gam)
			
			Make /O/D/N=3 aVector, bVector, cVector
			MakeUnitCellVectors(aVector,bVector,cVector,a,b,c,Alp,Bet,Gam)

			// Transform atom positions to Cartesian coordinates. 
			Matrix[0][] 	= aVector[q]
			Matrix[1][] 	= bVector[q]
			Matrix[2][] 	= cVector[q]
			MatrixOp /O UnitXYZ 	= (UnitABC x Matrix)
			NoZeroRoundingError2D(UnitXYZ,1e-10)
			
			
			
			Make /O/D/N=0 Stoicharray_Z, Stoicharray_N, Stoicharray_N_all, Stoicharray_Occ, Stoicharray_Chg, Stoicharray_Occ, Stoicharray_B
			Make /O/T/N=0 Stoicharray_T, Stoicharray_Bnd
			
			FillStoichiometryArrays(p1Folder,1,Uo,Ub,Uq,Ut)
			
			CreateStructureConstants(p1Folder,Uo,Ut)
	
			// The prefactor (1/0.6022) combines the conversion from cm^3 to ^3 with Avogadro's number. 
			Variable /G  gCellVol	= UnitCellVolume(a,b,c,Alp,Bet,Gam)
			
			// Still does not properly consider Occupancies!!!!
			Variable SumMass 		= SumAtomicMassOrNumber(Ua,Uo,1)
			Variable Rho			= (1/0.60221367) * SumMass/gCellVol
			
			CalculateAtomicDensities(p1Folder,Rho,1)
	
	SetDataFolder $(OldDF)
	
	return p1Folder
End

// ***************************************************************************
// **************** 			Local Geometry Calculation Routines
// ***************************************************************************
//
//		Including these as STATIC routines permits the p1 input procedures to be stand-alone

//STATIC Function UnitCellVolume(a,b,c,alpha,beta,gama)
Function UnitCellVolume(a,b,c,alpha,beta,gama)
	Variable a,b,c,alpha,beta,gama
	
	Variable alp,bet,gam
	alp = (2*pi)*(alpha/360)
	bet = (2*pi)*(beta/360)
	gam = (2*pi)*(gama/360)
	
	return a*b*c*sqrt(1-(cos(alp))^2-(cos(bet))^2-(cos(gam))^2+2*cos(alp)*cos(bet)*cos(gam))
End

//STATIC Function MakeUnitCellVectors(aV,bV,cV,a,b,c,alp,bet,gam)
Function MakeUnitCellVectors(aV,bV,cV,a,b,c,alp,bet,gam)
	Wave aV,bV,cV
	Variable a,b,c,alp,bet,gam
	
	Variable alpha = (2*pi/360) * alp
	Variable betta = (2*pi/360) * bet
	Variable gama = (2*pi/360) * gam
	
	aV = 0
	aV[0] = a
	
	bV[0] = a*b*cos(gama)/aV[0]
	bV[1] = sqrt(b^2 - bV[0]^2)
	bV[2] = 0
	
	cV[0] = a*c*cos(alpha)/aV[0]
	cV[1] = (b*c*cos(betta) - bV[0]*cV[0])/bV[1]
	cV[2] = sqrt(c^2 - cV[0]^2 - cV[1]^2)
	
	NoZeroRoundingError2D(aV,1e-10)
	NoZeroRoundingError2D(bV,1e-10)
	NoZeroRoundingError2D(cV,1e-10)
End

// ***************************************************************************
// **************** 			Export p1 Coordinates and Information
// ***************************************************************************

Function ExportP1UnitCell()

	String OldDF = getDataFolder(1)
	String ExportFolder	= "root:StrucSims:Export"
	
	NewDataFolder /O/S $ExportFolder
	
		MakeStringIfNeeded("root:StrucSims:gChosenp1UnitCell","")
		SVAR gChosenp1UnitCell = $("root:StrucSims:gChosenp1UnitCell")
		
		String /G gP1Name, gP1Name2, gP1ExportName, gP1SpaceGroup
		Variable /G gP1ExportType, gP1ExportNameChoice, gP1EOLFlag
		
		String P1List = ReplaceString("p1UnitCell:",ListOfStructuresInFolder("p1UnitCell","",""),"")
		
		String P1Name = gP1Name
		Prompt P1Name, "Please choose a P1 unit cell", popup, P1List
		String P1Name2 = gP1Name2
		Prompt P1Name2, "Choose another for multi-file export", popup, "_none_;"+P1List
		String P1SpaceGroup = gP1SpaceGroup
		Prompt P1SpaceGroup, "Space group (for PDFGui)"
		Variable P1ExportNameChoice = gP1ExportNameChoice
		Prompt P1ExportNameChoice, "Export naming... ", popup, "use P1 name;enter new name -->;"
		String P1ExportName = gP1ExportName
		Prompt P1ExportName, "... or enter new name below. "
		Variable P1ExportType=gP1ExportType
		Prompt P1ExportType, "Export file", popup, "Cartesian XYZ;Crystallographic XYZ;PDFGui .str;CrystalMaker CIF;"
		Variable P1EOLFlag=gP1EOLFlag+1
		Prompt P1EOLFlag, "End-of-line character", popup, "automatic;Macintosh;Windows;Unix;"
		DoPrompt "P1 export parameters", P1Name, P1Name2, P1SpaceGroup, P1ExportNameChoice, P1ExportName, P1ExportType,P1EOLFlag
		if (V_flag)
			SetDataFolder root:
			return -1
		endif
		
		gP1Name 				= P1Name
		gP1Name2 				= P1Name2
		gP1SpaceGroup 			= ReplaceString(" ",P1SpaceGroup,"")
		gP1EOLFlag				= P1EOLFlag-1
		gP1ExportType			= P1ExportType
		gP1Name				= P1Name
		P1ExportNameChoice	= P1ExportNameChoice
		
		NewPath /O/Q/M="Location to save P1 unit cell file" XYZPath
		if (V_flag != 0)
			return 0
		endif
		
		Variable i	= WhichListItem(P1Name,P1List)
		Variable j	= WhichListItem(P1Name2,P1List)
		
		do
			ExportSingleP1File(StringFromList(i,P1List),"",P1SpaceGroup,1,P1ExportType,P1EOLFlag)
			i+=1
		while(i <= j)
		
	SetDataFolder root:
End
		
Function ExportSingleP1File(P1Name,P1ExportName,P1SpaceGroup,P1ExportNameChoice,P1ExportType,P1EOLFlag)
	String P1Name, P1ExportName, P1SpaceGroup
	Variable P1ExportNameChoice, P1ExportType, P1EOLFlag
	
	if (P1ExportNameChoice == 1)
		P1ExportName		= P1Name
	endif
		
	WAVE /T UnitTag 		= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitTag")
	WAVE /T UnitElement 	= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitElement")
	WAVE UnitOcc 			= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitOcc")
	NVAR gUnita			= $("root:StrucSims:P1UnitCell:" + P1Name + ":gUnita")
	NVAR gUnitb			= $("root:StrucSims:P1UnitCell:" + P1Name + ":gUnitb")
	NVAR gUnitc			= $("root:StrucSims:P1UnitCell:" + P1Name + ":gUnitc")
	NVAR gAlpha			= $("root:StrucSims:P1UnitCell:" + P1Name + ":gAlpha")
	NVAR gBeta				= $("root:StrucSims:P1UnitCell:" + P1Name + ":gBeta")
	NVAR gGamma			= $("root:StrucSims:P1UnitCell:" + P1Name + ":gGamma")
	
	if (P1ExportType == 1)
		Print " *** Saving the P1 information for",P1Name,"in Cartesian coordinates"
		WAVE UnitXYZ 	= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitXYZ")
		ExportP1File(UnitXYZ,UnitOcc,UnitTag,P1ExportName,".xyz",P1EOLFlag)
	
	elseif (P1ExportType == 2)
		Print " *** Saving the P1 information for",P1Name,"in Crystallographic coordinates"
		WAVE UnitXYZ 	= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitABC")
		ExportP1File(UnitXYZ,UnitOcc,UnitTag,P1ExportName,".abc",P1EOLFlag)
		
	elseif (P1ExportType == 3)
		Print " *** Saving the P1 information for",P1Name,"in the PDF Gui structure format"
		WAVE UnitABC 	= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitABC")
		ExportPDFGuiFile(UnitABC,UnitOcc,UnitTag,P1ExportName,P1SpaceGroup,".stru",gUnita,gUnitb,gUnitc,gAlpha,gBeta,gGamma,P1EOLFlag)
		
	elseif (P1ExportType == 4)
		Print " *** Saving the P1 information for",P1Name,"in the CrystalMaker P1 CIF format"
		WAVE UnitABC 	= $("root:StrucSims:P1UnitCell:" + P1Name + ":UnitABC")
		ExportXtlCIFFile(UnitABC,UnitOcc,UnitTag,UnitElement,P1ExportName,P1SpaceGroup,".cif",gUnita,gUnitb,gUnitc,gAlpha,gBeta,gGamma,P1EOLFlag)
	endif
End



// ***************************************************************************
// *********** 	Export Unit Cell information in the CrystalMaker coordinate
// ***************************************************************************
Function ExportP1File(UnitXYZ,UnitOcc,UnitTag,ExportName,Suffix,EOLFlag)
	Wave UnitXYZ, UnitOcc
	Wave /T UnitTag
	String ExportName, Suffix
	Variable EOLFlag
	
	String AtomTag, PosnLine, AtomFmt, CoordFmt, CoordStr, CoordEOL
	Variable refNum, i, j, Line=1, CoordPad
	Variable NAtoms 	= DimSize(UnitXYZ,0)
	
	Print " *** The P1 unit cell has",NAtoms,"atoms. "
	
	// Open a text file for writing
	Open /Z/T="TEXT" /P=XYZPath refNum as ExportName+Suffix
	
	// Title line
	fprintf refNum, "%d\r\n", NAtoms
	fprintf refNum, "%s\r\n", ""
	
	// Formatting instructions
	AtomFmt 	= "%s"
	CoordPad	= 8
	CoordFmt 	=  "% 0.4#f"
	CoordEOL 	= "%s" + ReturnEOLCharacter(EOLFlag,0)
	
	for (i=0;i<NAtoms;i+=1)
		// The atom name
		AtomTag 	=  ReturnElementOrSite(1,UnitTag[i])
		fprintf refNum, "%s", AtomTag
		
		// The x,y,z coordinates
		sprintf CoordStr, CoordFmt, UnitXYZ[i][0]
		PosnLine = FrontPadString(CoordStr," ",CoordPad)
		
		sprintf CoordStr, CoordFmt, UnitXYZ[i][1]
		PosnLine += FrontPadString(CoordStr," ",CoordPad)
		
		sprintf CoordStr, CoordFmt, UnitXYZ[i][2]
		PosnLine += FrontPadString(CoordStr," ",CoordPad)
		
		fprintf refNum, CoordEOL, PosnLine
	endfor
	
	Close refNum
End

// ***************************************************************************
// *********** 	Export Unit Cell information in the CrystalMaker CIF format
// ***************************************************************************
Function ExportXtlCIFFile(UnitABC,UnitOcc,UnitTag,UnitElement,ExportName,SpaceGroup,Suffix,a,b,c,alp,bet,gam,EOLFlag)
	Wave UnitABC, UnitOcc
	Wave /T UnitTag, UnitElement
	String ExportName, SpaceGroup, Suffix
	Variable a,b,c,alp,bet,gam,EOLFlag
	
	String AtomTag, PosnLine, AtomFmt, CoordFmt, CoordStr, EOLChar, CIFLine, LineEOLFmt
	Variable refNum, i, j, Line=1, CoordPad
	Variable NAtoms = DimSize(UnitABC,0)
	
	Print " *** The P1 unit cell has",NAtoms,"atoms. "
	
	// Open a text file for writing
	Open /Z/T="TEXT" /P=XYZPath refNum as ExportName+Suffix
	
	EOLChar 		= ReturnEOLCharacter(EOLFlag,1)
	LineEOLFmt 	= "%s" + ReturnEOLCharacter(EOLFlag,0)
	
	// Title lines
	fprintf refNum, LineEOLFmt, "_audit_creation_method         'generated by CrystalMaker 7.1.2'"
	sprintf CIFLine, "%s %1.4f", "_cell_length_a                   ", a
	fprintf refNum, LineEOLFmt, CIFLine
	sprintf CIFLine, "%s %1.4f", "_cell_length_b                   ", b
	fprintf refNum, LineEOLFmt, CIFLine
	sprintf CIFLine, "%s %1.4f", "_cell_length_c                   ", c
	fprintf refNum, LineEOLFmt, CIFLine
	
	sprintf CIFLine, "%s %1.4f", "_cell_angle_alpha                   ", alp
	fprintf refNum, LineEOLFmt, CIFLine
	sprintf CIFLine, "%s %1.4f", "_cell_angle_beta                   ", bet
	fprintf refNum, LineEOLFmt, CIFLine
	sprintf CIFLine, "%s %1.4f", "_cell_angle_gamma                   ", gam
	fprintf refNum, LineEOLFmt, CIFLine
	fprintf refNum, LineEOLFmt, ""
	
	// The space group
	fprintf refNum, LineEOLFmt,"_symmetry_space_group_name_H-M     'P 1'"
	fprintf refNum, LineEOLFmt,"_symmetry_Int_Tables_number         1"
	fprintf refNum, LineEOLFmt,"_symmetry_cell_setting             triclinic"
	fprintf refNum, LineEOLFmt,"loop_"
	fprintf refNum, LineEOLFmt,"_symmetry_equiv_pos_as_xyz"
	fprintf refNum, LineEOLFmt,"'+x,+y,+z'"
	fprintf refNum, LineEOLFmt, ""
	
	fprintf refNum, LineEOLFmt,"loop_"
	fprintf refNum, LineEOLFmt,"_atom_site_type_symbol"
	fprintf refNum, LineEOLFmt,"_atom_site_label"
	fprintf refNum, LineEOLFmt,"_atom_site_fract_x"
	fprintf refNum, LineEOLFmt,"_atom_site_fract_y"
	fprintf refNum, LineEOLFmt,"_atom_site_fract_z"
	
	for (i=0;i<NAtoms;i+=1)
		AppendCIFAtomPosition(UnitABC,UnitTag,UnitElement,refNum,i,EOLFlag)
	endfor
	
	Close refNum
End

Function AppendCIFAtomPosition(UnitABC,UnitTag,UnitElement,refNum,n,EOLFlag)
	Wave UnitABC
	Wave /T UnitTag, UnitElement
	Variable refNum, n, EOLFlag
	
	Variable CoordPad
	String AtomTag, CoordStr, CoordFmt, LineEOLFmt, OccStr, PosnLine
	
	// Formatting instructions
	CoordPad		= 10
	CoordFmt 		=  "% 0.4#f"
	LineEOLFmt 	= "%s" + ReturnEOLCharacter(EOLFlag,0)
	
	// The element name
	PosnLine 	= "  " + PadString(UnitElement[n],7,0x20)
	
	// The site tag
	PosnLine 	+= PadString(UnitTag[n],8,0x20)
	
	// The x,y,z coordinates
	sprintf CoordStr, CoordFmt, UnitABC[n][0]
	PosnLine += PadString(CoordStr,CoordPad,0x20)
	
	sprintf CoordStr, CoordFmt, UnitABC[n][1]
	PosnLine += PadString(CoordStr,CoordPad,0x20)
	
	sprintf CoordStr, CoordFmt, UnitABC[n][2]
	PosnLine += PadString(CoordStr,CoordPad,0x20)
	
	fprintf refNum, LineEOLFmt, PosnLine
End

// ***************************************************************************
// *********** 	Export Unit Cell information in the PDF Gui .stru format
// ***************************************************************************
Function ExportPDFGuiFile(UnitXYZ,UnitOcc,UnitTag,ExportName,SpaceGroup,Suffix,a,b,c,alp,bet,gam,EOLFlag)
	Wave UnitXYZ, UnitOcc
	Wave /T UnitTag
	String ExportName, SpaceGroup, Suffix
	Variable a,b,c,alp,bet,gam,EOLFlag
	
	String AtomTag, PosnLine, AtomFmt, CoordFmt, CoordStr, EOLChar, LineEOLFmt
	Variable refNum, i, j, Line=1, CoordPad
	Variable NAtoms = DimSize(UnitXYZ,0)
	
	Print " *** The P1 unit cell has",NAtoms,"atoms. "
	
	// Open a text file for writing
	Open /Z/T="TEXT" /P=XYZPath refNum as ExportName+Suffix
	
	EOLChar 		= ReturnEOLCharacter(EOLFlag,1)
	LineEOLFmt 	= "%s" + ReturnEOLCharacter(EOLFlag,0)
	
	String /G gTitleLine
	Variable /G gPDFGuiSharp1, gPDFGuiSharp2, gPDFGuiSharp3, gPDFGuiSharp4
	
	String TitleLine 	= StrVarOrDefault("root:StrucSims:Export:gTitleLine","")
	Prompt TitleLine, "Description of structure (optional)"
	Variable Sharp1 	= NumVarOrDefault("root:StrucSims:Export:gPDFGuiSharp1",1.9)
	Prompt Sharp1, "Sharpening 1"
	Variable Sharp2 	= NumVarOrDefault("root:StrucSims:Export:gPDFGuiSharp2",0)
	Prompt Sharp2 "Sharpening 2"
	Variable Sharp3 	= NumVarOrDefault("root:StrucSims:Export:gPDFGuiSharp3",1)
	Prompt Sharp3, "Sharpening 3"
	Variable Sharp4 	= NumVarOrDefault("root:StrucSims:Export:gPDFGuiSharp4",4.2)
	Prompt Sharp4, "Sharpening 4"
	DoPrompt "Exporting a structure in DISCUS format", TitleLine, Sharp1, Sharp2, Sharp3, Sharp4
	if (V_flag)
		Close refNum
		return 0
	endif
	gTitleLine			= TitleLine
	gPDFGuiSharp1 	= Sharp1
	gPDFGuiSharp2 	= Sharp2
	gPDFGuiSharp3 	= Sharp3
	gPDFGuiSharp4 	= Sharp4
	
	// Title lines
	fprintf refNum, LineEOLFmt, PadString("title",6,0x20)+TitleLine
	fprintf refNum, LineEOLFmt, PadString("format",6,0x20)+"pdffit"
	fprintf refNum, LineEOLFmt, PadString("scale",6,0x20)+"1.000000"
	
//	String SharpStr1, SharpStr2, SharpStr3, SharpStr4
//	sprintf SharpStr1, "%0.6#f", Sharp1
//	sprintf SharpStr2, "%0.6#f", Sharp2
//	sprintf SharpStr3, "%0.6#f", Sharp3
//	sprintf SharpStr4, "%0.6#f", Sharp4
//	fprintf refNum, LineEOLFmt, PadString("sharp",6,0x20)   1.903010,  0.000000,  1.000000,  4.200000"
	
	// The PDF sharpening parameters
	fprintf refNum, "%s    %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f"+EOLChar, "sharp",Sharp1, Sharp2, Sharp3, Sharp4
	
	// The space group
	fprintf refNum, "%s   %s"+EOLChar, "spcgr", SpaceGroup
	
	// The cell dimensions
	fprintf refNum, "%s    %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f"+EOLChar, "cell",a,b,c,alp,bet,gam
	
	// unknown
	fprintf refNum, "%s   %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f,  %0.6#f"+EOLChar, "dcell",0.0,0.0,0.0,0.0,0.0,0.0
	
	// Supercell dimensions and number of atoms. 
	fprintf refNum, "%s           %d,        %d,        %d,        %d"+EOLChar, "ncell",1,1,1,NAtoms
	
	fprintf refNum, LineEOLFmt, "atoms"
	
	for (i=0;i<NAtoms;i+=1)
		AppendAtomPosition(UnitXYZ,UnitOcc,UnitTag,refNum,i,EOLFlag)
		AppendZeroThermalFactors(refNum,1,3,0.0)
		AppendZeroThermalFactors(refNum,4,3,-1)
	endfor
	
	Close refNum
End

Function AppendAtomPosition(UnitXYZ,UnitOcc,UnitTag,refNum,n,EOLFlag)
	Wave UnitXYZ, UnitOcc
	Wave /T UnitTag
	Variable refNum, n, EOLFlag
	
	Variable CoordPad
	String AtomTag, CoordStr, CoordFmt, LineEOLFmt, OccStr, PosnLine
	
	// Formatting instructions
	CoordPad		= 18
	CoordFmt 		=  "% 0.8#f"
	LineEOLFmt 	= "%s" + ReturnEOLCharacter(EOLFlag,0)
	
	// The atom name
	AtomTag 	=  PadString(UpperStr (ReturnElementOrSite(1,UnitTag[n])),4,0x20)
	fprintf refNum, "%s", AtomTag
	
	// The x,y,z coordinates
	sprintf CoordStr, CoordFmt, UnitXYZ[n][0]
	PosnLine = FrontPadString(CoordStr," ",CoordPad)
	
	sprintf CoordStr, CoordFmt, UnitXYZ[n][1]
	PosnLine += FrontPadString(CoordStr," ",CoordPad)
	
	sprintf CoordStr, CoordFmt, UnitXYZ[n][2]
	PosnLine += FrontPadString(CoordStr," ",CoordPad)
	
	// The occupancy
	if (WaveExists(UnitOcc))
		sprintf OccStr, "% 0.4#f", UnitOcc[n]
	else
		sprintf OccStr, "% 0.4#f", 1.0
	endif
	PosnLine += FrontPadString(OccStr," ",13)
	
	fprintf refNum, LineEOLFmt, PosnLine
End

Function AppendZeroThermalFactors(refNum,NLines,NCols,LastColVal)
	Variable refNum,NLines,NCols,LastColVal
	
	Variable i, j
	String ZeroStr, ZeroLine=""
	
	for (j=0; j<NLines; j+=1)
		sprintf ZeroStr, "% 0.8#f", 0.0
		ZeroLine = FrontPadString(ZeroStr," ",22)
		
		for(i=1;i<NCols;i+=1)
			ZeroLine += FrontPadString(ZeroStr," ",18)
		endfor
		
		if (LastColVal > -1)
			sprintf ZeroStr, "% 0.4#f", LastColVal
			ZeroLine += FrontPadString(ZeroStr," ",13)
		endif
		
		fprintf refNum, "%s\r\n", ZeroLine
	endfor
End







	