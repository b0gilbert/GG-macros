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

Function CalculateMHCParams(deltaE)
	Variable deltaE
	
	// These are the "standard" values
	Variable QMax = 11, Eo=-0.05, dE = -0.025
	
	Variable Emid = (Eo + ((QMax-1)*dE)/2)
	
	Variable Erange = ((QMax-1)*deltaE)
	
	Variable Ehalf = ((QMax-1)*deltaE)/2
	
	Variable Estart = Emid - Ehalf

	NVAR gMHC_Eo 					= root:BIOFILM:Globals:gMHC_Eo
	NVAR gMHC_dE 					= root:BIOFILM:Globals:gMHC_dE
	
	gMHC_Eo = Estart
	gMHC_dE = deltaE
	
	print " *** Set gMHC_Eo to ",gMHC_Eo,"and gMHC_dE to ",gMHC_dE

	// Debug
//	Variable Emid2 = (Estart + ((QMax-1)*deltaE)/2)
//	print Eo, Emid, Estart, Emid2
		
End

Static Function ManuallySet_MHC_kinetics()

		// *** CRITICAL RATE CONSTANTS

		Variable /G gMHC_dE 		= -0.025			// Increment in MHC redox potential for a unit change in charge state, in V
		Variable /G gMHC_Eo		= -0.05			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
//		Variable /G gMHC_dE 		= -0.025			// Increment in MHC redox potential for a unit change in charge state, in V
//		Variable /G gMHC_Eo		= -0.05			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
		
		// Multi-heme cytochrome parameters		// 			GOOD VALUES
//		Variable /G gMHC_dE 		= -0.031			// Increment in MHC redox potential for a unit change in charge state, in V
//		Variable /G gMHC_Eo		= -0.05			// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
		Variable /G gMHC_QMax 	= 11 				// # charge states per MHC. Note that 10 hemes = 11 charge states
		
//		Variable /G gMHC_QMax 	= 10 				// # charge states per MHC. Note that 10 hemes = 11 charge states
//		Variable /G gMHC_Eo		= -0.1				// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
		
		// *** Acetate Respiration and electron transfer to biofilm MHC(s)
		Variable /G gAc_Eo 			= -0.2				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
		Variable /G gAc_dAc		= 0.1
		
		Variable /G gAc_L			= 0.8				// Reorganization energy, in eV, for acetate-to-MHC ET
		Variable /G gAc_vK			= 80				// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
//		Variable /G gAc_L			= 0.8				// Reorganization energy, in eV, for acetate-to-MHC ET
//		Variable /G gAc_vK			= 0.1				// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
		
		// *** MHC - to - MHC electron transfer
		Variable /G gMHC_L			= 0.8				// Reorganization energy, in eV, for MHC-to-MHC ET
		Variable /G gMHC_vK		= 80 				// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
//		Variable /G gMHC_L			= 0.8				// Reorganization energy, in eV, for MHC-to-MHC ET								// good
//		Variable /G gMHC_vK		= 0.2 				// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity) // good
		
		// *** Anode-MHC to Anode ET -- currently permanent equilbrium so none of these are actually used

//		Variable /G gAc_Ko 			= 1e-5				// Prefactor for Acetate-to-MHC electron transfer
//		Variable /G gC_Enz		= 0.0001 			// Fixed concentration of Respiration Enzymes, in moles per liter
//		Variable /G gAc_K1 		= 1				// Rate constant for formation of Acetate--Enzyme complex
//		Variable /G gAc_K2 		= 0.0003			// Rate constant for breakup of Acetate--Enzyme complex
End

, root:Biofilm:Globals:MHC_QQaMin, root:Biofilm:Globals:MHC_QQaMax

Function Initialize_MHC_kinetics()
	
	Variable i, j
	
	NewDataFolder /S/O root:BIOFILM
		NewDataFolder /S/O root:BIOFILM:Globals
		
	ManuallySet_MHC_kinetics()
	
	CalculateMHCParams(-0.025)
//	CalculateMHCParams(-0.00025)
		
		NVAR gMHC_QMax 				= root:BIOFILM:Globals:gMHC_QMax
		NVAR gMHC_Eo 					= root:BIOFILM:Globals:gMHC_Eo
		NVAR gMHC_dE 					= root:BIOFILM:Globals:gMHC_dE
	
		// 1D arrays that record the populations of the MHCs with different charge states. 
		Make /O/D/N=(gMHC_QMax) MHC_QQa, MHC_QQb, MHC_QQc
		Make /O/D/N=(gMHC_QMax) MHC_QQt, MHC_QQf=0, MHC_QQr=0
		
		Make /O/D/N=(gMHC_QMax) MHC_QQaMin, MHC_QQbMin, MHC_QQcMin
		Make /O/D/N=(gMHC_QMax) MHC_QQaMax, MHC_QQbMax, MHC_QQcMax
		Variable /G gQQaMin=999, gQQbMin=999, gQQcMin=999, gQQaMax=-999, gQQbMax=-999, gQQcMax=-999
		
		// 2D arrays that record parameters for MHC-to-MHC electron transfer
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_DGab 			// Standard Gibbs free energy for the reaction
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_Kab			// Forward rate constants for the reaction
		Make /O/D/N=(gMHC_QMax,gMHC_QMax) MHC_Kba			// Reverse rate constants for the reaction
		
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_DGab 		// Standard Gibbs free energy for the reaction
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_Kab			// Forward rate constants for the reaction
//		Make /O/D/N=(gMHC_QMax-1,gMHC_QMax-1) MHC_Kba			// Reverse rate constants for the reaction
		
		SetScale /P x, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_QQa, MHC_QQb, MHC_QQc, MHC_QQt, MHC_QQf, MHC_QQr, MHC_Kab, MHC_Kba
		SetScale /P y, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_DGab, MHC_Kab, MHC_Kba
		SetScale /P x, gMHC_Eo, gMHC_dE, "V vs NHE" MHC_QQaMin, MHC_QQbMin, MHC_QQcMin, MHC_QQaMax, MHC_QQbMax, MHC_QQcMax
		
		// Calculate the Marcus expression for forward and reverse ET rates based on standard DGs for ET
		MHC_MHC_ET_rates(MHC_Kab,MHC_Kba)
		
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
		if (Prompt_AcetateConc() == 0)
			return 0
		endif
		if (Prompt_PoiseSettings() == 0)
			return 0
		endif
		if (Prompt_SSCVSettings() == 0)
			return 0
		endif
	SetDataFolder root:BIOFILM
	
	//  ------ MHC parameters
	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb		
	WAVE MHC_QQc 		= root:BIOFILM:Globals:MHC_QQc
	
	NVAR gQQai 				= root:BIOFILM:Globals:gQQai
	NVAR gQQbi 				= root:BIOFILM:Globals:gQQbi
	NVAR gQQci 				= root:BIOFILM:Globals:gQQci
	
	NVAR gCa 				= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of ANODE Multi-Heme Cytochromes, in moles per cm2
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of NON-RESPIRING Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	NVAR gCc 				= root:BIOFILM:Globals:gC_MHCc 		// Fixed concentration of RESPIRING Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	
	//  ------ Acetate parameters
	NVAR gAcRd				= root:BIOFILM:Globals:gAcRd
	NVAR gAcOx 				= root:BIOFILM:Globals:gAcOx
	Variable AcRd 			= gAcRd
	Variable AcOx 			= gAcOx
	Variable AnodeFlag 		= 1 	// Indicates QQa are bound to anode and their redox state is fixed
		
	//  ------ Poising parameters
	NVAR gPsEA 				= root:BIOFILM:Globals:gPsEA
	NVAR gPsEAdE 			= root:BIOFILM:Globals:gPsEAdE
	NVAR gPsEANSteps 		= root:BIOFILM:Globals:gPsEANSteps
	NVAR gPsEAtime 		= root:BIOFILM:Globals:gPsEAtime
	NVAR gPsEAdt 			= root:BIOFILM:Globals:gPsEAdt  
	NVAR gMovie 			= root:BIOFILM:Globals:gMovie  
	
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
	
	NVAR gMHCSim 			= root:BIOFILM:Globals:gMHCSim
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo
	
	Variable CVEPts = abs((gCVEstart-gCVEstop)/gCVdE)	// The number of anode potentials
	Variable CVTPts = gCVtime/gCVdt						// The number of time steps at each anode potential
	Variable CVRate = gCVdE/gCVtime						// The effective CV sweep rate in V/s
	Variable CVRPts = CVEPts/25								// Record 100% of the Ea steps but update every 10
	
	String MHCDir, MHCNote
	Variable i, j, k, n, QQai, CVE, QQac, QQbf, QQcv
	
	// Are we displaying during thesimulation? 
	DoWindow /F MovieMHCs
//	DoWindow /=MovieMHCs
//	Variable DisplayFlag = V_flag
	Variable DisplayFlag = 1
	Variable AddMHCa=0, ScaleMHCa=0.001
	
	MoviePath()
	Variable fRate=30
	String fName, dStr = Secs2Date(DateTime,-2)+"-"+time()
	dStr = ReplaceString(":",dStr,"-")
	dStr = StripSpacesAndSuffix(dStr,"_")
	
	if (gMovie==2)	// Movie of Poising
		fName="PoiseSim"+dStr+".mp4"
		DoWindow /F MovieMHCs
	elseif (gMovie==3)	// Movie of CV
		fName="CVSim"+dStr+".mp4"
		DoWindow /F MovieCVs
	endif
		
	if (gMovie>1)
		SavePICT/O/e=-5/SNAP=1/P=_PictGallery_ as "mhcPICT"
		NewMovie/O/PICT=mhcPICT/P=moviesPath as fName
		
		if( V_Flag!=0 )
			Print "OpenMovie failed, err= ",V_Flag
			return 0			// probably canceled
		endif
	endif
	
	Duplicate /O root:Biofilm:Sim000:CVf_cv_J, root:Biofilm:Sim000:CVf_cv_J_prev
	Duplicate /O root:Biofilm:Sim000:CVr_cv_J, root:Biofilm:Sim000:CVr_cv_J_prev
		
	// ==== The major loop across poising potential values ====
	for (k=0;k<gPsEANSteps;k+=1)
	
		MHCDir = "root:BIOFILM:Sim"+FrontPadVariable(gMHCSim+k,"0",3)
		MHCNote = MHCSimulationNote(gPsEA + k*gPsEAdE,gPsEAtime,gCVEstart,gCVEstop,CVRate)
		NewDataFolder /O/S $MHCDir
	
			Make /O/N=(PsRPts) Ps_Ac_C=NaN, Ps_Ac_Eh=0, Ps_ac_J=NaN, Ps_bf_J=NaN, Ps_cv_J=NaN					// Reporting the Poising period
			SetScale /P x, 0, (gPsEAdt*PsRStep), "s", Ps_Ac_C, Ps_Ac_Eh, Ps_ac_J, Ps_bf_J, Ps_cv_J
			DoUpdate
			
			Make /O/N=(CVEPts) CVf_Ac_C, CVf_Ac_Eh, CVf_ac_J=NaN, CVf_bf_J=NaN, CVf_cv_J=NaN, CVf_an_J=NaN		// Reporting the FORWARD CV scan
			Make /O/N=(CVEPts) CVr_Ac_C, CVr_Ac_Eh, CVr_ac_J=NaN, CVr_bf_J=NaN, CVr_cv_J=NaN, CVr_an_J=NaN		// Reporting the REVERSE CV scan
			SetScale /P x, gCVEstart, gCVdE, "V vs NHE", CVf_Ac_C, CVf_Ac_Eh, CVf_ac_J, CVf_bf_J, CVf_cv_J, CVf_an_J
			SetScale /P x, gCVEstop, -gCVdE, "V vs NHE", CVr_Ac_C, CVr_Ac_Eh, CVr_ac_J, CVr_bf_J, CVr_cv_J, CVr_an_J
			
			Note /K Ps_cv_J, MHCNote
			Note /K CVf_cv_J, MHCNote
			Note /K CVr_cv_J, MHCNote
			
			Make /O/D/N=(CVTPts) CV_Ps_ac_J, CV_Ps_bf_J, CV_Ps_cv_J 	// Time dependent traces at each CV Ea
			
			// Initial values for the MHCs
			QQai 	= gPsEA + k*gPsEAdE
			MHC_SetChargeStates(QQai,MHC_QQa)
			
			if (k==0)
				MHC_SetChargeStates(gQQbi,MHC_QQb)		// NON-RESPIRING
				MHC_SetChargeStates(gQQci,MHC_QQc)		// RESPIRING
				Duplicate /O MHC_QQa, root:Biofilm:Globals:MHC_QQa0
				Duplicate /O MHC_QQb, root:Biofilm:Globals:MHC_QQb0
				Duplicate /O MHC_QQc, root:Biofilm:Globals:MHC_QQc0
			endif
			
			Variable Poise=1
			if (Poise)				// ==== Poise at selected potential ====
				
				Variable MSref1=StartMSTimer
				i = 0; j = 0
				do
					// "Respiration" - Acetate-to-Biofilm-MHC electron transfer. Moles of electrons
					QQac 	= MHC_Ac_ET_step(gPsEAdt,AcRd,AcOx,gCc,MHC_QQc)
					
					// Equilibrate the Respiring and Non-Respiring MHCs. Moles of electrons
					QQbf 	= -1 * MHC_ET_step(gPsEAdt,0,gCb,gCc,MHC_QQb,MHC_QQc)		// <--- Set AnodeFlag=0
					
					// Equilibrate the Biofilm and Anode MHCs and record the current. Moles of electrons
					QQcv 	= -1 * MHC_ET_step(gPsEAdt,1,gCa,gCb,MHC_QQa,MHC_QQb)		// <--- Set AnodeFlag=1
					
					if (mod(i,PsRStep)==0)
						//UpdateDisplayMovie(DisplayFlag,gMovie)			// ** UPDATE MOVIE FRAME
						DoUpdate /W=MovieMHCs
						if (gMovie==2)	// Movie of Poising
							DoWindow /F MovieMHCs
							SavePICT/O/e=-5/SNAP=1/P=_PictGallery_ as "mhcPICT"
							AddMovieFrame/PICT=mhcPICT
						endif	
						
						// Convert to Coulombs/s i.e. Amperes
						Ps_ac_J[j] = cFaraday*QQac/gPsEAdt			// This current is much smaller than the other ones ... 
						Ps_bf_J[j] = cFaraday*QQbf/gPsEAdt
						Ps_cv_J[j] = cFaraday*QQcv/gPsEAdt
						
						Ps_Ac_C[j] = AcRd
						Ps_Ac_Eh[j] = gAc_Eo  + ln(AcOx/AcRd)/cf
						j += 1
						
					endif
					
					i+=1
				while(i < PsTPts)
				print " 	*** 	Poising at Ea=",QQai,"V for ",PsTPts," iterations took",StopMSTimer(MSref1)/1000,"s"
				print " 					Final current =",QQcv/gPsEAdt," and final acetate Eh = ",gAc_Eo  + ln(AcOx/AcRd)/cf	
				print " 					Respiring MHCs Eh = ", imag(MHC_MeanChargeState(MHC_QQc)),"; Biofilm MHCs Eh = ", imag(MHC_MeanChargeState(MHC_QQb)),"; Anode MHCs Eh = ", imag(MHC_MeanChargeState(MHC_QQa))
					
			endif

			// ==== FORWARD CV Scan ====
			if (gCVEChoice > 1)
				Variable MSref2=StartMSTimer
				for (n=0;n<CVEPts;n+=1)
					
					CVE = gCVEstart + n*gCVdE
					
					// *** Note *** This gives a large relative contribution so it is not currently added to the CV trace. (Check normalization!)
					if (n < 3)
						CVf_an_J[n] = NaN
					else
						CVf_an_J[n] = -1 * ScaleMHCa * cFaraday * gCa * MHC_SetChargeStates(CVE,MHC_QQa) / (gCVtime)	// <--- Divide by the total time at each Ea
					endif
										
					i = 0
					do
						// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
						QQac 	= MHC_Ac_ET_step(gCVdt,AcRd,AcOx,gCc,MHC_QQc)
						
						// Equilibrate the Respiring and Non-Respiring MHCs
						QQbf 	= -1 * MHC_ET_step(gCVdt,0,gCb,gCc,MHC_QQb,MHC_QQc)		// <--- Set AnodeFlag=0
						
						// Equilibrate the Biofilm and Anode MHCs and record the current
						QQcv 	= -1 * MHC_ET_step(gCVdt,1,gCa,gCb,MHC_QQa,MHC_QQb)			// <--- Set AnodeFlag=1

						if (mod(i,CVRPts)==0)
	//						UpdateDisplayMovie(DisplayFlag,gMovie)		// ** UPDATE MOVIE FRAME
							DoUpdate /W=MovieCVs
							if (gMovie==3)	// Movie of CV
								DoWindow /F MovieCVs
								SavePICT/O/e=-5/SNAP=1/P=_PictGallery_ as "mhcPICT"
								AddMovieFrame/PICT=mhcPICT
							endif
							UpdateQQMinMax(DisplayFlag)
						endif
					
						CV_Ps_ac_J[i] = cFaraday * QQac/gCVdt		// <--- Divide by the time step
						CV_Ps_bf_J[i] = cFaraday * QQbf/gCVdt
						CV_Ps_cv_J[i] = cFaraday * QQcv/gCVdt
						
						i+=1
					while(i < CVTPts)
					
					CVf_ac_J[n] 	= (n==0) ? NaN : mean(CV_Ps_ac_J)	 	// Exclude first point 
					CVf_bf_J[n] 	= mean(CV_Ps_bf_J)
					CVf_cv_J[n] 	= mean(CV_Ps_cv_J)
				
					if (AddMHCa && n>0)			// 2019-06 Try adding anode MHC current. Skip the first large point
						CVf_cv_J[n]  += CVf_an_J[n]
					endif
				endfor
				
				// ==== REVERSE CV Scan ====
				if (gCVEChoice > 2)
					for (n=0;n<CVEPts;n+=1)
						
						CVE = gCVEstop - n*gCVdE
						
						// *** Note *** This gives a large relative contribution so it is not currently added to the CV trace. (Check normalization!)
						CVr_an_J[n] 	= -1 * ScaleMHCa * cFaraday * gCa * MHC_SetChargeStates(CVE,MHC_QQa) / (gCVtime)	// <--- Divide by the total time at each Ea
						
						i = 0
						do
							// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
							QQac 	= MHC_Ac_ET_step(gCVdt,AcRd,AcOx,gCc,MHC_QQc)
							
							// Equilibrate the Respiring and Non-Respiring MHCs
							QQbf 	= -1 * MHC_ET_step(gCVdt,0,gCb,gCc,MHC_QQb,MHC_QQc)			// <--- Set AnodeFlag=0
							
							// Equilibrate the Biofilm and Anode MHCs and record the current
							QQcv 	= -1 * MHC_ET_step(gCVdt,1,gCa,gCb,MHC_QQa,MHC_QQb)			// <--- Set AnodeFlag=1
							
							if (mod(i,CVRPts)==0)
								//UpdateDisplayMovie(DisplayFlag,gMovie)
								DoUpdate /W=MovieCVs
								if (gMovie==3)	// Movie of CV
									DoWindow /F MovieCVs
									SavePICT/O/e=-5/SNAP=1/P=_PictGallery_ as "mhcPICT"
									AddMovieFrame/PICT=mhcPICT
								endif
								UpdateQQMinMax(DisplayFlag)
							endif
							
							CV_Ps_ac_J[i] = cFaraday * QQac/gCVdt		// <--- Divide by the time step
							CV_Ps_bf_J[i] = cFaraday * QQbf/gCVdt
							CV_Ps_cv_J[i] = cFaraday * QQcv/gCVdt
							
							i+=1
						while(i < CVTPts)
						
						CVr_ac_J[n] 	= mean(CV_Ps_ac_J)
						CVr_bf_J[n] 	= mean(CV_Ps_bf_J)
						CVr_cv_J[n] 	= mean(CV_Ps_cv_J)
						
						if (AddMHCa & n>0) 		// 2019-06 Try adding anode MHC current. 
							CVr_cv_J[n]  += CVr_an_J[n]
						endif
					endfor
					
				endif
				print " 	*** Forward and Reverse CV scan took",StopMSTimer(MSref2)/1000,"s"
				print " 					CV rate ="+num2str(CVRate*1000)+"mV/s;"
			endif

	endfor
	SetDataFolder $OldDf
	
	if (gMovie>1)
		CloseMovie
		if( V_Flag!=0 )
			Print "Close movie failed, err= ",V_Flag
		endif
		Sleep/S 1		// without this, Mac sometimes gives a file not a movie error; DoUpdate did not help
		PlayMovie/P=moviesPath as fName
	endif
End

Function UpdateQQMinMax(DisplayFlag)
	Variable DisplayFlag
	
	if (DisplayFlag!=1)
		return 0
	endif
	
	WAVE MHC_QQa 		= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb		
	WAVE MHC_QQc 		= root:BIOFILM:Globals:MHC_QQc
	
	WAVE MHC_QQaMin 		= root:BIOFILM:Globals:MHC_QQaMin
	WAVE MHC_QQaMax		= root:BIOFILM:Globals:MHC_QQaMax
	WAVE MHC_QQbMin 		= root:BIOFILM:Globals:MHC_QQbMin
	WAVE MHC_QQbMax		= root:BIOFILM:Globals:MHC_QQbMax
	WAVE MHC_QQcMin 		= root:BIOFILM:Globals:MHC_QQcMin
	WAVE MHC_QQcMax		= root:BIOFILM:Globals:MHC_QQcMax
	
	NVAR gQQaMin 				= root:BIOFILM:Globals:gQQaMin
	NVAR gQQaMax				= root:BIOFILM:Globals:gQQaMax
	NVAR gQQbMin 				= root:BIOFILM:Globals:gQQbMin
	NVAR gQQbMax				= root:BIOFILM:Globals:gQQbMax
	NVAR gQQcMin 				= root:BIOFILM:Globals:gQQcMin
	NVAR gQQcMax				= root:BIOFILM:Globals:gQQcMax
	
	Variable QQ = 	MHC_MeanChargeState(MHC_QQa)
	if (gQQaMin > QQ)
		MHC_QQaMin = MHC_QQa; gQQaMin = QQ
	endif
	if (gQQaMax < QQ)
		MHC_QQaMax = MHC_QQa; gQQaMax = QQ
	endif
	
	QQ = 	MHC_MeanChargeState(MHC_QQb)
	if (gQQbMin > QQ)
		MHC_QQbMin = MHC_QQb; gQQbMin = QQ
	endif
	if (gQQbMax < QQ)
		MHC_QQbMax = MHC_QQb; gQQbMax = QQ
	endif
	
	QQ = 	MHC_MeanChargeState(MHC_QQc)
	if (gQQcMin > QQ)
		MHC_QQcMin = MHC_QQc; gQQcMin = QQ
	endif
	if (gQQcMax < QQ)
		MHC_QQcMax = MHC_QQc; gQQcMax = QQ
	endif

End

Function UpdateDisplayMovie(DisplayFlag,MovieFlag)
	Variable DisplayFlag, MovieFlag
	
	
	if (DisplayFlag==1)
		DoUpdate /W=MovieCVs
		DoUpdate /W=MovieMHCs
		if (MovieFlag==1)
			DoWindow /F MovieCVs
			DoWindow /F MovieMHCs
			SavePICT/O/e=-5/SNAP=1/P=_PictGallery_ as "TTPICT"
			AddMovieFrame/PICT=TTPICT
//			AddMovieFrame
		endif
	endif
End

Function Prompt_MHCStates()
	
	Variable QQai = NumVarOrDefault("root:BIOFILM:Globals:gQQai",-0.5)
	Variable QQbi = NumVarOrDefault("root:BIOFILM:Globals:gQQbi",-0.15)
	Variable QQci = NumVarOrDefault("root:BIOFILM:Globals:gQQci",-0.15)
	Variable EaRev = NumVarOrDefault("root:BIOFILM:Globals:gEaRev",-0.15)
	
	Variable Ca = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCa",1e-4)	// Fixed concentration of RESPIRING MHCs in the biofilm layer, in moles per cm2
	Variable Cb = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCb",1e-4)	// Fixed concentration of NON-RESPIRING MHCs in the biofilm layer, in moles per cm2
	Variable Cc = NumVarOrDefault("root:BIOFILM:Globals:gC_MHCc",1e-4)	// Fixed concentration of NON-RESPIRING MHCs attached to the anode, in moles per cm2
	
//	Prompt QQai, "Initial redox state of Anode MHCs (vs NHE)" 	// This is not needed because it is always determined by the electrode. 
//	DoPrompt "Starting conditions", QQai, Ca, QQbi, Cb, QQci, Cc

	Prompt QQbi, "Non-respiring MHC Eh"
	Prompt QQci, "Respiring MHC Eh"
	Prompt Ca, "Anode MHC conc (moles/cm2)"
	Prompt Cb, "Non-Respiring MHC conc"
	Prompt Cc, "Respiring MHC conc"
	Prompt EaRev, "Anode reverse ET?", popup, "no;yes"
	DoPrompt "Starting conditions", Ca, EaRev, Cb, QQbi, Cc, QQci
	if (V_flag)
		return 0
	endif
	
	Variable /G	gQQai = QQai
	Variable /G	gQQbi = QQbi
	Variable /G	gQQci = QQci
	
	Variable /G	gC_MHCa = Ca
	Variable /G	gC_MHCb = Cb
	Variable /G	gC_MHCc = Cc
	
	Variable /G	gEaRev = EaRev
End

Function Prompt_AcetateConc()
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo	
	
	Variable AcRd = NumVarOrDefault("root:BIOFILM:Globals:gAcRd",0.025)
	Variable AcOx = NumVarOrDefault("root:BIOFILM:Globals:gAcOx",0.001)
	Variable FixAcRd = NumVarOrDefault("root:BIOFILM:Globals:gFixAcRd",0)
	Variable FixAcOx = NumVarOrDefault("root:BIOFILM:Globals:gFixAcOx",0)
	Variable AcFwd = NumVarOrDefault("root:BIOFILM:Globals:gAcFwd",0)
	Variable AcRev = NumVarOrDefault("root:BIOFILM:Globals:gAcRev",0)
	
	Prompt AcRd, "Initial acetate conc (M)"
	Prompt FixAcRd, "Fix acetate conc?", popup, "no;yes"
	Prompt AcOx, "Initial product conc (M)"
	Prompt FixAcOx, "Fix product conc?", popup, "no;yes"
	Prompt AcFwd, "Acetate oxidation?", popup, "no;yes"
	Prompt AcRev, "Product oxidation?", popup, "no;yes"
	DoPrompt "Starting conditions", AcRd, AcOx, FixAcRd, FixAcOx, AcFwd, AcRev
	if (V_flag)
		return 0
	endif
	
	Variable /G	gAcRd = AcRd
	Variable /G	gAcOx = AcOx
	Variable /G	gFixAcRd = FixAcRd
	Variable /G	gFixAcOx = FixAcOx
	Variable /G	gAcFwd = AcFwd
	Variable /G	gAcRev = AcRev
	
	Variable Ac_Eh 	= gAc_Eo  + ln(AcOx/AcRd)/cf
	Print " *** 	The starting redox potential for acetate in the biofilm is",Ac_Eh,"V vs NHE"
End

Function Prompt_PoiseSettings()

	Variable PsEA 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEA",-0.45) 
	Variable PsEAdE 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEAdE",0.6) 
	Variable PsEANSteps 	= NumVarOrDefault("root:BIOFILM:Globals:gPsEANSteps",1) 
	Variable PsEAtime 		= NumVarOrDefault("root:BIOFILM:Globals:gPsEAtime",1000000)
	Variable PsEAdt 			= NumVarOrDefault("root:BIOFILM:Globals:gPsEAdt",200) 
	
	Variable MHCMovie 		= NumVarOrDefault("root:BIOFILM:Globals:gMovie",1)
	Variable MHCSim 		= NumVarOrDefault("root:BIOFILM:Globals:gMHCSim",0)
	
	Prompt PsEA, "First anode potential (vs NHE)"
	Prompt PsEAdE, "Anode potential step"
	Prompt PsEANSteps, "Number of steps"
	Prompt PsEAtime, "Poise duration (s)"
	Prompt PsEAdt, "Poise time step"
	Prompt MHCMovie, "Record animation?", popup, "no;Poising;CV"
	Prompt MHCSim, "Starting Sim #"
	DoPrompt "Starting conditions", PsEA, PsEAdE, PsEANSteps, PsEAtime, PsEAdt, MHCMovie, MHCSim
	if (V_flag)
		return 0
	endif
	
	Variable /G	gPsEA = PsEA
	Variable /G	gPsEAdE = PsEAdE
	Variable /G	gPsEANSteps = PsEANSteps
	Variable /G	gPsEAtime = PsEAtime
	Variable /G	gPsEAdt = PsEAdt
	Variable /G	gMHCSim = MHCSim
	Variable /G	gMovie = MHCMovie
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
	Prompt CVtime, "Poising time at each CV point, t (s)"
	Prompt CVdt, "Poising time step, dt, (s)"
	DoPrompt "Cyclic voltammetry settings", CVEChoice, CVEstart, CVEstop, CVdE, CVtime, CVdt
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

Function MoviePath()
	PathInfo moviesPath
	if( V_Flag==0 )
		NewPath/Q moviesPath,  SpecialDirPath("Igor Pro User Files", 0, 0, 0 )
		if( V_Flag != 0 )
			return 1		// abort or failure
		endif
	endif
	return 0
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
	
	String CVType, CVNote, TName, EAStr, CVList = ReturnSimDataFolders()
	Variable i, NCVs = ItemsInList(CVList)
	
	if (NCVs == 0)
		return 0
	endif
	
	SVAR gSimPlotChoice 		= root:BIOFILM:Globals:gSimPlotChoice
	SVAR gSimPlotCmpt 		= root:BIOFILM:Globals:gSimPlotCmpt
	CVType 	= gSimPlotChoice+gSimPlotCmpt
	
	WAVE CVWave 	= $(StringFromList(0,CVList)+":"+CVType)
	if (!WaveExists(CVWave))
		return 0
	endif
	CVNote = note(CVWave)
	EAStr = StringByKey("PoiseEA",CVNote,"=")
	TName = NameOfWave(CVWave)+" Ea="+EAStr
	
	DoWindow /K $CVType
	Display /K=1/N=$CVType/W=(424,348,1170,754) CVWave/TN=$TName as CVType
	
	
	ModifyGraph zero(left)=4
	ModifyGraph mirror=2
	ModifyGraph fSize=18
	ModifyGraph lowTrip(left)=0.001
	
	Label left "Current"
	
	for (i=1;i<NCVs;i+=1)
		WAVE CVWave 	= $(StringFromList(i,CVList)+":"+CVType)
		EAStr = StringByKey("PoiseEA",note(CVWave),"=")
		TName = NameOfWave(CVWave)+" Ea="+EAStr
		AppendToGraph /W=$CVType CVWave/TN=$TName
	endfor
	
	ColorPlotTraces()
	AddLegend()
End

Function /T ReturnSimDataFolders()
	
	String OldDf = GetDataFolder(1)
	SetDataFolder root:BIOFILM:Globals
		
		String SimFolder 	= "root:BIOFILM"
		String SimList 	= ReturnSimulationList(SimFolder,"Sim")
		
		String SimName = StrVarOrDefault("root:BIOFILM:Globals:gSimName","")
		String Sim2Name = StrVarOrDefault("root:BIOFILM:Globals:gSim2Name","") 
		String SimPlotChoice = StrVarOrDefault("root:BIOFILM:Globals:gSimPlotChoice","CVr_") 
		String SimPlotCmpt = StrVarOrDefault("root:BIOFILM:Globals:gSimPlotCmpt","cv_J") 
		
		Prompt SimPlotChoice, "Simulation plot", popup, "Ps_;CVf_;CVr_;"
		Prompt SimPlotCmpt, "Simulation component", popup, "cv_J;an_J;bf_J;ac_J;Ac_C; Ac_Eh;"
		
		Prompt SimName, "List of simulations", popup, SimList
		Prompt Sim2Name, "Second for multiple display", popup, "_none_;"+SimList
		DoPrompt "Select simulations to view", SimPlotChoice, SimPlotCmpt, SimName,Sim2Name
		if (V_flag)
			return ""
		endif
		
		String /G gSimPlotChoice 	= SimPlotChoice
		String /G gSimPlotCmpt 		= SimPlotCmpt
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


//		// "Respiration" - Acetate-to-Biofilm-MHC electron transfer
//		QQac 	= MHC_Ac_ET_step(gCVdt,AcRd,AcOx,gFixAcRd,gFixAcOx,MHC_QQb)
						
Function MHC_Ac_ET_step(dt,AcRd,AcOx,C_MHC,QQ)
	Variable dt,&AcRd,&AcOx,C_MHC
	Wave QQ
	
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo			// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
	NVAR 	lambda 			= root:BIOFILM:Globals:gAc_L			// Reorganization energy, in eV, for Acetate-to-MHC ET
	NVAR 	vK 					= root:BIOFILM:Globals:gAc_vK			// Prefactor for Marcus-Hush rate constant (nuclear collision and adiabaticity)
	NVAR gAc_dAc 			= root:BIOFILM:Globals:gAc_dAc		// Do not consume all the Acetate
	
	NVAR 	gFixAcRd 			= root:BIOFILM:Globals:gFixAcRd			// Forward electron transfer
	NVAR 	gFixAcOx 			= root:BIOFILM:Globals:gFixAcOx		// Reverse electron transfer
	Variable FixAcRd 		= (gFixAcRd == 2) ? 1 : 0
	Variable FixAcOx 		= (gFixAcOx == 2) ? 1 : 0
	
	NVAR 	gAcFwd 			= root:BIOFILM:Globals:gAcFwd		// Forward electron transfer
	NVAR 	gAcRev 			= root:BIOFILM:Globals:gAcRev			// Reverse electron transfer
	Variable FWDFlag 		= (gAcFwd == 2) ? 1 : 0
	Variable REVFlag 		= (gAcRev == 2) ? 1 : 0
	
	WAVE QQf 				= root:BIOFILM:Globals:MHC_QQf			// A temporary array
	WAVE QQr				= root:BIOFILM:Globals:MHC_QQr			// A temporary array

	Variable MHC_Eo 		= DimOffset(QQ,0)				// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable MHC_dE 		= DimDelta(QQ,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable Qmax 			= DimSize(QQ,0)					// The total number of electron occupation states (= 11)
	
	Variable Ac_Eh, MHC_Eh, MHC_EN, dQQ
	Variable i, j, DG, Ket, dAc, dACtot=0, ETtot=0
	
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
				dAc 		= AcRd * C_MHC*QQ[j] * (1 - exp(-1*dt*Ket))
				
				// Record but don't apply the change in redox state
				QQf[j]  	= 8*dAc/C_MHC
			
			endif
			dActot += dAc
		endif
		
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
				dAc 		= AcOx * C_MHC*QQ[j] * (1 - exp(-1*dt*Ket))
				
				// Record but don't apply the change in redox state
				QQr[j]  	= 8*dAc/C_MHC
			
			endif
			dActot -= dAc
		endif
		
	endfor

	if (!FixAcRd)// Option to run in constant-Acetate conditions
//		AcRd -= dActot
		AcRd -= dActot*gAc_dAc
	endif
	if (!FixAcOx)
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
	
	// The "concentration of electrons" in moles/cm2
	ETtot = 8*dActot
	return ETtot
	
	// Convert to Coulombs/cm2
//	return cFaraday * ETtot
End



// ***************************************************************************
// 			Electron transfer between two MHC populations
// ***************************************************************************

// 	Input: Two QQ's containing populations of identical MHCs
// 	Calculation: Calculate rate constants for all permutations of forward and reverse electron transfer
//	Output: The modified QQ's and the net 'forward' electron flux	
//	Options: Allow biofilm-biofilnm or biofilm-anode ET. 
//	Description: 

//				QQbf 	= -1 * MHC_ET_step(gPsEAdt,0,MHC_QQb,MHC_QQc)		// <--- Set AnodeFlag=0
//				QQcv 	= -1 * MHC_ET_step(gPsEAdt,1,MHC_QQa,MHC_QQb)		// <--- Set AnodeFlag=1

Function MHC_ET_step(dt,AnodeFlag,gCa,gCb,QQa,QQb)
	Variable dt,AnodeFlag, gCa, gCb
	Wave QQa, QQb
	
//	NVAR gCb 		= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
//	NVAR gCa 		= root:BIOFILM:Globals:gC_MHCa 		// Fixed concentration of Multi-Heme Cytochromes attached to the anode, in moles per cm2
	
	WAVE Kab 			= root:BIOFILM:Globals:MHC_Kba			// The Forward ET's
	WAVE Kba 			= root:BIOFILM:Globals:MHC_Kab			// The Reverse ET's
	
	Variable Eo 			= DimOffset(QQb,0)				// Standard electrochemical potential (at pH 7) for FIRST reduction of the MHC, in V vs. NHE
	Variable dE 			= DimDelta(QQb,0)				// Increment in MHC redox potential for a unit change in charge state, in V
	Variable QMax 		= DimSize(QQb,0)				// The total number of electron occupation states (= 11)
	
	
	NVAR gEaRev 		= root:BIOFILM:Globals:gEaRev  
	
	Variable FWDFlag=1, REVFlag=1
	Variable i, j, Ket, ETfwd, ETrev, ETtot=0
	Variable aR=0, aF=0, bR=0, bF=0, aNet, bNet, abNet
	
	// Increasing i means that QQa is more reducing as we go down the rows of Kab
	// Increasing j means that QQb is more reducing as we go across the columns of Kab
	
	// Testing 2019-06 Disable reverse ET when AnodeFlag is 1 (i.e., electrode cannot charge up the biofilm). 
	if (gEaRev==1)
		REVFlag = (AnodeFlag==1) ? 0 : 1
	endif
	
	// Loop over all the Qmax populations
	for (i=0;i<QMax;i+=1)								// i is the index over MHC a
		for (j=0; j<QMax;j+=1)							// j is the index over MHC b
			
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
					bF 				+= ETfwd/gCb
					
					if (!AnodeFlag)								// Update the populations of QQa (here, donor and not on the anode)
						QQa[i] 		-= ETfwd/gCa			// Electrons transfered from MHCa state i to (i-1)
						QQa[i-1] 		+= ETfwd/gCa	
						aR 				+= ETfwd/gCa
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
//					ETrev 		= gCa*QQa[i] * gCb*QQb[j] * dt*Ket
				
					 // Update the populations of QQb (here, donor)
					QQb[j] 		-= ETrev/gCb				// Electrons transfered from MHCb state j to (j-1)
					QQb[j-1] 		+= ETrev/gCb	
					bR 				+= ETrev/gCb
					
					if (!AnodeFlag)							// Update the populations of QQa (here, acceptor and not on the anode)
						QQa[i] 		-= ETrev/gCa			// Electrons transfered from MHCb state i to (i+1)
						QQa[i+1] 		+= ETrev/gCa	
						aF 				+= ETrev/gCa
					endif
					
					ETtot 			-= ETrev						// Keep track of electrons transferred in forward reaction
				endif
			endif
			
		endfor
	endfor
	
	aNet = aF-aR; bNet = bF-bR; abNet=aNet+bNet
	 
	// Returns the moles/cm2 of electrons transferred
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
	
	Variable nn, E1st, Enth, Eratio, Edif, Popn
	Variable i, j, QQ=0, temp, NPts=Dimsize(MHC_QQ,0)
	
	// The difference between the Anode potential and the first redox potential
	Edif 		= Ea - Eo + 0.5*dE
	Eratio 		= Edif/dE
	
	// The index of the operational redox potential	
//	nn 		= min(max(0,trunc(Edif/dE)),QMax-2) // nn varies between 0 - 9 
	nn 		= min(max(0,trunc(Edif/dE-1)),QMax-2) // nn varies between 0 - 9 		// 2019-06-08 ?!?!?!?!?!?!? A mix up between calculation energies and indexing the matrices
	
	//  The value of the operational redox potential	
//	E1st 	= Eo + (nn)*dE
	E1st 	= Eo + (nn+1)*dE																// 2019-06-08 ?!?!?!?!?!?!?
	
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
	// When exp(0) = 1, the populations are equal. 
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
	
//	print "A = ",A," and B=",B
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


// ***************************************************************************
// 			Tests of Acetate-MHC electron transfer
// ***************************************************************************


Function xxMHC_Ac_Equilibrate()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQb 		= root:BIOFILM:Globals:MHC_QQb
	NVAR gCb 				= root:BIOFILM:Globals:gC_MHCb 		// Fixed concentration of NON-RESPIRING Multi-Heme Cytochromes in the biofilm layer, in moles per cm2
	NVAR gAc_Eo 			= root:BIOFILM:Globals:gAc_Eo				// Standard electrochemical potential (at pH 7) for acetate respiration, in V vs. NHE
	
	// Acetate parameters
	Variable AcRd = 1e-3
	Variable AcOx = AcRd/10
	Variable ConstAcRd = 0
	Variable ConstAcOx = 0

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
//		MHC_Ac_ET_step(dt,AcRd,AcOx,ConstAcRd,ConstAcOx,MHC_QQb)
		MHC_Ac_ET_step(dt,AcRd,AcOx,gCb,MHC_QQb)
		
		i+=1
		gIndex1+=1
	while(i < nSteps)
	print " 	*** ",nSteps," iterations took",StopMSTimer(MSref2)/1000,"s"
End





// ***************************************************************************
// 			Tests of MHC-MHC cyclic voltammetry
// ***************************************************************************

Function xxMHC_CV()
	
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
//			QQcv -= MHC_ET_step(EAdt,1,MHC_QQa,MHC_QQb)
			QQcv -= MHC_ET_step(EAdt,1,gCa,gCb,MHC_QQa,MHC_QQb)
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

Function xxMHC_Equilibrate()
	
	Initialize_MHC_kinetics()
	
	WAVE MHC_QQa 			= root:BIOFILM:Globals:MHC_QQa			
	WAVE MHC_QQb 			= root:BIOFILM:Globals:MHC_QQb
	
	NVAR gCa 		= root:BIOFILM:Globals:gC_MHCa 
	NVAR gCb 		= root:BIOFILM:Globals:gC_MHCb 
	
	Variable QQa 	= MHC_SetChargeStates(-0.13,MHC_QQa)
	Variable QQb = MHC_SetChargeStates(-0.16,MHC_QQb)
	
	Variable i=0, j=0, nSteps = 10000, dt=100, rStep=100
	
	Make /O/N=(nSteps) MHC_et=0
	Make /O/N=(nSteps/rStep) MHCa_Q=0, MHCb_Q=0
	
	Variable /G gIndex=0
	
	Variable ref1=StartMSTimer
	do
	
//		MHC_et[i] = MHC_ET_step(dt,0,MHC_QQa,MHC_QQb)
		MHC_et[i] = MHC_ET_step(dt,0,gCa,gCb,MHC_QQa,MHC_QQb)
		
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


Function Lxxoop_Test()
	
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
	
		MHC_et[i] = xxFunct_Test(dt,1,MHC_QQa,MHC_QQb)
		
		i+=1
		gIndex += 1
	while(i < nSteps)
	
	print i
End

Function xxFunct_Test(dt,AnodeFlag,QQa,QQb)
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