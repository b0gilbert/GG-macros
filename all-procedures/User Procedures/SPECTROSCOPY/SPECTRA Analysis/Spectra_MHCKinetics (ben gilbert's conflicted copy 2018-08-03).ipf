#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


Static Constant cFaraday 		= 96485.3365		// Coulombs/mole
Static Constant cR 				= 8.3144621			// J / mol K
Static Constant cBoltzmann 		= 1.380650e-23		// J/K
Static Constant cElectron 		= 1.602176e-19		// C

// Use the same notation as Bard & Faulkner: f = F/RT
Constant cf	= 38.9413


// Good Poise parameters are PsEATime = 100000000 and PsEAdr = 200 (do not go higher)

// Dec 2017:  Consider Anode MHCs to fully equilibrate with applied potential. 
// Then the charge transfered is the flux of electrons from biofilm MHC(s)

Function Initialize_MHC_kinetics()
	
	Variable i, j
	
	NewDataFolder /S/O root:BIOFILM
		NewDataFolder /S/O root:BIOFILM:Globals
		
		// *** Concentrations - now set below
//		Variable /G gC_MHCa	= 1e-3 				// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2
//		Variable /G gC_MHCb	= 1e-3 				// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
//		Variable /G gC_MHCc	= 1e-3 				// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2

		// Multi-heme cytochrome parameters
		Variable /G gMHC_Eo		= -0.05			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
		Variable /G gMHC_dE 		= -0.031			// Increment in MHC redox potential for a unit change in charge state, in V
		Variable /G gMHC_QMax 	= 11 				// # charge states per MHC. Note that 10 hemes = 11 charge states
		
		// *** CRITICAL RATE CONSTANTS
		
		// *** Acetate Respiration and electron transfer to biofilm MHC(s)
		Variable /G gAc_Eo 			= -0.2				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
		Variable /G gAc_L			= 0.8				// Reorganization energy, in eV, for acetate-to-MHC ET
		Variable /G gAc_vK			= 0.1			// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
		
		// *** MHC - to - MHC electron transfer
		Variable /G gMHC_L			= 0.8				// Reorganization energy, in eV, for MHC-to-MHC ET
		Variable /G gMHC_vK		= 0.2 				// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
		
		// *** Anode-MHC to Anode ET -- currently permanent equilbrium so none of these are actually used
		
		// 1D arrays that record the populations of the MHCs with different charge states. 
		Make /O/D/N=(gMHC_QMax) MHC_QQa, MHC_QQb, MHC_QQc
		Make /O/D/N=(gMHC_QMax) MHC_QQt, MHC_QQf=0, MHC_QQr=0
		
		// 2D arrays that record parameters for MHC-to-MHC electron transfer
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_DGab 		// Standard Gibbs free energy for the reaction
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_Kab			// Forward rate constants for the reaction
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_Kba			// Reverse rate constants for the reaction
		
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_DGab 		// Standard Gibbs free energy for the reaction
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_Kab			// Forward rate constants for the reaction
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_Kba			// Reverse rate constants for the reaction
		
		SetScale /P x, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_QQa, MHC_QQb, MHC_QQc, MHC_QQt, MHC_QQf, MHC_QQr, MHC_Kab, MHC_Kba
		SetScale /P y, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_DGab, MHC_Kab, MHC_Kba
		
		// Calculate the Marcus expression for forward and reverse ET rates based on standard DGs for ET
		MHC_MHC_ET_rates(MHC_Kab,MHC_Kba)
		
//		Variable /G gAc_Ko 			= 1e-5				// Prefactor for Acetate-to-MHC electron transfer
//		Variable /G gC_Enz		= 0.0001 			// Fixed concentration of Respiration Enzymes, in moles per liter
//		Variable /G gAc_K1 		= 1					// Rate constant for formation of Acetate--Enzyme complex
//		Variable /G gAc_K2 		= 0.0003				// Rate constant for breakup of Acetate--Enzyme complex
End

// ***************************************************************************
// 			Poising and CV with 3 MHC populations
// ***************************************************************************

Function MHCTrend_Ea()
	
	String OldDf = GetDataFolder(1)
	
	Initialize_MHC_kinetics()
	
	SetDataFolder root:BIOFILM:Globals	
		if (Prompt_MHCStates() == 0)
			return 0
		endif
		if (Prompt_PoiseSettings() == 0)
			return 0
		endif
		if (Prompt_SSCVSettings() == 0)
			return 0
		endif
	SetDataFolder root:BIOFILM
	
	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb		
	WAVE MHC_QQc 		= root:BIOFILM:Globals:MHC_QQc
	NVAR gQQai 				= root:BIOFILM:Globals:gQQai
	NVAR gQQbi 				= root:BIOFILM:Globals:gQQbi
	NVAR gQQci 				= root:BIOFILM:Globals:gQQci
	
	//  ------ Acetate parameters
//	Variable AcRd = 2/8000
	Variable AcRd = 1e-9
	Variable AcOx = AcRd/1
	Variable ConstAc = 1
	Variable AnodeFlag = 1 	// Indicates QQa are bound to anode and their redox state is fixed
	// ----------------------------------
		
	//  ------ Poising parameters
	NVAR gPsEA 				= root:BIOFILM:Globals:gPsEA
	NVAR gPsEAdE 			= root:BIOFILM:Globals:gPsEAdE
	NVAR gPsEANSteps 		= root:BIOFILM:Globals:gPsEANSteps
	NVAR gPsEAtime 		= root:BIOFILM:Globals:gPsEAtime
	NVAR gPsEAdt 			= root:BIOFILM:Globals:gPsEAdt  
	
	Variable PsTPts = gPsEAtime/gPsEAdt
	Variable PsRStep=max(1,PsTPts/100)
	Variable PsRPts = PsTPts/PsRStep					// Only record 1% of the poising points
	
	//  ------ CV parameters
	NVAR gCVEChoice 		= root:BIOFILM:Globals:gCVEChoice 	// 
	NVAR gCVEstart 		= root:BIOFILM:Globals:gCVEstart 	// 
	NVAR gCVEstop 			= root:BIOFILM:Globals:gCVEstop 	// 
	NVAR gCVdE 				= root:BIOFILM:Globals:gCVdE 		// 
	NVAR gCVtime 			= root:BIOFILM:Globals:gCVtime 		// 
	NVAR gCVdt 				= root:BIOFILM:Globals:gCVdt 		// 
	
	Variable CVEPts = abs((gCVEstart-gCVEstop)/gCVdE)	// The number of anode potentials
	Variable CVTPts = gCVtime/gCVdt						// The number of time steps at each anode potential
	Variable CVRate = gCVdE/gCVtime						// The effective CV sweep rate in V/s
	
	String MHCDir, MHCNote
	Variable i, j, k, n, QQai, CVE, QQac, QQbf, QQcv
	
	// Are we displaying during thesimulation? 
	DoWindow DisplayMHCs
	Variable DisplayFlag = V_flag
		
	// ==== The major loop across poising potential values ====
	for (k=0;k<gPsEANSteps;k+=1)
	
		MHCDir = "root:BIOFILM:Sim"+FrontPadVariable(k,"0",3)
		MHCNote = MHCSimulationNote(gPsEA + k*gPsEAdE,gPsEAtime,gCVEstart,gCVEstop,CVRate)
		NewDataFolder /O/S $MHCDir
	
			Make /O/N=(PsRPts) Ps_Ac_C=0, Ps_Ac_Eh=0, Ps_ac_J, Ps_bf_J, Ps_cv_J					// Reporting the Poising period
			SetScale /P x, 0, (gPsEAdt*PsRStep), "s", Ps_Ac_C, Ps_Ac_Eh, Ps_ac_J, Ps_bf_J, Ps_cv_J
			
			Make /O/N=(CVEPts) CVf_Ac_C, CVf_Ac_Eh, CVf_ac_J, CVf_bf_J, CVf_cv_J, CVf_an_J		// Reporting the FORWARD CV scan
			Make /O/N=(CVEPts) CVr_Ac_C, CVr_Ac_Eh, CVr_ac_J, CVr_bf_J, CVr_cv_J, CVr_an_J		// Reporting the REVERSE CV scan
			SetScale /P x, gCVEstart, gCVdE, "V vs NHE", CVf_Ac_C, CVf_Ac_Eh, CVf_ac_J, CVf_bf_J, CVf_cv_J, CVf_an_J
			SetScale /P x, gCVEstop, -gCVdE, "V vs NHE", CVr_Ac_C, CVr_Ac_Eh, CVr_ac_J, CVr_bf_J, CVr_cv_J, CVr_an_J
			
			Note /K Ps_cv_J, MHCNote
			Note /K CVf_cv_J, MHCNote
			Note /K CVr_cv_J, MHCNote
			
			Make /O/D/FREE/N=(CVTPts) CV_Ps_ac_J, CV_Ps_bf_J, CV_Ps_cv_J 	// Time dependent traces at each CV Ea
			
			// Initial values for the MHCs
			QQai 	= gPsEA + k*gPsEAdE
			MHC_SetChargeStates(QQai,MHC_QQa)
			
			if (k==0)
				MHC_SetChargeStates(gQQbi,MHC_QQb)
				MHC_SetChargeStates(gQQci,MHC_QQc)
			endif
			
			Variable Poise=1
			if (Poise)
			// ==== Poise at selected potential ====
			Variable MSref1=StartMSTimer
			i = 0; j = 0
			do
				// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
				QQac 	= MHC_Ac_ET_step(gPsEAdt,AcRd,AcOx,ConstAc,MHC_QQc)
				
				// Equilibrate the Respiring and Non-Respiring MHCs
				QQbf 	= -1 * MHC_ET_step(gPsEAdt,0,MHC_QQb,MHC_QQc)		// <--- Set AnodeFlag=0
				
				// Equilibrate the Biofilm and Anode MHCs and record the current
				QQcv 	= -1 * MHC_ET_step(gPsEAdt,1,MHC_QQa,MHC_QQb)		// <--- Set AnodeFlag=1
				
				if (mod(i,PsRStep)==0)
					if (DisplayFlag==1)
						DoUpdate /W=DisplayMHCs
						DoUpdate /W=DisplayPoise
					endif
					Ps_ac_J[j] = QQac/gPsEAdt
					Ps_bf_J[j] = QQbf/gPsEAdt
					Ps_cv_J[j] = QQcv/gPsEAdt
					j += 1
				endif
				
				i+=1
			while(i < PsTPts)
			print " 	*** Poising for ",PsTPts," iterations took",StopMSTimer(MSref1)/1000,"s"
			endif
			
			// !*!*!*!* debug
//			gCVEChoice = -1
			// ==== FORWARD CV Scan ====
			if (gCVEChoice > 1)
				Variable MSref2=StartMSTimer
				for (n=0;n<CVEPts;n+=1)
					
					CVE = gCVEstart + n*gCVdE
					
					// *** Note *** This gives a large relative contribution so it is not currently added to the CV trace. (Check normalization!)
					CVf_an_J[n] 	= MHC_SetChargeStates(CVE,MHC_QQa) / (gCVtime)	// <--- Divide by the total time at each Ea
					
					i = 0
					do
						// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
						QQac 	= MHC_Ac_ET_step(gCVdt,AcRd,AcOx,ConstAc,MHC_QQb)
						
						// Equilibrate the Respiring and Non-Respiring MHCs
						QQbf 	= -1 * MHC_ET_step(gCVdt,0,MHC_QQb,MHC_QQc)			// <--- Set AnodeFlag=0
						
						// Equilibrate the Biofilm and Anode MHCs and record the current
						QQcv 	= -1 * MHC_ET_step(gCVdt,1,MHC_QQa,MHC_QQb)			// <--- Set AnodeFlag=1

						if (mod(i,PsRStep)==0)
						if (DisplayFlag==1)
								DoUpdate /W=DisplayMHCs
								DoUpdate /W=DisplayPoise
							endif
						endif
					
						CV_Ps_ac_J[i] = QQac/gCVdt		// <--- Divide by the time step
						CV_Ps_bf_J[i] = QQbf/gCVdt
						CV_Ps_cv_J[i] = QQcv/gCVdt
						
						i+=1
					while(i < CVTPts)
					
					CVf_ac_J[n] 	= mean(CV_Ps_ac_J)
					CVf_bf_J[n] 	= mean(CV_Ps_bf_J)
					CVf_cv_J[n] 	= mean(CV_Ps_cv_J)
				endfor
				
				// ==== REVERSE CV Scan ====
				if (gCVEChoice > 2)
					for (n=0;n<CVEPts;n+=1)
						
						CVE = gCVEstop - n*gCVdE
						
						// *** Note *** This gives a large relative contribution so it is not currently added to the CV trace. (Check normalization!)
						CVr_an_J[n] 	= MHC_SetChargeStates(CVE,MHC_QQa) / (gCVtime)	// <--- Divide by the total time at each Ea
						
						i = 0
						do
							// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
							QQac 	= MHC_Ac_ET_step(gCVdt,AcRd,AcOx,ConstAc,MHC_QQb)
							
							// Equilibrate the Respiring and Non-Respiring MHCs
							QQbf 	= -1 * MHC_ET_step(gCVdt,0,MHC_QQb,MHC_QQc)			// <--- Set AnodeFlag=0
							
							// Equilibrate the Biofilm and Anode MHCs and record the current
							QQcv 	= -1 * MHC_ET_step(gCVdt,1,MHC_QQa,MHC_QQb)			// <--- Set AnodeFlag=1
							
							if (mod(i,PsRStep)==0)
							if (DisplayFlag==1)
									DoUpdate /W=DisplayMHCs
									DoUpdate /W=DisplayPoise
								endif
							endif
							
							CV_Ps_ac_J[i] = QQac/gCVdt		// <--- Divide by the time step
							CV_Ps_bf_J[i] = QQbf/gCVdt
							CV_Ps_cv_J[i] = QQcv/gCVdt
							
							i+=1
						while(i < CVTPts)
						
						CVr_ac_J[n] 	= mean(CV_Ps_ac_J)
						CVr_bf_J[n] 	= mean(CV_Ps_bf_J)
						CVr_cv_J[n] 	= mean(CV_Ps_cv_J)
					endfor
				endif
			endif

			print " 	*** Forward and Reverse CV scan took",StopMSTimer(MSref2)/1000,"s"
	endfor
	SetDataFolder $OldDf
End

Function Prompt_MHCStates()
	
	Variable QQai = NumVarOrDefault("root:BIOFILM:Globals:gQQai",-0.5)
	Variable QQbi = NumVarOrDefault("root:BIOFILM:Globals:gQQbi",-0.15)
	Variable QQci = NumVarOrDefault("root:BIOFILM:Globals:gQQci",-0.15)
	
	Variable Ca = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCa",1e-4)	// Fixed concentration of RESPIRING MHCs in the biofilm layer, in moles per cm2
	Variable Cb = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCb",1e-4)	// Fixed concentration of NON-RESPIRING MHCs in the biofilm layer, in moles per cm2
	Variable Cc = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCc",1e-4)	// Fixed concentration of NON-RESPIRING MHCs attached to the anode, in moles per cm2
	
	Prompt QQai, "Initial redox state of Anode MHCs (vs NHE)"
	Prompt QQbi, "Initial redox state of Non-respiring biofilm MHCs"
	Prompt QQci, "Initial redox state of Respiring biofilm MHCs"
	Prompt Ca, "Concentration of Anode MHCs (moles per cm2)"
	Prompt Cb, "Concentration of Non-Respiring MHCs"
	Prompt Cc, "Concentration of Respiring MHCs"
	DoPrompt "Starting conditions", QQai, Ca, QQbi, Cb, QQci, Cc
	if (V_flag)
		return 0
	endif
	
	Variable /G	gQQai = QQai
	Variable /G	gQQbi = QQbi
	Variable /G	gQQci = QQci
	
	Variable /G	gC_MHCa = Ca
	Variable /G	gC_MHCb = Cb
	Variable /G	gC_MHCc = Cc
End

Function Prompt_PoiseSettings()

	Variable PsEA 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEA",-0.45) 
	Variable PsEAdE 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEAdE",0.6) 
	Variable PsEANSteps 	= NumVarOrDefault("root:BIOFILM:Globals:gPsEANSteps",1) 
	Variable PsEAtime 		= NumVarOrDefault("root:BIOFILM:Globals:gPsEAtime",1000000)
	Variable PsEAdt 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEAdt",200) 
	
	Prompt PsEA, "First anode poising potential (vs NHE)"
	Prompt PsEAdE, "Anode potential step"
	Prompt PsEANSteps, "Number of steps"
	Prompt PsEAtime, "Poise duration (s)"
	Prompt PsEAdt, "Poise time step"
	DoPrompt "Starting conditions", PsEA, PsEAdE, PsEANSteps, PsEAtime, PsEAdt
	if (V_flag)
		return 0
	endif
	
	Variable /G	gPsEA = PsEA
	Variable /G	gPsEAdE = PsEAdE
	Variable /G	gPsEANSteps = PsEANSteps
	Variable /G	gPsEAtime = PsEAtime
	Variable /G	gPsEAdt = PsEAdt
End

Function Prompt_SSCVSettings()

	Variable CVEChoice 	= NumVarOrDefault("root:BIOFILM:Globals:gCVEChoice",1) 
	Variable CVEstart 	= NumVarOrDefault("root:BIOFILM:Globals:gCVEstart",-0.3) 
	Variable CVEstop 	= NumVarOrDefault("root:BIOFILM:Globals:gCVEstop",0.2) 
	Variable CVdE 		= NumVarOrDefault("root:BIOFILM:Globals:gCVdE",0.02) 
	Variable CVtime 		= NumVarOrDefault("root:BIOFILM:Globals:gCVtime",100000)
	Variable CVdt 		= NumVarOrDefault("root:BIOFILM:Globals:gCVdt",20) 
	
	Prompt CVEChoice, "CV calculation", popup, "none;forward;both"
	Prompt CVEstart, "CV start potential (vs NHE)"
	Prompt CVEstop, "CV end potential (vs NHE)"
	Prompt CVdE, "CV potential step"
	Prompt CVtime, "Duration at each CV point (s)"
	Prompt CVdt, "Time step"
	DoPrompt "Starting conditions", CVEChoice, CVEstart, CVEstop, CVdE, CVtime, CVdt
	if (V_flag)
		return 0
	endif
	
	Variable /G 	gCVEChoice = CVEChoice
	Variable /G	gCVEstart = CVEstart
	Variable /G	gCVEstop = CVEstop
	Variable /G	gCVdE = CVdE
	Variable /G	gCVtime = CVtime
	Variable /G	gCVdt = CVdt
End

Window DisplayMHCs() : Graph
	PauseUpdate; Silent 1		// building window...
	String fldrSav0= GetDataFolder(1)
	SetDataFolder root:Biofilm:Globals:
	Display /W=(74,45,504,451) MHC_QQa,MHC_QQb,MHC_QQc
	SetDataFolder fldrSav0
	ModifyGraph mode=5
	ModifyGraph rgb(MHC_QQb)=(0,0,65535),rgb(MHC_QQc)=(2,39321,1)
	ModifyGraph hbFill=5
	ModifyGraph gaps(MHC_QQb)=0
	ModifyGraph offset(MHC_QQa)={0,1},offset(MHC_QQb)={0,0.5}
	ModifyGraph zero(left)=4
	ModifyGraph mirror=2
	ModifyGraph fSize=18
	ModifyGraph lowTrip(left)=0.001
	Label left "Intensity"
	SetAxis left 0,2
	Legend/C/N=text0/J/F=0/A=MC/X=-20.63/Y=37.65 "\\Z18\\s(MHC_QQa) Anode MHCs\r\\s(MHC_QQb) Non-respiring MHCs\r\\s(MHC_QQc) Respiring MHCs"
EndMacro

Function DisplayCVs() : Graph
	
	String CVType, CVNote, EAStr, CVList = ReturnSimDataFolders()
	Variable i, NCVs = ItemsInList(CVList)
	
	if (NCVs == 0)
		return 0
	endif
	
	SVAR gSimPlotChoice 		= root:BIOFILM:Globals:gSimPlotChoice
	
	strswitch (gSimPlotChoice)
		case "forward CV":
			CVType	= ":CVf_cv_J"
			break
		case "reverse CV":
			CVType	= ":CVr_cv_J"
			break
	endswitch
	
	WAVE CVWave 	= $(StringFromList(0,CVList)+CVType)
	CVNote = note(CVWave)
	
	DoWindow /K CVrPlot
	Display /K=1/N=CVrPlot/W=(424,348,1170,754) CVWave as gSimPlotChoice
	EAStr = StringByKey("PoiseEA",CVNote,"=")
	Legend/C/N=text0/J "\\s("+NameOfWave(CVWave)+") Ea="+EAStr+"\r"
	
	ModifyGraph zero(left)=4
	ModifyGraph mirror=2
	ModifyGraph fSize=18
	ModifyGraph lowTrip(left)=0.001
	
	Label left "Current"
	
	for (i=1;i<NCVs;i+=1)
		WAVE CVWave 	= $(StringFromList(i,CVList)+CVType)
		EAStr = StringByKey("PoiseEA",note(CVWave),"=")
		AppendToGraph /W=CVrPlot CVWave
		AppendText/N=text0 "\\s("+NameOfWave(CVWave)+"#"+num2str(i)+") Ea="+EAStr+"\r"
	endfor
End

Function /T ReturnSimDataFolders()
	
	String OldDf = GetDataFolder(1)
	SetDataFolder root:BIOFILM:Globals
		
		String SimFolder 	= "root:BIOFILM"
		String SimList 	= ReturnSimulationList(SimFolder,"Sim")
		
		String SimName = StrVarOrDefault("root:BIOFILM:Globals:gSimName","")
		String Sim2Name = StrVarOrDefault("root:BIOFILM:Globals:gSim2Name","") 
		String SimPlotChoice = StrVarOrDefault("root:BIOFILM:Globals:gSimPlotChoice","forward CV") 
		
		Prompt SimPlotChoice, "Simulation plot", popup, "forward CV;reverse CV"
		Prompt SimName, "List of simulations", popup, SimList
		Prompt Sim2Name, "Second for multiple display", popup, "_none_;"+SimList
		DoPrompt "Select simulations to view", SimPlotChoice, SimName,Sim2Name
		if (V_flag)
			return ""
		endif
		
		String /G gSimPlotChoice 	= SimPlotChoice
		String /G gSimName 	= SimName
		String /G gSim2Name 	= Sim2Name
		
		Variable i, IStart, IStop
		
		String SimPlotList 	= SimFolder + ":" + SimName
		
		if (cmpstr("_none_",Sim2Name) != 0)
			IStart 	= WhichListItem(SimName,SimList)
			IStop 	= WhichListItem(Sim2Name,SimList)
			for (i=IStart+1;i<=IStop;i+=1)
				SimPlotList = SimPlotList + ";" + SimFolder + ":" + StringFromList(i,SimList)
			endfor
		endif
		
		return SimPlotList
		
	SetDataFolder $OldDf
End

Function /T ReturnSimulationList(SimFolder,SimPrefix)
String SimFolder,SimPrefix
	
	DFREF dfr = $SimFolder
	
	Variable i, NumDf, PrefixLen=strlen(SimPrefix)
	String DfName, DfPrefix, DfList=""
	
	NumDf 	= CountObjectsDFR(dfr, 4)
	for (i=0; i<NumDf;i+=1)
		DfName 	= GetIndexedObjNameDFR(dfr,4,i)
		DfPrefix = DfName[0,PrefixLen-1]
		if (cmpstr(DfPrefix,SimPrefix) == 0)
			DfList = DfList + DfName + ";"
		endif
	endfor
	
	return DfList
End

Function /T MHCSimulationNote(PsEA,PsEAtime,CVEstart,CVEstop,CVRate)
	Variable PsEA,PsEAtime,CVEstart,CVEstop,CVRate

	String CVNote = "PoiseEA="+num2str(PsEA)+";"
	CVNote += "PoiseT="+num2str(PsEAtime/3600)+";"
	CVNote += "CVStart="+num2str(CVEstart)+";"
	CVNote += "CVEstop="+num2str(CVEstop)+";"
	CVNote += "CVRate="+num2str(CVRate*1000)+"mV/s;"
	return CVNote
End

Static Function /T FrontPadString(NumStr,Char,Width)
	String NumStr, Char
	Variable Width
	
	String NewNumStr=""
	Variable i=0, OldLen
	
	OldLen = strlen(NumStr)
	if (OldLen > (Width-1))
		return NumStr
	else
		do
			NewNumStr+= Char
			i+=1
		while(i<(Width-OldLen))
		NewNumStr += NumStr
		return NewNumStr
	endif
End

Static Function /T FrontPadVariable(Num,Char,Width)
	Variable Num
	String Char
	Variable Width
	
	return FrontPadString(num2str(Num),Char,Width)
End

// ***************************************************************************
// 			Electron transfer between the Acetate pool and one Biofilm MHC population
// ***************************************************************************

Function MHC_Ac_ET_step(dt,AcRd,AcOx,ConstAc,QQ)
	Variable dt,&AcRd,&AcOx, ConstAc
	Wave QQ
	
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo			// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
	NVAR 	lambda 			= root:BIOFILM:Globals:gAc_L			// Reorganization energy, in eV, for Acetate-to-MHC ET
	NVAR 	vK 					= root:BIOFILM:Globals:gAc_vK			// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
	
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	WAVE QQf 				= root:BIOFILM:Globals:MHC_QQf			// A temporary array
	WAVE QQr				= root:BIOFILM:Globals:MHC_QQr			// A temporary array

	Variable MHC_Eo 		= DimOffset(QQ,0)				// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable MHC_dE 		= DimDelta(QQ,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable Qmax 			= DimSize(QQ,0)					// The total number of electron occupation states (= 11)
	
	Variable Ac_Eh, MHC_Eh, MHC_EN, dQQ
	Variable i, j, DG, Ket, dAc, dACtot=0, ETtot=0
	Variable FWDFlag=1, REVFlag=1
	
	// Redox potential of the acetate + respiration enzyme system - fixed for a single iteration
	Ac_Eh 	= gAc_Eo  + ln(AcOx/AcRd)/cf
	
	// Loop through all the MHC populations that can be reduced. 
	// The last state, Q=10, cannot be reduced, so stop at (MHC_QMax-1)
	for (j=0;j<(Qmax);j+=1)
		
		// ***  FORWARD ET means electron transfer from Acetate to MHCs
		if (FWDFlag)
			if (j == (Qmax-1))					// No ET to the most reduced acceptor states
			else
			
				// Redox potential for the (j)-to-(j+1), including Nernstian correction
				MHC_Eh 	= MHC_Eo + j*MHC_dE
				MHC_Eh 	+= ln(QQ[j+1]/QQ[j])/cf
			
				// Gibbs free energy for electron transfer
				DG			= -1 * (MHC_Eh - Ac_Eh)
				
				// The FORWARD electron transfer rate to this population
				Ket 		= K_HomoMarcusET(vK,DG,lambda)
				
				// The predicted consumption of Acetate due to electron transfer
				dAc 		= AcRd * gCb*QQ[j] * (1 - exp(-1*dt*Ket))
				
				// Record but don't apply the change in redox state
				QQf[j]  	= 8*dAc/gCb
			
			endif
		endif
		
		dActot += dAc
		
		// ***  REVERSE ET
		if (REVFlag)
			if (j == 0)							// No ET from the most oxidized states
			else
			
				// Redox potential for the (j)-to-(j-1), including Nernstian correction
				MHC_Eh 	= MHC_Eo + j*MHC_dE
				MHC_Eh 	+= ln(QQ[j]/QQ[j-1])/cf
			
				// Gibbs free energy for electron transfer
				DG			= -1 * (Ac_Eh - MHC_Eh)
				
				// The FORWARD electron transfer rate to this population
				Ket 		= K_HomoMarcusET(vK,DG,lambda)
				
				// The predicted consumption of Acetate due to electron transfer
				dAc 		= AcOx * gCb*QQ[j] * (1 - exp(-1*dt*Ket))
				
				// Record but don't apply the change in redox state
				QQr[j]  	= 8*dAc/gCb
			
			endif
		endif
		
		dActot -= dAc
		
	endfor
	
	if (!ConstAc)	// Option to run in constant-Acetate conditions
		AcRd -= dActot
		AcOx += dActot
	endif
	
	for (j=0;j<(Qmax-1);j+=1)
		if (FWDFlag)
			if (j == (Qmax-1))
			else
				QQ[j] 		-= QQf[j]
				QQ[j+1] 	+= QQf[j]
			endif
		endif
		if (REVFlag)
			if (j == 0)
			else
				QQ[j] 		-= QQr[j]
				QQ[j-1] 	+= QQr[j]
			endif
		endif
	endfor
	
	ETtot = 8*dActot
	return ETtot
End



// ***************************************************************************
// 			Electron transfer between two MHC populations
// ***************************************************************************

// 	Input: Two QQ's containing populations of identical MHCs
// 	Calculation: Calculate rate constants for all permutations of forward and reverse electron transfer
//	Output: The modified QQ's and the net 'forward' electron flux	
//	Options: Allow biofilm-biofilnm or biofilm-anode ET. 
//	Description: 

Function MHC_ET_step(dt,AnodeFlag,QQa,QQb)
	Variable dt,AnodeFlag
	Wave QQa, QQb
	
	NVAR gCb 		= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	NVAR gCa 		= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2
	
	WAVE Kab 			= root:BIOFILM:Globals:MHC_Kba			// The Forward ET's
	WAVE Kba 			= root:BIOFILM:Globals:MHC_Kab			// The Reverse ET's
	
	Variable Eo 			= DimOffset(QQb,0)				// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable dE 			= DimDelta(QQb,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable QMax 		= DimSize(QQb,0)				// The total number of electron occupation states (= 11)
	
	Variable FWDFlag=1, REVFlag=1
	Variable i, j, Ket, ETfwd, ETrev, ETtot=0
	
	// Increasing i means that QQa is more reducing as we go down the rows of Kab
	// Increasing j means that QQb is more reducing as we go across the columns of Kab
	
	// Loop over all the Qmax populations
	for (i=0;i<QMax;i+=1)
		for (j=0; j<QMax;j+=1)
			
			if (REVFlag)									// 	FORWARD ET between i and j means QQa[i] is the donor and QQb[j] is the acceptor
															// 	Populations are transfered from i to (i-1) and from j to (j+1)
				if (QQa[i]==0 || QQb[j]==0)			// No Donor or no Acceptor populations
				elseif (j == (Qmax-1))					// No ET to the most reduced acceptor states
				elseif (i == 0)							// No ET from the most oxidized states
				else
				
					// 	The homogeneous ET rate constant for this pair
					Ket 		= Kba[i][j]
				
					// The predicted electron transfer (correct form?)
					ETfwd 		= gCa*QQa[i] * gCb*QQb[j] * (1 - exp(-1*dt*Ket))
	//				ETfwd 		= gCa*QQa[i] * gCb*QQb[j] * dt*Ket
				
					 // Update the populations of QQb (here, acceptor)
					QQb[j] 		-= ETfwd/gCb			// Electrons transfered from MHCb state j to (j+1)
					QQb[j+1] 		+= ETfwd/gCb	
					
					if (!AnodeFlag)								// Update the populations of QQa (here, donor and not on the anode)
						QQa[i] 		-= ETfwd/gCa			// Electrons transfered from MHCa state i to (i-1)
						QQa[i-1] 		+= ETfwd/gCa	
					endif
					
					ETtot 			+= ETfwd						// Keep track of electrons transferred in forward reaction
				endif
			endif
			
			if (FWDFlag)									// 	REVERSE ET between i and j means QQa[j] is the donor and QQb[i] is the acceptor
															// 	Populations are transfered from i to (i+1) and from j to (j-1)
				if (QQa[i]==0 || QQb[j]==0)			// No Acceptor or no Donor
				elseif (j == 0)							// No ET from the most oxidized states
				elseif (i == QMax-1)						// No ET to the most reduced acceptor states
				else
				
					// 	The homogeneous ET rate constant for this pair
					Ket 		= Kab[i][j]
				
					// The predicted electron transfer (correct form?)
					ETrev 		= gCa*QQa[i] * gCb*QQb[j] * (1 - exp(-1*dt*Ket))
//					ETfwd 		= gCa*QQa[i] * gCb*QQb[j] * dt*Ket
				
					 // Update the populations of QQb (here, donor)
					QQb[j] 		-= ETrev/gCb				// Electrons transfered from MHCb state j to (j-1)
					QQb[j-1] 		+= ETrev/gCb	
					
					if (!AnodeFlag)							// Update the populations of QQa (here, acceptor and not on the anode)
						QQa[i] 		-= ETrev/gCa			// Electrons transfered from MHCb state i to (i+1)
						QQa[i+1] 		+= ETrev/gCa	
					endif
					
					ETtot 			-= ETrev						// Keep track of electrons transferred in forward reaction
				endif
			endif
		endfor
	endfor
	
	return ETtot
End


// ***************************************************************************
// 			Electron transfer rate constants based on Marcus Theory
// ***************************************************************************

// MHC to MHC electron transfer
// Based on standard DGs for ET with no Nernstian terms so only need to calculate this once. 
Function MHC_MHC_ET_rates(Kab,Kba)
	Wave Kab,Kba
	
	NVAR 	lambda 		= root:BIOFILM:Globals:gMHC_L		// Reorganization energy, in eV, for MHC-to-MHC ET
	NVAR 	vK 				= root:BIOFILM:Globals:gMHC_vK		// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
	
	Variable Eo 			= DimOffset(Kab,0)			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable dE 			= DimDelta(Kab,0)			// Increment in MHC redox potential for a unit change in charge state, in V
	Variable QMax 		= DimSize(Kab,0)			// The total number of electron occupation states
	
	Variable i, j, DGf, DGr
	
	for (i=0;i<QMax;i+=1)
		for (j=0; j<QMax;j+=1)
		
			DGf 		= (i - j) * dE			// <-- Check signs!!!!!!!!
			DGr 		= (j - i) * dE			// <-- Check for conversion between Eo and DG!!!!!!!
			
			Kab[i][j]		= K_HomoMarcusET(vK,DGf,lambda)		// Seem to have these the wrong way round, but that is now accounted for in the equilibration step
			Kba[i][j]		= K_HomoMarcusET(vK,DGr,lambda)
		
		endfor
	endfor
End

// Non-adiabatic solution-phase ET
Function K_HomoMarcusET(vK,DG,lambda)
	Variable vK, DG, lambda
	
	Variable DG_act, K_mh
	
	// The activation energy for homogeneous electron transfer from Marcus Theory. 
	DG_act  	= (lambda + DG)^2/(4*lambda)
	
	// The Marcus-Hush rate constant 
	K_mh 		= vK * exp(-(cFaraday*DG_act)/(cR*298))
	
	return K_mh
End




// ***************************************************************************
// 			Instant equilibration of MHCs with local redox potential
// ***************************************************************************

// Calculate the charge distribution of MHCs for a given anode potential. 
// 	Inputs: The current charge state of a the surface bound MHCs and the Anode Potential
// 	Return QQ, the number of electrons required to acheive the charge state, per MHC, from the starting charge state

Function MHC_SetChargeStates(Ea,MHC_QQ)
	Variable Ea
	Wave MHC_QQ
	
	WAVE MHC_QQt 	= root:BIOFILM:Globals:MHC_QQt				// A temporary array
	MHC_QQt = 0
	
	Variable Eo 			= DimOffset(MHC_QQ,0)			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable dE 			= DimDelta(MHC_QQ,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable QMax 		= DimSize(MHC_QQ,0)				// The total number of electron occupation states
	
	Variable nn, E1st, Enth, Edif, Popn
	Variable i, j, QQ=0, temp, NPts=Dimsize(MHC_QQ,0)
	
	// The difference between the Anode potential and the first redox potential
	Edif 		= Ea - Eo + 0.5*dE
	
	// The index of the operational redox potential	
	nn 		= min(max(0,trunc(Edif/dE)),QMax-2) // nn varies between 0 - 9 
	
	//  The value of the operational redox potential	
	E1st 	= Eo + (nn)*dE
	
	// Start with the nnth redox couple
	MHC_SetFirstChargeState(nn,Ea,E1st,MHC_QQt)
	
	// The contribution of the more reducing charge states
	j=1
	for (i=nn+1;i<QMax-1;i+=1)
		Enth 	= E1st + j*dE
		MHC_SetNthChargeState(i,Ea,E1st,Enth,MHC_QQt)
		j+=1
	endfor
		
	// The contribution of the more oxidizing charge states
	j=1
	for (i=nn-1;i>=0;i-=1)
		Enth 	= E1st - j*dE
		MHC_SetNthChargeState(i,Ea,E1st,Enth,MHC_QQt)
		j+=1
	endfor
	
	Popn 	= sum(MHC_QQt)
	MHC_QQt /= Popn
	
	// Calculate the total change in charge
	for (i=0;i<NPts;i+=1)
		QQ += i*(MHC_QQt[i] - MHC_QQ[i])
	endfor
	
	MHC_QQ = MHC_QQt
	
	return QQ
End

Function MHC_SetNthChargeState(nn,Ea,E1st,Enth,MHC_QQt)
	Variable nn,Ea,E1st,Enth
	Wave MHC_QQt
	
	Variable XX, A, B
	
	// This expression stays the same (?) whether Enth is higher or lower than E1st
	// -----------------------------------------------
	XX 		= exp(    (  1 *  (Ea-Enth)*cElectron    )/(cBoltzmann*298)) 	// Properly converted from eV to J
	// -----------------------------------------------
	
	// If Enth is more reducing than E1st, then we fix B and set the nnth
	if (Enth < E1st)
		B 					= MHC_QQt[nn]		// This is nn + i
		A 					= B/XX
		MHC_QQt[nn+1] 	= A
	else
		A  					= MHC_QQt[nn+1]
		B 					= A*XX
		MHC_QQt[nn] 		= B
	endif
End

Function MHC_SetFirstChargeState(nn,Ea,Enn,MHC_QQt)
	Variable nn,Ea,Enn
	Wave MHC_QQt
	
	Variable XX, A, B
	
	// -----------------------------------------------
	XX 		= exp(    (  1 *  (Ea-Enn)*cElectron    )/(cBoltzmann*298)) 	// Properly converted from eV to J
	// -----------------------------------------------
	
	// A is the proportion of REDUCED 
	A 		= 1/(1+XX)
	B 		= XX/(1+XX)

	// Positive QQ means electrons are transferred to the MHCs
	MHC_QQt[nn] 		= B
	MHC_QQt[nn+1] 	= A
End

// Calculate the average occupation of all MHCs
Function /C MHC_MeanChargeState(MHC_QQ)
	Wave MHC_QQ
	
	Variable Eo 			= DimOffset(MHC_QQ,0)			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable dE 			= DimDelta(MHC_QQ,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable QMax 		= DimSize(MHC_QQ,0)				// The total number of electron occupation states
	
	Variable /C QQEh
	Variable i, QQ=0, Eh
	
	for (i=0;i<QMax;i+=1)
		QQ += i*MHC_QQ[i]
	endfor
	
	Eh 		= Eo + QQ*dE
	QQEh 	= cmplx(QQ,Eh)
	
	return QQEh
End

// ======================================================================================================
// ======================================================================================================
// ======================================================================================================
// ======================================================================================================
// ======================================================================================================
// ======================================================================================================

Function MHC3_SSCV()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb		
	WAVE MHC_QQc 		= root:BIOFILM:Globals:MHC_QQc
	
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of RESPIRING MHCs in the biofilm layer, in moles per cm2
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of NON-RESPIRING MHCs in the biofilm layer, in moles per cm2
	NVAR gCa 				= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of NON-RESPIRING MHCs attached to the anode, in moles per cm2

	Variable ii, jj=0, QQac, QQbf, QQcv
	
	//  ------ Acetate parameters
	Variable AcRd = 2/8000
	Variable AcOx = AcRd/10
	Variable ConstAc = 1
	Variable AnodeFlag = 1 	// Indicates QQa are bound to anode and their redox state is fixed
	// ----------------------------------
		
	// Poising and respiration parameters
	Variable PsEA=-0.45, PsEAtime=1000000, PsEAdt=200
	Variable PsTPts = PsEAtime/PsEAdt
	Variable PsRStep=max(1,PsTPts/100)
	Variable PsRPts = PsTPts/PsRStep		// Only record a portion of the poising points
	
	// Reporting the poising period
	Make /O/N=(PsRPts) Ps_Ac_C=0, Ps_Ac_Eh=0, Ps_ac_J, Ps_bf_J, Ps_cv_J
	SetScale /P x, 0, (PsEAdt*PsRStep), "s", Ps_Ac_C, Ps_Ac_Eh, Ps_ac_J, Ps_bf_J, Ps_cv_J
	
	// CV parameters
	Variable CVE, CVEstart=-0.3, CVEstop=0.2, CVdE=0.02, CVtime=100000, CVdt=20
	Variable CVEPts = abs((CVEstart-CVEstop)/CVdE)	// The number of anode potentials
	Variable CVTPts = CVtime/CVdt						// The number of time steps at each anode potential
	
	// Reporting the CV period
	Make /O/N=(CVEPts) CV_Ac_C=0, CV_Ac_Eh, CV_ac_J, CV_bf_J, CV_cv_J, CV_an_J
	SetScale /P x, CVEstart, CVdE, "V vs NHE", CV_Ac_C, CV_Ac_Eh, CV_ac_J, CV_bf_J, CV_cv_J, CV_an_J
	
	// Initial values for the MHCs
	Variable Restart=1
	if (Restart)
		MHC_SetChargeStates(-0.5,MHC_QQa)
		MHC_SetChargeStates(-0.15,MHC_QQb)
		MHC_SetChargeStates(-0.15,MHC_QQc)
	endif
	
	Variable n, nLoops=20,QQ1, QQ2,SaveLast=1
	if (SaveLast)
		Duplicate /O CV_Ac_J, CV_Ac_J_last	// Electrons generated by acetate respiration
		Duplicate /O CV_bf_J, CV_bf_J_last	// Electrons transfered from Respiring to Non-respiring MHCs
		Duplicate /O CV_cv_J, CV_cv_J_last		// Electrons transfered to anode from biofilm
		Duplicate /O CV_an_J, CV_an_J_last		// Electrons exchanged between anode and attached MHCs
	endif
		
	Variable /G gIndex1=0

	Variable PoiseFlag=1
	if (PoiseFlag)
	Variable MSref1=StartMSTimer
	for (n=0;n<nLoops;n+=1)
		ii = 0
		do
			// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
			QQac 	= MHC_Ac_ET_step(PsEAdt,AcRd,AcOx,ConstAc,MHC_QQc)
			
			// Equilibrate the Respiring and Non-Respiring MHCs
			QQbf 	= -1 * MHC_ET_step(PsEAdt,0,MHC_QQb,MHC_QQc)		// <--- Set AnodeFlag=0
			
			// Equilibrate the Biofilm and Anode MHCs and record the current
			QQcv 	= -1 * MHC_ET_step(PsEAdt,1,MHC_QQa,MHC_QQb)		// <--- Set AnodeFlag=1
			
			ii+=1
		while(ii < PsTPts)
		DoUpdate
	endfor
	print " 	*** Poising for ",PsTPts," iterations took",StopMSTimer(MSref1)/1000,"s"
	endif
	
	
	for (n=0;n<CVEPts;n+=1)
		
		CVE = CVEstart + n*CVdE
		
		CV_an_J[n] 	= MHC_SetChargeStates(CVE,MHC_QQa) / (1e9*CVdt)
		
		jj = 0
		ii = 0
		Variable /G MSref2=StartMSTimer
		do
			if (mod(ii,PsRStep)==0)
				DoUpdate
				Ps_ac_J[jj] = QQac/CVdt
				Ps_bf_J[jj] = QQbf/CVdt
				Ps_cv_J[jj] = QQcv/CVdt
				jj += 1
			endif
			
			// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
			QQac 	= MHC_Ac_ET_step(CVdt,AcRd,AcOx,ConstAc,MHC_QQb)
			
			// Equilibrate the Respiring and Non-Respiring MHCs
			QQbf 	= -1 * MHC_ET_step(CVdt,0,MHC_QQb,MHC_QQc)			// <--- Set AnodeFlag=0
			
			// Equilibrate the Biofilm and Anode MHCs and record the current
			QQcv 	= -1 * MHC_ET_step(CVdt,1,MHC_QQa,MHC_QQb)	// <--- Set AnodeFlag=1
			
			ii+=1
			gIndex1+=1
		while(ii < CVTPts)
		
		CV_Ac_J[n] 	= mean(Ps_Ac_J)
		CV_bf_J[n] 	= mean(Ps_bf_J)
		CV_cv_J[n] 	= mean(Ps_cv_J)
	endfor
	
	print " 	*** CV scan for ",PsTPts," iterations took",StopMSTimer(MSref2)/1000,"s"
	
	return 0

End

// ***************************************************************************
// 			Tests of Acetate-MHC-MHC cyclic voltammetry with 2 pools
// ***************************************************************************

Function MHC2_SSCV()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
	
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	NVAR gCa 				= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2

	Variable ii, jj=0, QQac=NaN, QQcv=NaN
	
	//  ------ Acetate parameters
	Variable AcRd = 2/8000
	Variable AcOx = AcRd/10
	Variable ConstAc = 1
	Variable AnodeFlag = 1 	// Indicates QQa are bound to anode and their redox state is fixed
	// ----------------------------------
		
	// Poising and respiration parameters
	Variable PsEA=-0.45, PsEAtime=1000000, PsEAdt=200
	Variable PsTPts = PsEAtime/PsEAdt
	Variable PsRStep=max(1,PsTPts/100)
	Variable PsRPts = PsTPts/PsRStep		// Only record a portion of the poising points
	
	// Reporting the poising period
	Make /O/N=(PsRPts) Ps_Ac_C=0, Ps_Ac_Eh=0, Ps_Ac_J, Ps_MHCa_J, Ps_MHCb_J, Ps_MHCa_Eh, Ps_MHCb_Eh
	SetScale /P x, 0, (PsEAdt*PsRStep), "s", Ps_Ac_C, Ps_Ac_Eh, Ps_Ac_J, Ps_MHCa_J, Ps_MHCb_J, Ps_MHCa_Eh, Ps_MHCb_Eh
	
	// CV parameters
	Variable CVE, CVEstart=-0.3, CVEstop=0.2, CVdE=0.005, CVtime=100000, CVdt=2
	Variable CVEPts = abs((CVEstart-CVEstop)/CVdE)	// The number of anode potentials
	Variable CVTPts = CVtime/CVdt						// The number of time steps at each anode potential
	
	// Reporting the CV period
	Make /O/N=(CVEPts) CV_Ac_C=0, CV_Ac_Eh, CV_MHCa_Eh, CV_MHCb_Eh
	Make /O/N=(CVEPts) CV_Ac_J, CV_MHCa_J, CV_MHCb_J, CV_MHCa_dJ, CV_MHCb_dJ
	SetScale /P x, CVEstart, CVdE, "V vs NHE", CV_Ac_C, CV_Ac_Eh, CV_Ac_J, CV_MHCa_J, CV_MHCb_J, CV_MHCa_Eh, CV_MHCb_Eh,CV_MHCa_dJ, CV_MHCb_dJ
	
	
	Variable n, QQ1, QQ2,SaveLast=1
	if (SaveLast)
		Duplicate /O CV_Ac_J, CV_Ac_J_last
		Duplicate /O CV_MHCa_J, CV_MHCa_J_last
		Duplicate /O CV_MHCb_J, CV_MHCb_J_last
		Duplicate /O CV_MHCa_dJ, CV_MHCa_dJ_last
		Duplicate /O CV_MHCb_dJ, CV_MHCb_dJ_last
	endif
	
	// Initial values for the MHCs
	Variable QQa, QQb
//	Variable QQa 	= MHC_SetChargeStates(-0.2,MHC_QQa)
//	Variable QQb = MHC_SetChargeStates(-0.13,MHC_QQb)

	MHC_SetChargeStates(-0.05,MHC_QQa)
	MHC_SetChargeStates(-0.2,MHC_QQb)
	
	for (n=0;n<12;n+=1)
		ii = 0
		do
			
			// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
			QQac 	= MHC_Ac_ET_step(PsEAdt,AcRd,AcOx,ConstAc,MHC_QQb)
			
			// Equilibrate the Biofilm and Anode MHCs and record the current
			QQcv 	= -1 * MHC_ET_step(PsEAdt,ConstAc,MHC_QQa,MHC_QQb)
			
			ii+=1
		while(ii < PsTPts)
		DoUpdate
	endfor
		
	
	Variable /G MSref1=StartMSTimer, gIndex1=0
	
	for (n=0;n<CVEPts;n+=1)
		
		CVE = CVEstart + n*CVdE
		
		QQa 	= MHC_SetChargeStates(CVE,MHC_QQa)
		
		jj = 0
		ii = 0
		do
			if (mod(ii,PsRStep)==0)
				DoUpdate	 	// Some reporting
//				RecordBiofilmCurrent(jj,AcRd,AcOx,Ps_Ac_C, Ps_Ac_Eh, MHC_QQa, MHC_QQb, Ps_MHCa_Eh, Ps_MHCb_Eh)
				Ps_Ac_J[jj] = QQac/PsEAdt
				Ps_MHCb_J[jj] = QQcv/PsEAdt
				jj += 1
			endif
			
			// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
			QQac 	= MHC_Ac_ET_step(PsEAdt,AcRd,AcOx,ConstAc,MHC_QQb)
			
			// Equilibrate the Biofilm and Anode MHCs and record the current
			QQcv 	= -1 * MHC_ET_step(PsEAdt,ConstAc,MHC_QQa,MHC_QQb)
			
			ii+=1
			gIndex1+=1
		while(ii < PsTPts)
		
//		CV_Ac_J[n] 	= Ps_Ac_J[jj-1]
//		CV_MHCb_J[n] 	= Ps_MHCb_J[jj-1]
		CV_Ac_J[n] 	= mean(Ps_Ac_J)
		CV_MHCb_J[n] 	= mean(Ps_MHCb_J)
		
	endfor
	
	
	print " 	*** Poising for ",PsTPts," iterations took",StopMSTimer(MSref1)/1000,"s"
	
	return 0

End


//
//
//Function MHC_Poise_CV()
//	
//	Initialize_MHC_kinetics()
//	
//	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
//	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
//	
//	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
//	NVAR gCa 				= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2
//
//	Variable ii, jj=0, QQac=NaN, QQcv=NaN
//	
//	//  ------ Acetate parameters
//	Variable AcRd = 2/8000
//	Variable AcOx = AcRd
//	Variable ConstAc = 1
//	Variable AnodeFlag = 1 	// Indicates QQa are bound to anode and their redox state is fixed
//	// ----------------------------------
//		
//	// Poising and respiration parameters
//	Variable PsEA=-0.45, PsEAtime=20000000, PsEAdt=200
//	Variable PsTPts = PsEAtime/PsEAdt
//	Variable PsRStep=max(1,PsTPts/100)
//	Variable PsRPts = PsTPts/PsRStep		// Only record a portion of the poising points
//	
//	// Reporting the poising period
//	Make /O/N=(PsRPts) Ps_Ac_C=0, Ps_Ac_Eh=0, Ps_Ac_J, Ps_MHCa_J=0, Ps_MHCb_J=0, Ps_MHCa_Eh=0, Ps_MHCb_Eh=0
//	SetScale /P x, 0, (PsEAdt*PsRStep), "s", Ps_Ac_C, Ps_Ac_Eh, Ps_Ac_J, Ps_MHCa_J, Ps_MHCb_J, Ps_MHCa_Eh, Ps_MHCb_Eh
//	
//	// CV parameters
//	Variable CVE, CVEstart=-0.4, CVEstop=0.2, CVdE=0.05, CVtime=100000, CVdt=2
//	Variable CVEPts = abs((CVEstart-CVEstop)/CVdE)	// The number of anode potentials
//	Variable CVTPts = CVtime/CVdt						// The number of time steps at each anode potential
//	Variable CVRStep = 1 //max(1,CVEPts/100)
//	
//	// Reporting the CV period
//	Make /O/N=(CVEPts) CV_Ac_C=0, CV_Ac_Eh, CV_MHCa_Eh, CV_MHCb_Eh
//	Make /O/N=(CVEPts) CV_Ac_J, CV_MHCa_J, CV_MHCb_J, CV_MHCa_dJ, CV_MHCb_dJ
//	SetScale /P x, CVEstart, CVdE, "V vs NHE", CV_Ac_C, CV_Ac_Eh, CV_Ac_J, CV_MHCa_J, CV_MHCb_J, CV_MHCa_Eh, CV_MHCb_Eh,CV_MHCa_dJ, CV_MHCb_dJ
//	
//	// Reporting the time axis on the CV
//	Variable CTTotTPts = CVEPts * CVTPts
//	Make /O/N=(CTTotTPts) CV_Ac_Time_J, CV_MHCa_Time_J, CV_MHCb_Time_J
//	
//	Variable n, QQ1, QQ2,SaveLast=1
//	if (SaveLast)
//		Duplicate /O CV_Ac_J, CV_Ac_J_last
//		Duplicate /O CV_MHCa_J, CV_MHCa_J_last
//		Duplicate /O CV_MHCb_J, CV_MHCb_J_last
//		Duplicate /O CV_MHCa_dJ, CV_MHCa_dJ_last
//		Duplicate /O CV_MHCb_dJ, CV_MHCb_dJ_last
//	endif
//	
//	// Initial values for the MHCs
//	Variable QQa 	= MHC_SetChargeStates(-0.2,MHC_QQa)
////	Variable QQb = MHC_SetChargeStates(-0.13,MHC_QQb)
//	
//	// Poising period
////	print PsRStep, CVRStep
//	
//	Variable /G MSref1=StartMSTimer, gIndex1=0
//	do
//		if (mod(ii,PsRStep)==0)
//			DoUpdate	 	// Some reporting
//			RecordBiofilmCurrent(jj,AcRd,AcOx,Ps_Ac_C, Ps_Ac_Eh, MHC_QQa, MHC_QQb, Ps_MHCa_Eh, Ps_MHCb_Eh)
//			Ps_Ac_J[jj] = QQac/PsEAdt
//			Ps_MHCb_J[jj] = QQcv/PsEAdt
//			jj += 1
//		endif
//		
//		// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
//		QQac 	= MHC_Ac_ET_step(PsEAdt,AcRd,AcOx,ConstAc,MHC_QQb)
//		
//		// Equilibrate the Biofilm and Anode MHCs and record the current
//		QQcv 	= -1 * MHC_ET_step(PsEAdt,ConstAc,MHC_QQa,MHC_QQb)
//		
//		ii+=1
//		gIndex1+=1
//	while(ii < PsTPts)
//	print " 	*** Poising for ",PsTPts," iterations took",StopMSTimer(MSref1)/1000,"s"
//	
//	return 0
//
//	// Oxidizing CV scan
//	
//	Variable /G MSref2=StartMSTimer, gIndex2=0
//	
//	n=0
//	for (ii=0;ii<CVEPts;ii+=1)
//		
//		CVE = CVEstart + ii*CVdE
//		
//		// Equilibrate the Anode-MHCs at the new potential and record the current
//		CV_MHCa_J[ii] 	= -1*gCa*MHC_SetChargeStates(CVE,MHC_QQa)/CVtime
//		
//		
//		CV_MHCa_Time_J[n] = CV_MHCa_J[ii]
//		
//		QQac = 0
//		QQcv = 0
//		for (jj=0;jj<CVTPts;jj+=1)
//		
//			// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
//			QQ1 = MHC_Ac_ET_step(CVdt,AcRd,AcOx,ConstAc,MHC_QQb)
//		
//			// Equilibrate the Biofilm and Anode MHCs and record the current
//			QQ2 -= MHC_ET_step(CVdt,AnodeFlag,MHC_QQa,MHC_QQb)
//			
//			CV_Ac_Time_J[n] = QQ1
//			CV_MHCb_Time_J[n] = QQ2
//			n+=1
//			
//			QQac += QQ1
//			QQcv += QQ2
//			
//		endfor
//		
//		CV_Ac_J[ii] = QQac/CVtime
//		CV_MHCb_J[ii] = QQcv/CVtime
//		
//		DoUpdate
//		RecordBiofilmCurrent(ii,AcRd,AcOx,CV_Ac_C, CV_Ac_Eh, MHC_QQa, MHC_QQb, CV_MHCa_Eh, CV_MHCb_Eh)
//	
//	endfor
//	print " 	*** CV for ",PsTPts," iterations took",StopMSTimer(MSref2)/1000,"s"
//	
//	CV_Ac_J[0] = 0
//	CV_MHCa_J[0] = 0
//	CV_MHCb_J[0] = 0
//	Differentiate CV_MHCa_J /D=CV_MHCa_dJ
//	Differentiate CV_MHCb_J /D=CV_MHCb_dJ
//End

Function RecordBiofilmCurrent(n,AcRd,AcOx,Ac_C, Ac_Eh, MHC_QQa, MHC_QQb, MHCa_Eh, MHCb_Eh)
	Variable n,AcRd,AcOx
	Wave Ac_C, Ac_Eh, MHC_QQa, MHC_QQb, MHCa_Eh, MHCb_Eh
	
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
	
	Ac_C[n] 		= AcRd
	Ac_Eh[n] 		= gAc_Eo + ln(AcOx/AcRd)/cf
	
	MHCb_Eh[n] 	= imag(MHC_MeanChargeState(MHC_QQb))
	MHCa_Eh[n] 	= imag(MHC_MeanChargeState(MHC_QQa))
	
End

// ***************************************************************************
// 			Tests of Acetate-MHC electron transfer
// ***************************************************************************


Function MHC_Ac_Equilibrate()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
	
	// Acetate parameters
	Variable AcRd = 1e-3
	Variable AcOx = AcRd/10
	Variable ConstAc = 0

	// Set the initial MHC redox state
	Variable QQb = MHC_SetChargeStates(-0.13,MHC_QQb)
	
	Variable i=0, j=0, nSteps = 50000, dt=1, rStep=100
	
	Variable nReporting = nSteps/rStep
	Make /O/N=(nReporting) Ac_C, MHCb_Q, Ac_Eh//, Ac_Ket=0
//	Make /O/N=(11,nReporting+1) Ket_array=NaN, dAc_array=NaN, DGf_array=NaN
	
	Variable SaveLast=1
	if (SaveLast)
		Duplicate /O Ac_C, Ac_C_last
		Duplicate /O MHCb_Q, MHCb_Q_last
		Duplicate /O Ac_Eh, Ac_Eh_last
	endif
	
	Variable /G MSref2=StartMSTimer, gIndex1=0, gIndex2=0
	do
		
		if (mod(i,rStep)==0)
			DoUpdate	 	// Some reporting
			Ac_C[j] 		= AcRd
			Ac_Eh[j] 		= gAc_Eo + ln(AcOx/AcRd)/cf
			MHCb_Q[j] 	= imag(MHC_MeanChargeState(MHC_QQb))
			j += 1
		endif
		
		// This is the important step
		MHC_Ac_ET_step(dt,AcRd,AcOx,ConstAc,MHC_QQb)
		
		i+=1
		gIndex1+=1
	while(i < nSteps)
	print " 	*** ",nSteps," iterations took",StopMSTimer(MSref2)/1000,"s"
End





// ***************************************************************************
// 			Tests of MHC-MHC cyclic voltammetry
// ***************************************************************************

Function MHC_CV()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQa 			= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 			= root:BIOFILM:Globals:MHC_QQb
	
	NVAR gCb 		= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	NVAR gCa 		= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2

	Variable i, j, QQcv, MHC_Eh
	
	// CV parameters
	Variable EA, EAstart=-0.45, EAstop=0.2, EAdE=0.01, EAtime=1000000, EAdt=1000
	Variable EAEPts = abs(EAstart-EAstop)/EAdE
	Variable EATPts = EAtime/EAdt
	
	Make /O/N=(EAEPts) MHC_CVja=0, MHC_CVjb=0, MHCa_Q=0, MHCb_Q=0
	SetScale /P x, EAstart, EAdE, "V vs NHE", MHC_CVja, MHC_CVjb, MHCa_Q, MHCb_Q
	
	Variable QQa 	= MHC_SetChargeStates(-0.13,MHC_QQa)
	Variable QQb = MHC_SetChargeStates(-0.3,MHC_QQb)

	// Oxidizing scan
	for (i=0;i<EAEPts;i+=1)
		
		EA = EAstart + i*EAdE
		
		// The current from the anode MHCs (instantaneous)
		MHC_CVja[i] 	= -1*gCa*MHC_SetChargeStates(EA,MHC_QQa)/EAtime
		
		QQcv = 0
		for (j=0;j<EATPts;j+=1)
			// The charge from the biofilm MHC for the duration at this EA
			QQcv -= MHC_ET_step(EAdt,1,MHC_QQa,MHC_QQb)
		endfor
		
		// Convert to current
		MHC_CVjb[i] = QQcv/EAtime
		
		MHCa_Q[i] = real(MHC_MeanChargeState(MHC_QQa))
		MHCb_Q[i] = real(MHC_MeanChargeState(MHC_QQb))
		DoUpdate
	
	endfor
	
	MHC_CVja[0] = 0
End

// ***************************************************************************
// 			Tests of MHC-MHC electron transfer
// ***************************************************************************

Function MHC_Equilibrate()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQa 			= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 			= root:BIOFILM:Globals:MHC_QQb
	
	Variable QQa 	= MHC_SetChargeStates(-0.13,MHC_QQa)
	Variable QQb = MHC_SetChargeStates(-0.16,MHC_QQb)
	
	Variable i=0, j=0, nSteps = 10000, dt=100, rStep=100
	
	Make /O/N=(nSteps) MHC_et=0
	Make /O/N=(nSteps/rStep) MHCa_Q=0, MHCb_Q=0
	
	Variable /G gIndex=0
	
	Variable ref1=StartMSTimer
	do
	
		MHC_et[i] = MHC_ET_step(dt,0,MHC_QQa,MHC_QQb)
		
		if (mod(i,rStep)==0)
			DoUpdate	 	// This approximately doubles the duration
			MHCa_Q[j] = real(MHC_MeanChargeState(MHC_QQa))
			MHCb_Q[j] = real(MHC_MeanChargeState(MHC_QQb))
			j += 1
		endif
		
		i+=1
		gIndex += 1
	while(i < nSteps)
	print " 	*** ",nSteps," iterations took",StopMSTimer(ref1)/1000,"s"
End



































//
//
//
//Function MHC_Poise()
//
//	Initialize_MHC_kinetics()
//	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa
//	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
//	
//	if (GetPoiseParameters() == 0)
//		return 0
//	endif
//	NVAR gPsNew 			= root:BIOFILM:Globals:gPsNew 		// 	Flag to restart vs continue
//	NVAR gPsAcetate 		= root:BIOFILM:Globals:gPsAcetate 	// 	The initial acetate concentration
//	NVAR gPsEa 				= root:BIOFILM:Globals:gPsEa 		// 	The Anode potential (V vs NHS)
//	NVAR gPsTime 			= root:BIOFILM:Globals:gPsTime 		// 	Poising time in HOURS
//	NVAR gPsStep 			= root:BIOFILM:Globals:gPsStep 		// 	Poise time step in SECONDS
//	
//	Variable iStart = 0, RecordFlag = 1, C_AcOx, C_AcRed, QQ_Tot
//	Variable TimeStep, PrevPoiseSteps = 0
//	Variable PoiseTimeSec 	= gPsTime*3600
//	Variable NPoiseSteps 	= trunc(PoiseTimeSec/gPsStep)
//	
//	if (gPsNew==1)
//		// ***      Concentration vs Time waves --- for POISING
//		Make /O/D/N=(NPoiseSteps) cAcRed = 0 			// The concentration of "reduced acetate" - i.e., the substrate
//		Make /O/D/N=(NPoiseSteps) cAcOx = 0 				// The concentration of "oxidized acetate" - i.e., the products
//		Make /O/D/N=(NPoiseSteps) cQQa = NaN				// The charge state of the MHCs on the anode
//		Make /O/D/N=(NPoiseSteps) cQQb = NaN				// The charge state of the MHCs in the biofilm
//		Make /O/D/N=(NPoiseSteps) cIIa = 0					// The current due to the Anode-attached MHCs
//		Make /O/D/N=(NPoiseSteps) cIIb = 0					// The current due to theBiofilm MHCs
//		Make /O/D/N=(NPoiseSteps) cIIAc = 0				// The current due Acetate oxidation
//		Make /O/D/N=(NPoiseSteps) cEa = 0					// The Anode poise potential
//		
//		SetScale /P x, 0, gPsStep, "s" cAcRed, cAcOx, cQQa, cQQb, cEa, cIIa, cIIb, cIIAc
//
//		// Initially, the MHCs are completely uncharged. 
//		MHC_QQa 	= 0
//		MHC_QQa[0] = 1
//		MHC_QQb 	= 0
//		MHC_QQb[0] = 1
//		
//		// Initiall, a small amount of oxidized acetate and the requested concentration. 
//		C_AcOx 		= 1e-5
//		C_AcRed 	= gPsAcetate
//	
//		Print " 	*** Poising a new biofilm for",gPsTime,"hours at",TimeStep,"per step, at Ea =",gPsEa,"V vs NHE and [Ac]o =",C_AcRed
//	else
//		PrevPoiseSteps = DimSize(cAcRed,0)
//		iStart 			= PrevPoiseSteps
//		Redimension /N=(PrevPoiseSteps+NPoiseSteps) cAcRed, cAcOx, cQQa, cQQb, cEa, cIIa, cIIb, cIIAc
//		
//		C_AcOx 		= cAcOx[PrevPoiseSteps-1]
//		C_AcRed 		= cAcRed[PrevPoiseSteps-1]
////		C_AcRed 		= gPsAcetate		// option to add acetate when restarting 
//	
//		Print " 	*** Poising existing biofilm for",gPsTime,"hours at",TimeStep,"per step, at Ea =",gPsEa,"V vs NHE and [Ac]o =",C_AcRed
//	endif
//	
//	TimeStep = PoiseTimeSec/NPoiseSteps
//	
//	QQ_Tot = MHC_PoiseAnodePotential(PoiseTimeSec,NPoiseSteps,gPsEa,iStart,C_AcRed,C_AcOx,RecordFlag)
//	
////	print QQ_Tot
//	
//	return 1
//End
//
//
//// Poise the system at a single anode potential for time tt, and record the current transfered to the Anode. 
//// 		tt 	= length of time to poise the system, s
//// 		Ea 	= Anode potential, V vs NHE
//
//// 		C_AcRed 	= "reduced" acetate concentration, M
//// 		C_AcOx 	= "oxidized" acetate concentration, M
//
//// 		MHC_QQb = matrix of the proportions of biofilm MHCs with different charge states
//// 		QQb 		= average charge state of the biofilm MHCs
////
//// 		Returns the total charge passed to the Anode
//// 		Updates the Acetate concentrations
//
//Function MHC_PoiseAnodePotential(tt,nsteps,Ea,iStart,C_AcRed,C_AcOx,RecordFlag)
//	Variable tt,nsteps,Ea,iStart,&C_AcRed,&C_AcOx,RecordFlag
//	
//	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa
//	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
//	WAVE MHC_QQt 		= root:BIOFILM:Globals:MHC_QQt
//	WAVE MHC_KAc 		= root:BIOFILM:Globals:MHC_KAc
//	
//	NVAR gC_MHCb 			= root:BIOFILM:Globals:gC_MHCb 		// The concentration of MHC's in the biofilm
//	NVAR gC_MHCa 			= root:BIOFILM:Globals:gC_MHCa 		// The concentration of MHC's on the anode
//	NVAR gC_Enz 			= root:BIOFILM:Globals:gC_Enz 			// The concentration of respiration enzymes
//	
//	NVAR gMHC_Eo 			= root:BIOFILM:Globals:gMHC_Eo 		// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
//	NVAR gMHC_dE 			= root:BIOFILM:Globals:gMHC_dE			// Increment in MHC redox potential for a unit change in charge state, in V
//	NVAR gMHC_QMax 		= root:BIOFILM:Globals:gMHC_QMax		// # charge states per MHC
//	NVAR gMHC_L 			= root:BIOFILM:Globals:gMHC_L			// Reorganization energy, in eV
//	
//	// Optional: follow concentrations with time in a single poising step
//	WAVE cQQ 				= root:BIOFILM:Globals:cQQ
//	WAVE cAcRed 			= root:BIOFILM:Globals:cAcRed
//	WAVE cAcOx 			= root:BIOFILM:Globals:cAcOx
//	WAVE cEa 				= root:BIOFILM:Globals:cEa
//	WAVE cIIa 				= root:BIOFILM:Globals:cIIa
//	WAVE cIIb 				= root:BIOFILM:Globals:cIIb
//	WAVE cIIAc 				= root:BIOFILM:Globals:cIIAc
//	
//	// Calculate the incremental time step
//	Variable i=0, j, dI, dt
//	
//	// dt is the incremental time step
//	dt = tt/nsteps
//	
//	Variable ETa=0, ETb=0, ETAc=0, ET=0, Total_QQ=0
//	
//	// ------- Set the charge state of the MHCs on the anode --------------
////	ETa = MHC_SetChargeStates(Ea,gMHC_Eo,gMHC_dE,gMHC_QMax,MHC_QQa,MHC_QQt)
//	// -----------------------------------------------------
//	
//	// Loop through small time increments
//	for (i=0;i<nsteps;i+=1)
//		
//		if (RecordFlag && (mod(i,1000)==0))
//			DoUpdate
//		endif
//		
//		// 	----- *** RESPIRATION - reduction of Biofilm MHCs -------
//		ETAc = Charge_Ac_To_MHCb(dt,C_AcRed,C_AcOx,gC_MHCb,gC_Enz,gMHC_L,gMHC_Eo,gMHC_dE,gMHC_QMax,MHC_QQb)
//		// -----------------------------------------------------
//		
//		// 	----- *** CURRENT - reduction of Anode MHCs and the Anode -------
//		ETb = Charge_MHCb_to_MHCa(dt,MHC_QQa,MHC_QQb)
//		// -----------------------------------------------------
//		
//		// The measured current is (i) change in MHCa charge state and (ii) flux from biofilm
//		ET += ETa + ETb
//		
//		//Optionally save the trends with time
//		if (RecordFlag)
//			cQQ[iStart+i] 		= MHC_MeanChargeState(MHC_QQb)
//			cAcRed[iStart+i] 	= C_AcRed
//			cAcOx[iStart+i] 		= C_AcOx
//			cIIa[iStart+i] 			=  ETa/dt
//			cIIb[iStart+i] 			=  ETb/dt
//			cIIAc[iStart+i] 		=  ETAc/dt
//			cEa[iStart+i] 			= Ea
//		endif
//		
//	endfor
//	
//	// Output the electron flux (# electrons transferred to the anode divided by the poising time step)
//	return ET/tt
//	
//	// Output the current, which needs the Coulomb
//	return cCoulomb * ET/tt
//End

//// ***************************************************************************
//// 				Charge transfered from Acetate Respiration to biofilm MHCs
//// ***************************************************************************
//
//// 		Currently, this does not really consider rates of enzymmatic acetate reduction
//// 		It only considers acetate to be a redox species that can reduce MHCs by ET
//Function Charge_Ac_To_MHCb(dt,C_AcRed,C_AcOx,C_MHC,C_X,lambda,MHC_Eo,MHC_dE,MHC_QMax,MHC_QQb)
//	Variable dt,&C_AcRed, &C_AcOx, C_MHC, C_X, lambda, MHC_Eo,MHC_dE,MHC_QMax
//	Wave MHC_QQb
//
//	Variable j, E_Ac, E_MHC, MHC_Eoj, C_MHC_Ox
//	Variable QQ_Ox, QQ_Red, DG_eV, K_Xet, dAc, ET=0
//	Variable small =1e-6
//	
//	// Record the change in these parameters across the potential range
//	WAVE Array_DG 	= Array_DG
//	WAVE Array_KAc 	= Array_KAc
//	WAVE Array_dAc 	= Array_dAc
//	
//	// Values for a single potential
//	WAVE MHC_DG 		= MHC_DG
//	WAVE MHC_KAc 	= MHC_KAc
//	WAVE MHC_dAc 	= MHC_dAc
//	
//	ET = 0
//	
//	// Loop through all the MHC populations that can be reduced. 
//	// The last state, Q=10, cannot be reduced, so stop at (MHC_QMax-1)
//	for (j=0;j<(MHC_QMax-1);j+=1)
//		
//		// Redox potential of the acetate + respiration enzyme system
//		E_Ac 		= E_Acetate(C_AcRed,C_AcOx)
//		
//		// Formal redox potential for the (j)-to-(j+1) 
//		MHC_Eoj 	= MHC_Eo + j*MHC_dE
//		
//		// Nernst correction
//		QQ_Ox 	= MHC_QQb[j]
//		QQ_Red 	= MHC_QQb[j+1]
//	
////		E_MHC 		= MHC_Eoj							// standard redox contribution
////		E_MHC 		= -1 * cf*ln(QQ_Red/QQ_Ox)		// Nernstian contribution
//		E_MHC 		= MHC_Eoj - cf*ln(QQ_Red/QQ_Ox)
//		
//		// The change in free energy for MHC reduction by acetate, in eV
//		DG_eV		= (E_Ac - E_MHC)//cFaraday
////		DG_eV 		= min(0,DG_eV)
//		
//		// The rate constant for homogenous electron transfer, based on 
////		K_Xet 		= K_HomogenET(DG_eV,lambda)		// Marcus-Hush
////		K_Xet 		= K_DiffHomoET(DG_eV,0.05)			// activation energy free Marcus-Hush	
//		
//		// The actual concentration of the oxidized MHCs
//		C_MHC_Ox 	= C_MHC * QQ_Ox
//		
//		// The actual ET is propotional to:
//		// 	1. Concentration of oxidized MHCs
//		// 	2. Concentration of the complexes {Ac-X}. Note that this is not a proper treatment. 
//		
////		dAc 	= dt * K_Xet * C_MHC_Ox * C_AcRed * C_X	
//		dAc 	= dt * K_Xet * C_MHC_Ox * C_X
////		dAc 	= K_Xet * C_MHC_Ox
//		
////		MHC_Kac[j] = K_Xet
////		MHC_dAc[j] = dAc
////		MHC_DG[j] = DG_eV
////		MHC_DG[j] = E_MHC
//		
//		// Update the acetate concentration (Disable this for development)
////		C_AcRed -= dAc
////		C_AcOx += dAc
//		
//		// Update the MHC charge including the reaction stoichiometry of 8 e's per acetate 
//		MHC_QQb[j] -= 8*dAc/C_MHC
//		MHC_QQb[j+1] += 8*dAc/C_MHC
//		
//		ET += 8 * dAc
//	endfor
//	
////	Array_KAc[ee][]	 	= MHC_KAc[q]
////	Array_dAc[ee][]	 	= MHC_dAc[q]
////	Array_DG[ee][]	 	= MHC_DG[q]
//	
////	return DG_eV
////	return mean(MHC_DG)
//	return ET
//End




//// The electrochemical potential of acetate 
//Function E_Acetate(C_AcRed,C_AcOx)
//	Variable C_AcRed, C_AcOx
//	
//	NVAR gAc_Eo 		= root:BIOFILM:Globals:gAc_Eo
//	
//	Variable Nernst 	= cR*298*ln(C_AcOx/C_AcRed)/cFaraday
//
//	return gAc_Eo + Nernst
//End
//
//Function Show_ET_kinetics()
//	
//	Variable lambda = 0.8, vK=1
//	Make /O/D/N=(201) DG, K_eff, K_Homo
//	DG[] 	=-1.2+p*0.012
//	
//	K_Homo[] 	= K_HomoMarcusET(vK,DG[p],lambda)
//	K_eff[] 		= K_DiffHomoET(vK,DG[p],0.05)
//	
//End
//
//
//// For lambda = 0.8, Df = 0.05 is good. 
//// This is not bad . It does not go to zero at zero DG - problem? 
//Function K_DiffHomoET(vK,DG,Df)
//	Variable vK,DG,Df
//	
//	Variable DG_act, K_mh, K_eff
//	
//	DG_act  	= (DG)^2/4
//	K_mh 		= vK*exp(-1*(cFaraday*(DG_act))/(cR*298))
//	
//	
//	if (DG>0)
//		return 0
////		return Df/(Df+1) - Df/(Df+1)
//	endif
//	
//	K_eff 		= Df/(Df+K_mh) - Df/(Df+1)
//	
//	return K_eff
//End
//
//Function K_DiffHomoET_XX(DG,Df,Nm,lambda)
//	Variable DG,Df,Nm, lambda
//	
//	Variable DG_act, K_mh, K_eff
//	
//	DG_act  	= (lambda + DG)^2/(4*lambda)
//	DG_act  	= DG^2/4
//	
//	K_mh 		= exp(-1*(cFaraday*(DG_act))/(cR*298))
//	
//	K_eff 		= Nm * (1/(Df+K_mh))
//	
//	return K_eff
//End
















//Function MHC_Ac_ET_step_v1(dt,AcRd,AcOx,QQ)
//	Variable dt,&AcRd,&AcOx
//	Wave QQ
//	
//	NVAR gCb 		= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
//	WAVE QQt 		= root:BIOFILM:Globals:MHC_QQt			// A temporary array
//	NVAR gIndex2 	= root:BIOFILM:Globals:gIndex2			// A temporary array
//		
//	Variable QMax 	= DimSize(QQ,0)					// The total number of electron occupation states (= 11)
//	
//	Variable dummy
//	Variable i, j, Ket, dQQ, ETpred, ETposs, ETtot=0
//	
//	// This rate is linear in the difference of Eh for the Acetate and MHC populations
//	Ket 		= MHC_Ac_ET_rate(QQ,AcRd,AcOx)
//	
//	// The predicted electron transfer
//	// Really, the concentration of biofilm MHCs, Cb, should be the "concentration of reducible MHCs", but let's fix that below. 
//	ETpred 	= 8 * gCb * AcRd * (1 - exp(-1*dt*Ket))
//	dummy = 1 - exp(-1*dt*Ket)
//	gIndex2 = 0
//	
//	// Now, how should these electrons be distributed among the MHC population? 
//	// Simplest approach is to distribute equally and then enforce charge balance
//	
//	// Loop over the REDUCIBLE states to calculate the population transfers
//	// The problem here is if 8*AcRd > Cb then we might be trying to "overcharge" each population
//	// Crude solution is to set a maximum single electron per population
//	// Need to check this carefully and adjust the Ac-MHC rate constant
//	for (i=0;i<QMax-1;i+=1)
//		ETposs = min(1,ETpred/gCb)
//		ETtot += ETposs
//		
//		QQt[i] = ETposs * QQ[i]
//		
//		gIndex2 += 1
//	endfor
//	
//	// Apply the changes to each of the redox pairs
//	for (i=0;i<QMax-1;i+=1)
//		QQ[i] 		-= QQt[i]
//		QQ[i+1] 	+= QQt[i]
//	endfor
//	
//	AcRd -= (ETtot*gCb)/8
//	AcOx += (ETtot*gCb)/8
//End

//// Acetate to MHC electron transfer - somewhat approximate basis
//// 	Assume that the MHCs are equilibrating with a solution redox potential that is set by Acetate respiration
////	Calculate a Eh + Nernst for a hypothetic redox couple of Ac-Rd  <--->  Ac-Oc + e-
////	Then seems simplest to imagine a linear rate constant
//// 	FORWARD ET only
//Function MHC_Ac_ET_rate(MHC_QQ,AcRd,AcOx)
//	Wave MHC_QQ
//	Variable AcRd,AcOx
//	
//	NVAR 	Ac_Eo 		= root:BIOFILM:Globals:gAc_Eo		// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
//	NVAR 	Ac_Ko 		= root:BIOFILM:Globals:gAc_Ko		// Prefactor for Acetate-to-MHC electron transfer
//	
//	Variable MHC_Eh, Ac_Eh, DG, Ket
//	
//	MHC_Eh 	= imag(MHC_MeanChargeState(MHC_QQ))
//	
//	Ac_Eh 	= Ac_Eo  + ln(AcOx/AcRd)/cf
//	
//	Ket 		= -1 * Ac_Ko*(Ac_Eh-MHC_Eh) 
//	
//	return max(0,Ket)
//End





Function Loop_Test()
	
	NewDataFolder /S/O root:Biofilm
	
	Variable gMHC_QMax = 11, gMHC_Eo=-0.05, gMHC_dE=-0.031
	
	Make /O/D/N=(gMHC_QMax) MHC_QQa={0.014,0.0321,0.0216,0.437,0.263,0.047,0.002,4e-5,2e-7,2e-10,1e-13} 
	Make /O/D/N=(gMHC_QMax) MHC_QQb={0.0004,0.0134,0.1335,0.397,0.353,0.094,0.0075,0.00017,1e-6,3e-9,2e-12}
	Make /O/D/N=(gMHC_QMax) MHC_QQt
	Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_Kab
	
	SetScale /P x, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_QQa, MHC_QQb, MHC_Kab
	SetScale /P y, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_Kab
	
	Variable i=0, j=0, nSteps = 100000, dt=10, rStep=1000
	
	Make /O/N=(nSteps) MHC_et=NaN
	Make /O/N=(nSteps/rStep) MHCa_Q=0, MHCb_Q=0
	
	Variable /G gIndex=0
	
	do
	
		MHC_et[i] = Funct_Test(dt,1,MHC_QQa,MHC_QQb)
		
		i+=1
		gIndex += 1
	while(i < nSteps)
	
	print i
End

Function Funct_Test(dt,AnodeFlag,QQa,QQb)
	Variable dt,AnodeFlag
	Wave QQa, QQb
	
	WAVE Kba = root:Biofilm:MHC_Kab
	
	Variable FWDFlag=1, REVFlag=1, QMax=11
	Variable i, j, Ket=0.1, EE, EEtot
	Variable gCa=1e-3, gCb=1e-3
	
	// Loop over all the Qmax populations
	for (i=0;i<QMax;i+=1)
		for (j=0; j<QMax;j+=1)
		
			if (FWDFlag)
				
				if (QQa[i]==0 || QQb[j]==0)
					// do nothing
				elseif (j == (Qmax-1))
				
				elseif (i == 0)
				
				else
					
					// This seems to be causing a problem
					EE = (1 - exp(-1*dt*Ket))
					
					EEtot += EE	
					
				endif
			endif
		
		endfor
	endfor
	
	return EEtot
	
End