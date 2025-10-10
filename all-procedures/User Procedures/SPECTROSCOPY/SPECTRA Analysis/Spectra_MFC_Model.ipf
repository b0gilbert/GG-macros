#pragma rtGlobals=1		// Use modern global access method.

Menu "Spectra"
	SubMenu "Electrochemistry"
		"New Biofilm"
		"Display A Biofilm"
		"Biofilm Calculation"
		"Delete A Biofilm"
	End
End

Function BiofilmCalculation()
	
	String Biofilm	= ChooseABiofilm(1)
	if (strlen(Biofilm) == 0)
		return 0
	endif
	
	String Calculation 	= GetBiofilmCalculationType(Biofilm)
	
	strswitch (Calculation)
		case "Chrono":
			Print " 		*** Run a chronoamperometry simulation for biofilm",Biofilm
			BiofilmChronoAmp(Biofilm)
			break
		default:
			Print " 		*** No calculation type chosen. "
	endswitch
	
	SetDataFolder root:
End

Function DeleteABiofilm()

	String Biofilm	= ChooseABiofilm(0)
	if (strlen(Biofilm) == 0)
		return 0
	endif
	
	DeleteBiofilmFolder(Biofilm)
End

Function DisplayABiofilm()

	String Biofilm	= ChooseABiofilm(0)
	if (strlen(Biofilm) == 0)
		return 0
	endif
	
	DisplayBiofilm(Biofilm)
End



// ********************************************************************
// ********		Plot routines to display Biofilm concentration profiles
// ******************************************************************** 
Function DisplayBiofilm(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	
End

// ********************************************************************
// ********		Specific Simulation Types
// ******************************************************************** 

Function BiofilmChronoAmp(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	Variable /G gdT, gDuration, gEa
	Variable dT=gdT
	Prompt dT, "Time step (s)"
	Variable Duration=gDuration
	Prompt Duration, "Simulation duration (mins)"
	Variable Ea=gEa
	Prompt Ea, "Anode potential (vs SHE)"
	DoPrompt "Chrono-amperometry parameters", dT, Duration, Ea
	if (V_flag)
		return 0
	endif
	
	gdT 			= dT
	gEa 			= Ea
	gDuration 	= Duration
	
	if (GetEChemParameters(Biofilm) == 0)
		return 0
	endif
	if (GetDiffusionParameters(Biofilm) == 0)
		return 0
	endif
	
	// Variables to keep track of what happened during a single simulation run. 
	//** May be best to put all these into a single wave **
	Variable CAcAvg=0		// The average acetate concentration in the biofilm
	Variable qAnode=0		// The total amount of charge transferred to the anode. 
	
	Variable NSteps 	= (60*Duration)/dT
	
	BiofilmMetabolism(Biofilm,1,NSteps,Ea,dT,CAcAvg, qAnode)

End

// ********************************************************************
// ********		Tyler: The next 3 functions are the important ones. 
// ******************************************************************** 

// 	This is the main function to allow biofilm metabolism to continue at anode potential Ea to a predetermined point. 
// 	The contents of the Biofilm folder are taken as the initial conditions. 
// 	The calling routine sets the time step and anode potential. 
Function BiofilmMetabolism(Biofilm,EndChoice,EndVariable,Ea,dt,CAcAvg, qAnode)
	String Biofilm
	Variable EndChoice, EndVariable, Ea, dt, &CAcAvg, &qAnode
	
	// The concentrations in bulk medium
	NVAR gCAc 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCAc")
	NVAR gpH 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gpH")
	NVAR gCBuff 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCBuff")
	NVAR gCMed 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCMed")
	
	// The diffusion coefficients in the biofilm
	NVAR gDAc 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gDAc")
	NVAR gDProt 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gDProt")
	NVAR gDBuff 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gDBuff")
	NVAR gDMed 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gDMed")
	
	// The biofilm parameters
	NVAR gSurface 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gSurface")
	NVAR gThick 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gThick")
	NVAR gCCell 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCCell")
	
	// The acetate metabolism rate constants
	NVAR gKcat 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gKcat")
	NVAR gKmed 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gKred")
	NVAR gKM 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gKm")
	
	// Anode charge transfer parameters
	NVAR gEo 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gEo")
	NVAR gKbv 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gKbv")
	
	// The concentration waves
	WAVE Protons 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":Protons")
	WAVE pH 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":pH")
	WAVE Acetate	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":Acetate")
	WAVE Buffer	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":Buffer")
	WAVE Biomass	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":Biomass")
	WAVE MedTot	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":MedTot")
	WAVE MedRed	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":MedRed")
	WAVE MedOx	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":MedOx")
	WAVE CO2		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":CO2")
	
	Variable dQ, dx, Nx, CProt, nT=0, stop=0
	Nx 		= DimSize(Acetate,0)		// Number of x points
	dx 		= DimDelta(Acetate,0)			// x step
	CProt 	= pHtoConc(gpH)
	
	Variable nTUpdate=100
	
	//?? *!*!*!*!   Debugging
	Acetate 	= 10
	MedTot 	= gCMed
	MedOx 	= gCMed
	MedRed 	= 0
	Biomass = 1
	CO2 = 0
	Protons = CProt
	
	// Initialization. Prepare the B- and A-matrices
	// The B-matrix is reused. It will contain the concentration of each species
	Make /O/D/N=(Nx,0) BMatrix=0
	
	// The A-matrices describe how diffusion and other processes affect the local concentrations. 
	Make /O/D/N=(Nx,Nx) AMAc, AMProt, AMBuff, AMRed
	MakeDiffusionMatrix(AMAc,dx,dt,gDAc,gCAc,-1)
	MakeDiffusionMatrix(AMProt,dx,dt,gDProt,CProt,-1)
	MakeDiffusionMatrix(AMBuff,dx,dt,gDBuff,gCBuff,-1)
	MakeDiffusionMatrix(AMRed,dx,dt,gDMed,-1,-1)
	
	// A temporary matrix to record the change in acetate concentration at each time step. 
	Make /O/D/N=(Nx) dAc=0
	
	// Make some arrays to follow changes in parameters 
	Make /O/D/N=(10000) TrendMedRed=NaN, TrendMedOx=NaN, TrendAc=NaN, TrendpH=NaN
	do
		// Step 1. Acetate consumption
		MetabolismTimeStep(dAc,Acetate,Biomass,MedOx,Protons,dt,gKcat,gKmed,gKm)
		CAcAvg 	= area(Acetate)/gThick
	
		// Step 2. Change the concentrations of all relevant species
		Acetate 		-= dAc
		Protons 	+= 8 * dAc
		CO2 		+= 2 * dAc
		
		// MedOx is not changed in MetabolismTimeStep(), but is changed below ... 
		MedRed 		+= 8 * dAc
		
		// Step 3. (Optionally) buffer any pH change
		
		// Step 4. Diffusion
		if(0)
		DiffusionTimeStep(Acetate,AMAc,BMatrix)
		DiffusionTimeStep(Protons,AMProt,BMatrix)
		DiffusionTimeStep(Buffer,AMBuff,BMatrix)
		DiffusionTimeStep(MedRed,AMRed,BMatrix)
		endif
		
		MedOx 	= MedTot - MedRed
		
		// Step 5. Electron transfer TO the anode is (i.e., oxidation of mediator) positive
		if (0)
		dQ 		= gSurface * ElectrodeChargeTransfer(Ea,gEo,gKbv,1,MedOx[Nx-1],MedRed[Nx-1],dt)
		MedRed[Nx-1] 	-= dQ
		MedOx[Nx-1] 	+= dQ
		qAnode += dQ
		endif
		
		// Step 6. Stopping criteria
		switch (EndChoice)
			case 1:
				stop = (nT > EndVariable) ? 1 : 0
				break
			case 2:
				stop = (qAnode > EndVariable) ? 1 : 0
				break
		endswitch
		
		// Track some changes through the simulation. 
		TrendMedRed[nT] = MedRed[0]
		TrendMedOx[nT] = MedOx[0]
		TrendAc[nT] = Acetate[0]
		TrendpH[nT] = ConcTopH(Protons[0])
		
		nT += 1
		if (mod(nT,nTUpdate)==0)
		
			DoUpdate
		endif
	while(!stop)
End

// Calculate the change in the acetate concentration.
// Problem: The expression allows more acetate consumption than there are oxidized mediators. 
Function MetabolismTimeStep(dAc,Acetate,Biomass,MedOx,Protons,dt,Kcat,Kmed,KM)
	Wave dAc,Acetate,Biomass,MedOx,Protons
	Variable dt,Kcat,Kmed,Km
	
	Variable MedOxExp, LastMedOx, FirstMedOx, small=1e-8
	
	dAc[] 	= ((dt/8)*Kcat*Biomass[p]) / (1 + Kcat/(Kmed*MedOx[p]) + KM/(8*Acetate[p]))
	
//	dAc[] 	= max(dAc[p],8*MedOx[p]+small)
//	dAc[] 	= max(dAc[p],0)
	
	MedOxExp 	= Kcat/(Kmed*MedOx[0])
//	LastMedOx 	= MedOx[numpnts(MedOx)-1]
//	FirstMedOx 	= MedOx[0]
End

//Function MetabolismStep(Acetate,Biomass,MedOx,Protons,dt,Kcat,Kmed,KM)
//	Wave Acetate, MedOx
//	Variable Biomass,Protons
//	Variable dt,Kcat,Kmed,Km
//	
//	Variable MedOxExp, LastMedOx, FirstMedOx, small=1e-8
//	Variable denom, numer, dAc2
//	
//	numer	= dt*Kcat*Biomass
//	denom 	= 1 + Kcat/(Kmed*MedOx) + KM/(8*Acetate)
//	dAc2 	= numer/denom
//	
//	return dAc2/8
//End

// The net transferred charge in mmoles per unit area. 
Function ElectrodeChargeTransfer(Ea,Eo,Kbv,n,Cox,Cred,dt)
	Variable Ea, Eo, Kbv, n, Cox, Cred, dt
	
	Variable alp	 = 0.5 						// Note fixed alpha here
	Variable f 	= cFaraday/(cR * 298) 	// Note fixed temperature here. 
	
	Variable ExpOx 		= exp((1-alp) * f * (Ea-Eo))
	Variable ExpRed 	= exp(-alp * f * (Ea-Eo))
	Variable CoxP 		= Cox^(1-alp)
	Variable CredP	 	= Cred^alp
	Variable ii0 		= n * Kbv * CoxP * CredP
	
	// Positive value means more electrons are transferred to the anode from the mediator
	Variable ii 			= dt * ii0 * (ExpOx-ExpRed)/(1 + CredP*ExpOx + CoxP*ExpRed)
	
//	Variable ii 			= dt * ii0 * (-ExpRed)/(1 + CoxP*ExpRed)
//	Variable ii 			= dt * ii0 * (ExpOx)/(1 + CredP*ExpOx)
	
	return ii
End

// 	This is the N x N matrix in the equation A x X = B
// 	X are the unknowns at time n+1
//	B are the known values at time n
Function MakeDiffusionMatrix(AMatrix,dx,dt,D,C0,CN)
	Wave AMatrix
	Variable ,dx,dt,D,C0,CN
	
	Variable i, NPts=Dimsize(AMatrix,0)
	Variable a = (dt*D)/(dx^2)
	
	AMatrix 	= 0
	
	// Treat the edges separately
	for (i=1;i<NPts-1;i+=1)
		AMatrix[i][i-1] 	= -a		
		AMatrix[i][i+1] 	= -a
		AMatrix[i][i] 		= (1 + 2*a)
	endfor
	
	// Boundary conditions at LEFT side
	if (C0 < 0)
		//Zero gradient
		AMatrix[0][0] 		= (1 + 2*a)
		AMatrix[0][1] 		= -2*a
	else
		// Constant value
		AMatrix[0][0] 		= 1
		AMatrix[0][1] 		= 0
	endif
	
	// Boundary conditions at RIGHT side
	if (CN < 0)
		//Zero gradient
		AMatrix[NPts-1][NPts-1] 		= (1 + 2*a)
		AMatrix[NPts-1][NPts-2] 		= -2*a
	else
		// Constant value
		AMatrix[NPts-1][NPts-1] 		= 1
		AMatrix[NPts-1][NPts-2] 		= 0
	endif
End

// 	A single diffusion step using fully implicit discretization scheme
// 	The time step, dt, is contained in the A-matrix values. 
Function DiffusionTimeStep(Concentration,AMatrix,BMatrix)
	Wave Concentration,AMatrix,BMatrix
	
	// Write the values at time n into the B matrix
	BMatrix[][0] 	= Concentration[p]	
	
	// Tridiagonal matrix 
	MatrixLinearSolve /M=4 AMatrix, BMatrix
	
	// The results (values at time n+1) are recorded in this new array
	WAVE M_B = M_B
	
	// Overwrite the initial values
	Concentration[] 		= M_B[p][0]
End

Function MakeBiofilmArrays(Biofilm)
	String Biofilm
	
	NVAR gThick 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gThick")
	NVAR gpH 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gpH")
	NVAR gCAc 		= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCAc")
	NVAR gCBuff 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCBuff")
	NVAR gCMed 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCMed")
	NVAR gCCell 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCCell")
	
	// Calculate the array dimensions, based on the biofilm thickness
	// Make sure that the thickness is a multiple of z-axis step. 
	Variable dZ=1, nZ
	nZ 		= ceil(gThick/dZ)
	gThick 	= nZ * dZ	
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
		
		// The 
		Make /O/D/N=(nZ) Biomass, Protons, pH, Acetate, Buffer, MedTot, MedRed, MedOx, CO2
		SetScale /P x, 0, dZ, Biomass, Protons, pH, Acetate, Buffer, MedTot,  MedRed, MedOx, CO2
		
		// Convert the cell density to a 'concentration' in mM
		Biomass 	= (1000000 * gCCell) / cAvogadro 
		
		pH 			= gpH
		Protons 	= pHToConc(gpH)
		Acetate 		= gCAc
		Buffer 		= gCBuff
		MedRed 		= 0
		MedOx 		= gCMed
		MedTot 		= gCMed
		CO2 		= 0
		
	SetDataFolder root:
End

Function pHToConc(pH)
	Variable pH
	
	return 10 ^ (-1*pH)
End
Function ConcTopH(Conc)
	Variable Conc
	
	return -1 * log(Conc)
End

// ********************************************************************
// ********			User Interaction Routines
// ******************************************************************** 

Function /S NewBiofilm()
	
	InitializeElectrochemistry()
	
	// Make a folder for all the biofilm calculations
	String MainBioFilmFolder 	= "root:ELECTROCHEM:Biofilms"
	NewDataFolder /O/S $MainBioFilmFolder
	
	// Make a new folder for a biofilm calculation with a liberal name
	String NewBiofilmName, NewBiofilmFolder
	NewBiofilmName 	= StrVarOrDefault("root:ELECTROCHEM:Biofilms:gBiofilmName","Biofilm 1")
	NewBiofilmName 	= UniqueFolderName(MainBioFilmFolder,NewBiofilmName)
	NewBiofilmName 	= PromptForUserStrInput(NewBiofilmName,"New biofilm name","Please enter a name for the new biofilm")
	if (cmpstr("_quit!_",NewBiofilmName) == 0)
		return ""
	endif
	NewBiofilmName 	= UniqueFolderName(MainBioFilmFolder,NewBiofilmName)
	
	String /G root:ELECTROCHEM:Biofilms:gBiofilmName = NewBiofilmName
	NewDataFolder /O/S $(ParseFilePath(2,MainBioFilmFolder,":",0,0) + PossiblyQuoteName(NewBiofilmName))
		
		GetMediaParameters(NewBiofilmName)
		
		GetBiofilmParameters(NewBiofilmName)
		
		MakeBiofilmArrays(NewBiofilmName)
		
		Print " 		*** Created a new biofilm calculation titled: ", NewBiofilmName
	
	SetDataFolder root:
	
	return NewBiofilmName
End

Function /S DuplicateABiofilm(BiofilmName)
	String BiofilmName
	
	SVAR gBiofilmName 			= root:ELECTROCHEM:Biofilms:gBiofilmName
	
	// Make a new folder for a biofilm calculation with a liberal name
	String BiofilmFolder, NewBiofilmName, NewBiofilmFolder, MainBioFilmFolder 	= "root:ELECTROCHEM:Biofilms"
	NewBiofilmName 	= UniqueFolderName(MainBioFilmFolder,BiofilmName)
	NewBiofilmName 	= PromptForUserStrInput(NewBiofilmName,"Duplicate biofilm "+BiofilmName,"Please enter a name for the duplicate biofilm")
	if (cmpstr("_quit!_",NewBiofilmName) == 0)
		return ""
	endif
	NewBiofilmName 	= UniqueFolderName(MainBioFilmFolder,NewBiofilmName)
	
	BiofilmFolder 		= ParseFilePath(2,MainBioFilmFolder,":",0,0) + PossiblyQuoteName(BiofilmName)
	NewBiofilmFolder 	= ParseFilePath(2,MainBioFilmFolder,":",0,0) + PossiblyQuoteName(NewBiofilmName)
	
	NewDataFolder /O $(ParseFilePath(2,MainBioFilmFolder,":",0,0) + PossiblyQuoteName(NewBiofilmName))
		
	DuplicateAllWavesInDataFolder(BiofilmFolder,NewBiofilmFolder,"*",0)
	DuplicateAllVarsInDataFolder(BiofilmFolder,NewBiofilmFolder,"*",1)
	
	Print " 		*** Created a duplicate biofilm calculation titled: ", NewBiofilmName
	
	SetDataFolder root:
	
	// Update the global record of chosen biofilm
	gBiofilmName 	= NewBiofilmName
	
	return NewBiofilmName
End

Function /S ChooseABiofilm(NewFlag)
	Variable NewFlag

	String MainBioFilmFolder 	= "root:ELECTROCHEM:Biofilms"
	SVAR gBiofilmName 			= root:ELECTROCHEM:Biofilms:gBiofilmName
	gBiofilmName 				= ChooseAFolder(MainBioFilmFolder,gBiofilmName,"List of biofilms","Choose a biofilm",NewFlag)
	
	if (cmpstr(gBiofilmName,"new") == 0)
		gBiofilmName 	= NewBiofilm()
	endif
	
	return gBiofilmName
End

// If the chosen biofilm is duplicated, the name of the chosen biofilm will change
Function /S GetBiofilmCalculationType(BiofilmName)
	String &BiofilmName
	
	SetDataFolder root:ELECTROCHEM:Biofilms
	
	String PopupStr 	= "no - use "+BiofilmName+";yes - copy "+BiofilmName+";"
			
	String BiofilmCalc = StrVarOrDefault("root:ELECTROCHEM:Biofilms:gBiofilmCalc","Chrono")
	Prompt BiofilmCalc, "Choose a simulation type", popup, "Chrono;CV;Diffusion;"
	Variable NewBiofilm = 1
	Prompt NewBiofilm, "New biofilm?", popup, PopupStr
	DoPrompt "Choose a simulation type", BiofilmCalc, NewBiofilm
	if (V_flag)
		return ""
	endif
	
	String /G gBiofilmCalc 	= BiofilmCalc
	
	if (NewBiofilm == 2)
		BiofilmName 	= DuplicateABiofilm(BiofilmName)
	endif
	
	return BiofilmCalc
End

Function GetMediaParameters(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	Variable /G gCAc, gpH, gCBuff, gCMed, gCCell, gThick
	Variable CAc=gCAc, pH=gpH, CBuff=gCBuff
	Prompt CAc, "Acetate concentration [mM]"
	Prompt pH, "pH"
	Prompt CBuff, "Buffer concentration [mM]"
	DoPrompt "Media parameters", CAc, pH, CBuff
	if (V_flag)
		return 0
	endif
	
	gCAc 	= CAc
	gpH 	= pH
	gCBuff 	= CBuff
End

Function GetBiofilmParameters(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	Variable /G gCMed, gCCell, gThick, gSurface
	Variable CMed=gCMed, CCell=gCCell, Thick=gThick, SA=gSurface
	Prompt CMed, "Mediator concentration [mM]"
	Prompt CCell, "Cell concentration [cells per mL]"
	Prompt Thick, "Biofilm thickness [µm]"
	Prompt SA, "Biofilm area [cm3]"
	DoPrompt "Initial biofilm conditions", CMed, CCell, Thick, SA
	if (V_flag)
		return 0
	endif
	
	gCMed 	= CMed
	gCCell 	= CCell
	gThick 	= Thick
	gSurface = SA
End

Function GetEChemParameters(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	Variable /G gKcat,gKmed, gKred,gKox, gKM, gEo, gKbv
	Variable Kcat=gKcat, Kmed=gKmed, Kred=gKred, Kox=gKox, KM=gKM, Eo=gEo, Kbv=gKbv
	
	Prompt Kcat, "Rate of catalytic acetate consumption [/s]"
	Prompt KM, "Microbial acetate affinity [mole/mL]"
	Prompt Kmed, "Microial mediator reduction [/mole/cm2/s]"	// Just called "k" in Strycharz
	
	Prompt Kred, "k for mediator reduction by anode [/s]"
	Prompt Kox, "k mediator oxidation by anode [/s]"
	
	Prompt Eo, "Redox potential of mediator [V vs SHE]"
	Prompt Kbv, "Butler-Volmer constant [/s]"
	
//	DoPrompt "Rate constants etc", Kcat,Kmed,Kred,Kox, KM, Eo,Kbv
	DoPrompt "Rate constants etc", Kcat,Kmed, KM, Eo,Kbv
	if (V_flag)
		return 0
	endif
	
	gKcat 	= Kcat
	gKmed 	= Kmed
	gKM 	= KM
	
	gKred 	= Kred
	gKox 	= Kox
	
	gEo 		= Eo
	gKbv 	= Kbv
End

Function GetDiffusionParameters(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	Variable /G gDAc,gDProt,gDBuff,gDMed
	Variable DAc=gDAc, DProt=gDProt, DBuff=gDBuff, DMed=gDMed
	
	Prompt DAc, "Diffusion coefficient for acetate [cm2/s]"
	Prompt DProt, "Diffusion coefficient for protons [cm2/s]"
	Prompt DBuff, "Diffusion coefficient for buffer [cm2/s]"
	Prompt DMed, "Diffusion coefficient for mediator [cm2/s]"
	
	DoPrompt "Diffusion coefficients", DAc,DProt,DBuff,DMed
	if (V_flag)
		return 0
	endif
	
	gDAc 	= DAc
	gDProt 	= DProt
	gDBuff 	= DBuff
	gDMed 	= DMed
End

Function DeleteBiofilmFolder(Biofilm)
	String Biofilm
	
	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
		KillWaves /A/Z
		KillVariables /A/Z
		KillDataFolder /Z $""
		if (V_flag != 0)
			print " 		*** Attempted to delete the biofilm folder",Biofilm,"but one or more data waves must be displayed. "
		endif
	SetDataFolder root:
End








































//Function GetCalculationParameters(Biofilm)
//	String Biofilm
//	
//	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
//	
//	Variable /G gDT, gEndChoice, gEndNT, gEndNQ, gEndDI
//	Variable EndNT = gEndNT, EndNQ=gEndNQ, EndDI=gEndDI
//			
//	Variable dT = gDT
//	Prompt dT, "Time step size [s]"
//	Variable Endchoice = gEndChoice
//	Prompt EndChoice, "Stopping criterion", popup, "# time steps;transferred charge;stable current;"
//	DoPrompt "Calculation parameters", dT, EndChoice
//	if (V_flag)
//		return 0
//	endif
//	
//	gDT 		= dT
//	gEndChoice 	= EndChoice
//	
//	switch (EndChoice)
//		case 1: 
//			gEndNT 	= PromptForUserVarInput(gEndNT,"Number of time steps","Enter stopping criterion")
//			break
//		case 2: 
//			gEndNQ 	= PromptForUserVarInput(gEndNQ,"Charge transferred","Enter stopping criterion")
//			break
//		case 3: 
//			gEndDI 	= PromptForUserVarInput(gEndDI,"Change in current","Enter stopping criterion")
//			break
//	endswitch
//End









// ********************************************************************
// ********			This was a test diffusin routine. 
// ******************************************************************** 

Function TestBiofilmDiffusionRoutine(Biofilm)
	String Biofilm
	
	Variable i, dx, D, Nx

	SetDataFolder $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm))
	
	NVAR gDT 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gDT")
	NVAR gNT 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gNT")
	NVAR gCAc 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":gCAc")
	WAVE Ac 	= $("root:ELECTROCHEM:Biofilms:" + PossiblyQuoteName(Biofilm)+":Acetate")
	
	D 	= .1				// diffusion coef.
	Nx 	= DimSize(Ac,0)	// Number of x points
	dx 	= DimDelta(Ac,0)	// x step
	Make /O/D/N=(Nx,Nx) AMatrix=0
	Make /O/D/N=(Nx,0) BMatrix=0
	
	// An initial sinusoidal concentration
	Ac = gCAc * sin(x/4) + 2*gCAc
	Duplicate /O/D Ac, AcetateSave
	
	MakeDiffusionMatrix(AMatrix,dx,gDT,D,20,-1)
	
	for (i=0;i<gNT;i+=1)
		DiffusionTimeStep(Ac,AMatrix,BMatrix)
		if (mod(i,10) == 0)
			DoUpdate /W=Graph0
			sleep /S 0.1
		endif
	endfor
End







// The net transferred charge per unit area. 
// 	** This did not properly consider the LIMITING CURRENT!!
//Function ElectrodeChargeTransfer(Ea,Eo,Kbv,n,Cox,Cred,dt)
//	Variable Ea, Eo, Kbv, n, Cox, Cred, dt
//	
//	Variable kOx, kRed, charge, OxET, RedET
//	Variable alp	 = 0.5 						// Note fixed alpha here
//	Variable f 	= cFaraday/(cR * 298) 				// Note fixed temperature here. 
//	
//	// 	The Bulter-Volmer expressions for the oxidative and reductive charge transfer
//	//	kOx represents oxidation of reduced mediator - should increase as Ea > Eo
//	kOx 	= Kbv * exp((1-alp) * f * (Ea-Eo))
//	kRed 	= Kbv * exp(-alp * f * (Ea-Eo))
//	
//	// Calculate the number of mmoles of electrons transfered between mediator and anode. (So don't need Faraday's constant)
////	charge 	= dt * n * cFaraday * (kOx*Cred - kRed*Cox)
//
//
////	charge 	= dt * n * (kOx*Cred - kRed*Cox)	
//	OxET 	= dt * n * kOx * Cred
//	RedET 	= dt * n * kRed * Cox
//	
//	// Positive value means more electrons are transferred to the anode from the mediator
//	return (OxET - RedET)
//End