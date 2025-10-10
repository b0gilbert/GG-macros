#pragma rtGlobals=1		// Use modern global access method.

// The fractionation factor between atmospheric CO2 and calcite
Function C13Fractionation(C13CO2, TC)
	Variable C13CO2, TC

	Variable TK = 278.15 + TC
	Variable b =	5.634
	Variable c =	-9.02
	Variable F = b*1e3/TK + c
	
	Variable C13Calcite = C13CO2 + F
	
	return C13Calcite
End

Function SphericalDiffusion5(D1025,tYr,Anm,nMax)
	Variable D1025, tYr, Anm, nMax
	
	Variable n, NPts = 101
	
	Variable t = tYr * 365*24*360		// time in second
	Variable D = D1025 * 1e-25			// diffusion coefficient in m2/s
	Variable nm2m 	= 1e-9
	Variable a = Anm * nm2m			// radius in m
	
	Variable Dta2 	= D*t/a^2
	Variable Lmb 	= (pi/a)
	Variable Alp 		= D
	
	Variable Uo 	= 0		// Initial constant concentration throughout the particle
	Variable Ua 	= 0.1		// Constant concentration on the boundary at a
	
	Print " *** Dimensionless Dt/a2=",Dta2,"and number of seconds=",t," and summing to n-max=",nMax
	
	Variable rStep = a/(NPts-1)
	Make /O/D/N=(NPts) B13=0, B13p=0, B13n=0
	SetScale /P x, 0, (rStep), "",B13, B13p, B13n
	
	for (n=1;n<=nMax;n+=1)
		
		B13[] +=  (( (-1)^(n+1) )/n)   *    (1/pnt2x(B13,p))   *    exp(-n^2 * Lmb^2 * Alp * t)   *    sin(n * Lmb * pnt2x(B13,p))
	
	endfor
	
	B13 *= (2/pi)*a*(Uo-Ua)
	
	B13 += Ua
End

Function SphereCenterConc(D1025,tYr,Anm,nMax)
	Variable D1025, tYr, Anm, nMax
	
	Variable n, m, NPts = 1001
	
	Variable t = tYr * 365*24*360
	Variable D = D1025 * 1e-25
	Variable nm2m 	= 1e-9
	Variable a = Anm * nm2m
	Variable Dta2 	= D*t/a^2
	
	Print " *** Dimensionless Dt/a2=",Dta2,"and number of seconds=",t," and summing to n-max=",nMax
	
	Variable tStep = 1000000/(NPts-1)
	Make /O/D/N=(NPts) T13=0, T13p=0, T13n=0
	SetScale /P x, 0, (tStep), "",T13, T13p, T13n
	
	for (m=0;m<=NPts;m+=1)
		Dta2 	= D*t/a^2
		for (n=1;n<=nMax;n+=1)
			T13[m] 	+= -1^n  *  exp( -(n*pi)^2*Dta2 )
		endfor
	endfor
	T13 *= 2
	
End

Function SphericalDiffusion4(D1025,tYr,Anm,nMax)
	Variable D1025, tYr, Anm, nMax
	
	Variable n, NPts = 101
	
	Variable t = tYr * 365*24*360
	Variable D = D1025 * 1e-25
	Variable nm2m 	= 1e-9
	Variable a = Anm * nm2m
	Variable Dta2 	= D*t/a^2
	
	Print " *** Dimensionless Dt/a2=",Dta2,"and number of seconds=",t," and summing to n-max=",nMax
	
	Variable rStep = a/(NPts-1)
	Make /O/D/N=(NPts) B13=0, B13p=0, B13n=0
	SetScale /P x, 0, (rStep), "",B13, B13p, B13n
	
	for (n=1;n<=nMax;n+=2)
		
		B13p[] 	+= ((-1)^(n+1))/(n+0)  *  exp( -(n*pi)^2*Dta2 )  *    ( a/pnt2x(B13,p) )  *  sin( n*pi*(pnt2x(B13,p)/a) )
		B13n[] 	+= ((-1)^(n+2))/(n+1)  *  exp( -(n*pi)^2*Dta2 )  *    ( a/pnt2x(B13,p) )  *  sin( n*pi*(pnt2x(B13,p)/a) )
	
	endfor
	
	B13 = B13p + B13n
End

Function ExpTest(j)
	Variable j
	
	Variable n
	Variable Bp=0, Bn=0
	Variable Dta2 = 1
	
	for (n=1;n<=j;n+=2)
		
		Bn += ((-1)^(n+1))/(n+0)  *  exp( -(n*pi)^2*Dta2 )  *    ( 0.5 )
		Bp += ((-1)^(n+2))/(n+1)  *  exp( -(n*pi)^2*Dta2 )  *    ( 0.5 )
	
	endfor
	
	print Bn, Bp, Bn-Bp
End

Function SphericalDiffusion3(D1025,tYr,Anm,jj)
	Variable D1025, tYr, Anm, jj
	
	Variable n, scale
	
	Variable t = tYr * 365*24*360
	Variable D = D1025 * 1e-25
	Variable nm2m 	= 1e-9
	Variable a = Anm * nm2m
	Variable rStep = a/(101-1)
	
	Variable Dta2 	= D*t/a^2
	
	Make /O/D/N=101 B13=0
	SetScale /P x, 0, (rStep), "",B13
	
	
	for (n=1;n<=jj;n+=1)
		
		
		B13[] +=     (-1^(n+1))/n  //*  exp( -(n*pi)^2*Dta2 )
		
//		B13[] +=     (-1^(n+1))/n    *    ( a/pnt2x(B13,p) )   *   exp( -(n*pi)^2*Dta2 )  *     sin( n*pi*pnt2x(B13,p)/a )     
	
	endfor
	
	B13[] *= 2
	
//	B13[] = 1 - B13[p]
	
End

Function SphericalDiffusion2(D1025,tYr,Anm,jj)
	Variable D1025, tYr, Anm, jj
	
	Variable n, scale
	
	Variable t = tYr * 365*24*360
	Variable D = D1025 * 1e-25
	Variable nm2m 	= 1e-9
	Variable a = Anm * nm2m
	
	Variable Dta2 	= D*t/a^2
	
	Make /O/D/N=101 B13=0
	SetScale /P x, 0, 0.01, "",B13
	
	
	for (n=1;n<jj;n+=1)
	
		B13[] +=     -1^n/n    *    sin( n*pi*pnt2x(B13,p) )     *    exp( -n^2*pi^2*Dta2 )  
	
	endfor
	
	B13[] *= -2/(pi*pnt2x(B13,p))
	
End

cosh


// D in 10-25 m2 s-1
// Time, t, in years
//  jj the maximum index
Function SphericalDiffusion(D1025,tYr,jj)
	Variable D1025,tYr, jj
	
	// Convert t to seconds
	Variable t = tYr * 365*24*360
	Variable D = D1025 * 1e-25
	Variable nm2m 	= 1e-9
	
	NVAR gUnitA 				= root:KINETICS:gUnitA
	
	// Set the axis in nm
	Variable UnitA = 1e9*gUnitA
	
	Make /O/D/N=201 C13
	SetScale /P x, 0, UnitA, "nm",C13
	
	Variable n, a = 201 * gUnitA
	
	Variable Dta2 	= D*t/a^2
	print Dta2
	
	C13 = 1
	
	for (n=1;n<jj;n+=1)
	
		C13[] +=     (2/pi)*( a/(nm2m*pnt2x(C13,p)) )   *   (    ( (-1^n)/n )    *    sin( (n*pi)   *  ( (nm2m*pnt2x(C13,p))/a )  )     *    exp( -n^2*pi^2*Dta2 )      )
		
	endfor
	
	
	
End

Function CalculateRXtl()
	
	Variable YearToSecs = 60*60*24*365
	Variable DayToSecs = 60*60*24
	
	Variable DDays = (CsrXWaveRef(B)[pcsr(B)] - CsrXWaveRef(A)[pcsr(A)])
	Variable DMoles = (CsrWaveRef(B)[pcsr(B)] - CsrWaveRef(A)[pcsr(A)])
	
//	print DMoles, DDays
	
	Variable RXtl1 = DMoles/DDays
	Variable RXtl2 = RXtl1/DayToSecs
	Variable RXtl3 = RXtl1*365
	
	print "	*** Average recrystallization rate is",RXtl1," moles / m2 / day, or", RXtl2," moles / m2 / s, or",RXtl3," moles / m2 / year"
End

Function delta13CFrom13Cratio(C13)
	Variable C13

	// The 13C/12C ratio in the standard, Rvpdb
	Variable /G gd13CRvpdb 		= 0.0112372
	
	Variable delta13C = ((C13/gd13CRvpdb) - 1)*1000
	
	return delta13C
End

Function C13ratioFromdelta13C(delta13C)
	Variable delta13C

	// The 13C/12C ratio in the standard, Rvpdb
	Variable /G gd13CRvpdb 		= 0.0112372
	
	Variable C13 = gd13CRvpdb * (1 + delta13C/1000)
	
	return C13
End

Function C13contentFromdelta13C(delta13C)
	Variable delta13C

	// The 13C/12C ratio in the standard, Rvpdb
	Variable /G gd13CRvpdb 		= 0.0112372
	
	// The 13C/12C ratio
	Variable C13 = gd13CRvpdb * (1 + delta13C/1000)
	
	// The 13C/totC fraction
	Variable C13frac = C13/(C13+1)
	
	// The formula weight of calcite
	Variable FW 				= 100.087  		// g/mol
	Variable uMolPerG 		= 1e6/FW			// umoles/g
	
	Variable C13conc		= C13frac * uMolPerG
	
	return C13conc
	
End

Function PlotRipening()

	String RcdStr="", OldDf = GetDataFolder(1)
	SetDataFolder root:KINETICS:

	Variable SimNum = NumVarOrDefault("root:KINETICS:gSimNum",1)
	Prompt SimNum, "Simulation number"
	DoPrompt "Enter simulation number to plot", SimNum
	if (V_flag)
		return 0
	endif
	Variable /G	gSimNum = SimNum
	
	String SimFolder = "root:Kinetics:Sim"+FrontPadVariable(SimNum,"0",3)+":"
	String RipeFolder = "root:Kinetics:Sim"+FrontPadVariable(SimNum,"0",3)+":Ripening:"
	
	SetDataFolder $RipeFolder
	
	String MassWaves = WaveList("CalciteMass_*",";","")
	String LengthWaves = WaveList("CalciteLen_*",";","")
	Variable i, NWaves = ItemsInList(MassWaves)
	
	Wave Mass0 = $StringFromList(0, MassWaves)
	Wave Length0 = $StringFromList(0, LengthWaves)
	
	// Display the output of the calculation - the total mass evolution of each of the histogram bins
	Display Mass0 vs Length0
	
	for (i=1;i<Nwaves;i+=1)

		Wave Mass = $StringFromList(i, MassWaves)
		Wave Length = $StringFromList(i, LengthWaves)
		
		AppendToGraph Mass vs Length
	endfor
	
	// Display an interpolation of the mass distribution back to the original length axis
	// We do need to re-normalize at this step to conserve mass
	Variable TotalMass 	= sum(Mass)
	
	Display Mass0 vs Length0
	
	for (i=1;i<Nwaves;i+=1)

		Wave Mass = $StringFromList(i, MassWaves)
		Wave Length = $StringFromList(i, LengthWaves)
		
//		Interpolate2 /T=1/I=3/X=Length0/Y=Mass_Interp Length, Mass
		Interpolate2 /T=1/I=3/X=Length0/Y=$("i_"+NameofWave(Mass)) Length, Mass
		
		Wave Mass_Interp = $("i_"+NameofWave(Mass))
		
		Variable TotalMass_Interp 	= sum(Mass_Interp)
		Mass_Interp *= (TotalMass/TotalMass_Interp)
		
		AppendToGraph Mass_Interp vs Length0
	endfor
		
	// Display the true recrystallization rate
//	WAVE TrackReXtl = TrackReXtl
//	WAVE Track_Days = Track_Days
//	WAVE TrackSA = TrackSA
	
	SetDataFolder $SimFolder
	Display /W=(398,47,975,514) TrackReXtl vs Track_Days
	AppendToGraph/R TrackSA vs Track_Days
	ModifyGraph mirror(bottom)=2
	Label left "\\Z18Recrystallized calcite (moles/m\\S2\\M\\Z18)"
	Label bottom "\\Z24Time (days)"
	Label right "\\Z18Surface area (m\\S2\\M\\Z18/g)"
	
//	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
//	TotalMass_Interp 	= sum(XtalMass_Interp)
//	XtalNum_Interp *= (TotalMass/TotalMass_Interp)
//	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
//	TotalMass_Interp 	= sum(XtalMass_Interp)
	
	SetDataFolder $OldDf
End

Function ConvertNPtoMass()

	WAVE Length = CalciteLen_0
	if (!WaveExists(Length))
		return 0
	endif
	
	String MassWaves = WaveList("CalciteMass_*",";","")
	Variable i, NWaves = ItemsInList(MassWaves)
	
//	print NWaves
	
	for (i=0;i<Nwaves;i+=1)

		Wave NP = $StringFromList(i, MassWaves)
		
		NP[] *= Length[p]^3
	endfor
End



// 	http://www.aqion.de/site/168
// 	Atomic weight of Ca = 40.078

// MatrixOp /O CProfile = row(CalciteArray,gMeanLIndex)^t

// ***************************************************************************
// **************** 			Globals for Ostwald Ripening and Surface Exchange Routines
// ***************************************************************************

// 	Consider a mass of calcite particles (kg) one cubic meter of solution. 
// 			So, 1 kg in 1 m3 is equivalent to 1 g in 1 L

// Unit Conversions: 
Constant cLiterstoM3 	= 0.001			// 1m3 = 1000 L
Constant mMtomolM3 	= 1000			//
Constant MinToDays		= 1440			// 1440 minutes = 1 day; 43,200 mins = 1 month; 144,000 mins = 100 days

// Calculate the size dependence of the calcite solubility product
Function ParticleKsp(XtalKsp,XtalLen)
	Wave XtalKsp,XtalLen

	NVAR gTemperature = root:KINETICS:gTemperature
	NVAR gIFE 			= root:KINETICS:gIFE
	NVAR gKsp 			= root:KINETICS:gKsp
	NVAR gMolVol 		= root:KINETICS:gMolarVolume
	NVAR gUnitA 			= root:KINETICS:gUnitA
	
	// A factor of 2 in alpha for the size-dep trend in Ksp vs solubility
//	Variable alpha 		= (4*IFE*MolarVol)/(T*cR)
	Variable alpha 		= (8*gIFE*gMolVol)/(gTemperature*cR)
	
	XtalKsp[] 	= gKsp * exp(alpha/max(gUnitA,XtalLen[p]))
End

Function InitializeKinetics()

	String OldDF = getDataFolder(1)
	NewDataFolder /O/S root:KINETICS
	
		// Physical properties of calcite
		Variable /G gMolarVolume 	= 3.12e-05		// m3 / mol 		converted from 31.20 cm3 per mole
		Variable /G gFW 			= 0.100087 		// kg/mol			converted from 100.087  g/mol
		Variable /G gDensity 		= 2710				// kg/m3			should be equal to ... (gFW/1000)/gMolarVolume ? 
		Variable /G gIFE 			= 0.094			// J/m2			value from Steefel paper sent by A. Stack
//		Variable /G gIFE 			= 0.188			// J/m2			trial

		// Geometry of the particles
		Variable /G gUnitA 				= 0.45e-9
		
		// 2017-08-05 
//		Variable /G gNLayers 			= 3000
//		Variable /G gNLayers 			= 2000
//		Variable /G gNLayers 			= 5555
		
		// Solubility of bulk calcite Ksp = {Ca2+}{CO32-}
//		Variable /G gKsp 			= 10^(-8.6223)	// at 21 C	<-- a good bulk estimate from Antoine, but I did not use this for some reason ... 
//		Variable /G gKsp 			= 10^(-8.3223)	// at 21 C	<-- ... instead I manually tweaked to this value to acheive [Ca] = 
		
		// 2017-08-03 Allow Ksp to be a user variable to check for effect of changing temperature 
		Variable LogKsp = NumVarOrDefault("root:KINETICS:gLogKsp",1)
		Prompt LogKsp, "At 21ûC -log{Ksp} = 8.3223 (GWB)"
		Variable NLayers = NumVarOrDefault("root:KINETICS:gNLayers",3000)
		Prompt NLayers, "Highest number of layers"
		Variable ManualOmega = NumVarOrDefault("root:KINETICS:gManualOmega",-1)
		Prompt ManualOmega, "A positive value will be fixed"
		DoPrompt "Enter -log{calcite solubility product}", LogKsp, NLayers, ManualOmega
		if (V_flag)
			return 0
		endif
		Variable /G	gLogKsp = LogKsp
		Variable /G	gKsp = 10^(-1*LogKsp)
		Variable /G gNLayers 			= NLayers
		Variable /G gManualOmega 	= ManualOmega
		
		// Solution chemistry, in moles/m3 = mM/L
//		Variable /G gCaAq 			= 0.492			// Andrew calculation
		Variable /G gCaAq 			= 0.513			// Antoine and phreeqc @ 21C
		Variable /G gCO32Aq		= 9.58e-3			//	"			"
		
		// At equilibrium {CaCO3} = sqrt(Ksp} = 48.8 x 10-6 moles per liter
//		Variable /G gCaCO3aq 		= 0.0488			// moles/m3		converted from 0.0000488	moles/L

		//  Follow Stack and separate the dissolved Ca and CO3
		
		// The proportion of 13C in atmospheric CO2
		Variable /G g13CAtm 		= 0.0102				// Not used
		
		// The proportion of 13C in aqueous CO2 for an atmospheric d13C of -8 per mill at 21C (??? Is this accurate? I think that 0.0112488 might be Antoine's prediction). 
//		Variable /G g13CAq 			= 1/(89.7949-1)  // = 0.0112618
		// The proportion of 13C in aqueous CO2 for an atmospheric d13C of -20 per mill at 50C
		Variable /G g13CAq 			= 0.0110945

		
//		g13CAq 	= 89.7949
//		g13CAq 	= 50
//		print "		**  !*!*!*!	 this has a high value of g13CAq=",g13CAq,"for a Subhas simulation !*!*!"
			
		// The 13C/12C ratio in the standard, Rvpdb
		Variable /G gd13CRvpdb 		= 0.0112372
		
		// 	Andrew's  rate constant for ion release or addition from a calcite surface
		// 	R_surface = 0.068 µmol/m2/s = 4.08 µmol/m2/min = 0.2448 mmol/m2/hour = 5.88 mmol/m2/day
//		Variable /G gkDiss 			= 0.00000408				// moles/m2/MINUTE - Stack 
//		Variable /G gkDiss 			= 0.00000000251			// moles/m2/MINUTE - Stack
		
		NVAR gkDiss 	= root:KINETICS:gkDiss
		NVAR gkExch 	= root:KINETICS:gkExch
		NVAR gkDiff 	= root:KINETICS:gkDiff
		NVAR gEquateExDiss 	= root:KINETICS:gEquateExDiss
		if (!NVar_Exists(gkDiss))
			Variable /G gkDiss 			= 0.00000001			// moles/m2/MINUTE - adjusted
			Variable /G gkExch 			= 0.00000001			// moles/m2/MINUTE - adjusted
			Variable /G gkDiff 			= 5e-23			 	// m-2/MINUTE - adjusted
			Variable /G gEquateExDiss 	= 2
		endif
		
//		Variable /G gkDiff 			= 4e-22			// m-2/MINUTE - manual 'fit' to 262 nm particle and 50C
//		Variable /G gkDiff 			= 6e-22			// m-2/MINUTE - manual 'fit' to 523 nm particle and 25C
//		Variable /G gkDiff 			= 1.75e-21		// m-2/MINUTE - manual 'fit' to 523 nm particle and 50C
		
//		gkExch 			= 3.765e-09
		
//		KillAllWavesInFolder("root:KINETICS:Ripening","XtlPDFMass")
//		KillAllWavesInFolder("root:KINETICS:Ripening","XtlPDFMass")

		Variable kDiss = gkDiss
		Prompt kDiss, "Diss/Ppt rate in moles/m2/min"
		Variable kExch = gkExch
		Prompt kExch, "Exchange rate in moles/m2/min"
		Variable EqExDiss = gEquateExDiss
		Prompt EqExDiss, "Set kEx to kDiss?", popup, "yes;no;"
		Variable kDiff = gkDiff
		
		Prompt kDiff, "Diffusion coefficient in m2/min"
		
		DoPrompt "Optionally adjust rate parameters", kDiss, kExch, EqExDiss, kDiff
		if (V_flag)
			return 0
		endif
		
		gkDiss 	= kDiss
		gkExch 	= kExch
		gEquateExDiss = EqExDiss
		gkDiff 	= kDiff
		
		if (gEquateExDiss == 1)
			print " 	*** Setting the Exchange rate to the Dissolution/Precipitation rate!" 
			gkExch = gkDiss
		else
		endif
		
	SetDataFolder $OldDF
End

// ***************************************************************************
// **************** 			Ostwald Ripening + Surface Exchange
// ***************************************************************************
Function ORandEx()

	if (InitializeKinetics() == 0)
		return 0
	endif
	
	NVAR gCaAq 		= root:KINETICS:gCaAq
	NVAR gNLayers 	= root:KINETICS:gNLayers
	
	// By default, each simulations OVERWRITE existing ones
	String SimulationDir = "root:KINETICS:Sim"+FrontPadVariable(1,"0",3)
	String SimNote="", SimParam, CalculationName
	Variable n, i, TotalMass, dummy, Success, NewParticles=1
	
	String OldDF = getDataFolder(1)
	NewDataFolder /O/S root:KINETICS
	
		String CalcTypeList = "Particle distribution;Ostwald ripening;Surface exchange;Exchange & Diffusion;Ripening & Exchange;Ripening & Exchange & Diffusion;"
	
		// Parameters for a single simulation
		Variable NTPts = NumVarOrDefault("root:KINETICS:gNTPts",1000)
		Prompt NTPts, "# points for time axis"
		Variable TStep = NumVarOrDefault("root:KINETICS:gTStep",1000)
		Prompt TStep, "Time step (minutes)"
		Variable Temperature = NumVarOrDefault("root:KINETICS:gTemperature",295)
		Prompt Temperature, "Temperature (K)"
		Variable CaAqInit = NumVarOrDefault("root:KINETICS:gCaAqInit",gCaAq)	// Expt measurement was  42mg/L = 1.048 mM  ????
		Prompt CaAqInit, "Initial calcium concentration (mM)"
		Variable MixTime = NumVarOrDefault("root:KINETICS:gMixTime",1000)
		Prompt MixTime, "Time step to start mixing"
		Variable CalcType = NumVarOrDefault("root:KINETICS:gCalcType",1)
		Prompt CalcType, "Calculation type", popup, CalcTypeList
		Variable CalcMulti = NumVarOrDefault("root:KINETICS:gCalcMulti",1)
		Prompt CalcMulti, "Number of simulations (integer)"
		Variable CalcTrack = NumVarOrDefault("root:KINETICS:gCalcTrack",2)
		Prompt CalcTrack, "Track single particle or full distribution?", popup, "Single;Full;Both;"
		
		DoPrompt "Single Isotope Exchange simulation", TStep, NTPts, Temperature, CaAqInit, MixTime, CalcType, CalcMulti, CalcTrack
		if (V_flag)
			return 0
		endif
		
		if ((CalcTrack==1) && ((CalcType==2) || (CalcType>5)))
			Print " 			--- Ostwald ripening simulations can only be performed on a complete particle distribution."
			CalcTrack = 2
		endif
		
		Variable /G gTStep 			= TStep
		Variable /G gNTPts 			= NTPts
		Variable /G gTemperature 	= Temperature
		Variable /G gCaAqInit 		= CaAqInit			// 1 mM is equivalent to 1 mole/m3
		Variable /G gMixTime 		= MixTime
		Variable /G gCalcType 		= CalcType
		Variable /G gCalcMulti 		= CalcMulti
		Variable /G gCalcTrack 		= CalcTrack
		
		// Create the initial distribution of calcite particles. 
		TotalMass 	= NewCalciteParticles(NewParticles,NTPts,gNLayers,CaAqInit)
		if (TotalMass == 0)
			return 0
		elseif (CalcType == 1)
			return 1
		endif
		
		// Reset the results of prior simulation(s)
//		for (n=1;n<=CalcMulti;n+=1)		
		for (n=1;n<=30;n+=1)		
			SimulationDir = "root:KINETICS:Sim"+FrontPadVariable(n,"0",3)
			WAVE Track13C = $(SimulationDir+":Track13C")
			if (WaveExists(Track13C))
				Track13C = 0
				KillWaves /Z $(SimulationDir+":Track13Cn")
				KillDataFolder /Z $(SimulationDir+":Diffusion:")
				KillDataFolder /Z $(SimulationDir+":Ripening:")
			endif
		endfor
		
		if (CalcMulti > 1)
		
			// Parameters for a suite of simulations
			String CalcParam = StrVarOrDefault("root:KINETICS:gCalcParam","Kexch")
			Prompt CalcParam, "Parameter to vary", popup, "No! - Kexch;kDiss;kDiff;"
			Variable CalcVary = NumVarOrDefault("root:KINETICS:gCalcVary",1)
			Prompt CalcVary, "Variation method", popup, "Addition;Scaling;"
			Variable CalcStart = NumVarOrDefault("root:KINETICS:gCalcStart",1e-8)
			Prompt CalcStart, "Starting value of chosen parameter (/minute)"
			Variable CalcFactor = NumVarOrDefault("root:KINETICS:gCalcFactor",1e-8)
			Prompt CalcFactor, "Difference or scaling factor"

			DoPrompt "Multiple Isotope Exchange simulations", CalcParam, CalcVary, CalcStart, CalcFactor
			if (V_flag)
				return 0
			endif
			
			String /G gCalcParam 		= CalcParam
			Variable /G gCalcVary 		= CalcVary
			Variable /G gCalcStart 		= CalcStart
			Variable /G gCalcFactor 		= CalcFactor
			
			NVAR gParam 	= $("root:KINETICS:g"+gCalcParam)
			
			CalculationName 	= StringFromList(CalcType-1,CalcTypeList)
			Print " 	*** Simulation of",CalculationName,"while varying",gCalcParam
				
			for (n=1;n<=CalcMulti;n+=1)
				
				SimulationDir = "root:KINETICS:Sim"+FrontPadVariable(n,"0",3)
				
				if (CalcVary == 1)
					gParam 	= (CalcFactor * (n-1)) + CalcStart
				else
					gParam 	= CalcFactor^(n-1) * CalcStart
				endif
				
				SimParam 	= CalcParam+"="+num2str(gParam)
				SimNote 	= SimulationNote("One simulation <#030> in a series of isotope exchange in calcite",CalcType)
				
				if (n>1)
					dummy 		= NewCalciteParticles(NewParticles,NTPts,gNLayers,CaAqInit)
				endif
				
				Success 	= CalciteIsotopeExchange(TStep,NTPts,MixTime,CalcType,CaAqInit,gNLayers,TotalMass,SimulationDir,SimNote)
				if (!Success)
					break
				endif
				
				NewParticles = 0
			endfor
			
		else
			
			SimNote 	= SimulationNote("A single simulation of isotope exchange in calcite",CalcType)
			CalciteIsotopeExchange(TStep,NTPts,MixTime,CalcType,CaAqInit,gNLayers,TotalMass,SimulationDir,SimNote)
		endif
End

Function /T SimulationNote(SimText,CalcType)
	String SimText
	Variable CalcType
	
	NVAR gkDiss 	= root:KINETICS:gkDiss
	NVAR gkExch 	= root:KINETICS:gkExch
	NVAR gkDiff 	= root:KINETICS:gkDiff
	NVAR gEquateExDiss = root:KINETICS:gEquateExDiss
	
	if (gEquateExDiss == 1)
		print " 	*** Setting the Exchange rate to the Dissolution/Precipitation rate!" 
		gkExch = gkDiss
	endif
	
	Variable ORFlag,SEFlag,DiffFlag
	MechanismFlags(CalcType,ORFlag,SEFlag,DiffFlag)
	
	String SimNote = SimText
	if (ORFlag)
		SimNote 		= SimNote + "\rNet DISSOLUTION/PRECIPITATION rate constant = "+num2str(gkDiss)+" mol/m2/min, or "+num2str(gkDiss/60)+" mol/m2/s"
	endif
	if (SEFlag)
		SimNote 		= SimNote + "\rSURFACE EXCHANGE rate constant = "+num2str(gkExch)+" mol/m2/min, or "+num2str(gkExch/60)+" mol/m2/s"
	endif
	if (DiffFlag)
		SimNote 		= SimNote + "\rCARBONATE DIFFUSION coefficient = "+num2str(gkDiff)+" m2/min, or "+num2str(gkDiff/60)+" m2/s"
	endif
	
	return SimNote
End

// A Single Simulation of 13C isotope exchange in a distribution of carbonate particles.  
Function CalciteIsotopeExchange(TStep,NTPts,MixTime,CalcType,CaAqInit,NLayers,TotalMass,RipeningDir,SimNote)
	Variable TStep,NTPts,MixTime,CalcType,CaAqInit,NLayers,&TotalMass
	String RipeningDir,SimNote

	Variable Success=1, MixFlag
	Variable ORFlag,SEFlag,DiffFlag
	
	// Create Property-vs-Time arrays
	CalciteTrackingWaves(TStep,NTPts,TotalMass,CaAqInit,RipeningDir,SimNote)
	
	// Determine which processes are operational
	MechanismFlags(CalcType,ORFlag,SEFlag,DiffFlag)
	
	// Prepare diffusion matrices if needed
	if (DiffFlag)
		Variable NLs=1000 					// <--- 	THIS IS A FIXED SIZE FOR DIFFUSION CALCULATION
		
		NVAR gMeanLIndex 		= root:KINETICS:gMeanLIndex
		MakeSSDiffusionMatrices(TStep,gMeanLIndex)
	endif
	
	Variable i, duration,timeRef = startMSTimer
	
//	Variable RecordMod 	= trunc(NTPts/50)
	Variable RecordMod 	= 1	// To output everything. 
	Variable SaveMod 		= 100
	
	try 
		Progress_Kinetics(NTPts)
		
		for (i=0;i<NTPts;i+=1)
				
			if (mod(i,10)==0)
				ValDisplay valdisp0,value= _NUM:i+10,win=myProgress
				DoUpdate /W=myProgress /E=1
			endif
			
			// Indicates whether atmosphere is introduced
			MixFlag = (i >= MixTime) ? 1 : 0
			
			if (MixFlag && SEFlag)
				ExchangeStep(i,RipeningDir)
			endif
			
			if (MixFlag && DiffFlag)
				SSDiffusionStep(i,RipeningDir)
				if (mod(i,RecordMod)==0)
					DiffusionRecord(i,RipeningDir)
				endif
			endif
			
			if (ORFlag)
				TotalMass 	= RipeningStep2(i,MixFlag,RipeningDir)
				
				if (mod(i,RecordMod)==0)
				
					// Copies of some evolving particle distributions
					RipeningRecord(i,NLayers,RipeningDir)
				endif
			endif
			
			//Back up the experiment
			if (mod(i,SaveMod)==0)
				SaveExperiment
			endif
			
			// Single function to record trends in parameters
			CalciteTracking(i,TotalMass,RipeningDir)
			
		endfor
		duration 	= stopMSTimer(timeRef)
		Print " 		*** Calcite isotope exchange routine finished at step",i,"and",duration/60000000,"mins."
		
	catch
		duration 	= stopMSTimer(timeRef)
		Print " 	*** Calcite isotope exchange routine aborted by user at step",i,"and",duration/60000000,"mins."
		Success = 0
	endtry
	
	StopAllTimers()
	DoWindow myProgress
	do	// Get rid of any progress windows
		KillWindow myProgress
		DoWindow myProgress
	while (V_flag)
	
	return Success
End

Function MechanismFlags(CalcType,ORFlag,SEFlag,DiffFlag)
	Variable CalcType,&ORFlag,&SEFlag,&DiffFlag
	
	switch (CalcType)
		case 1: 	// New particles
			ORFlag 	= 0
			SEFlag 	= 0
			DiffFlag = 0
			break
		case 2: 	// Ostwald ripening only
			ORFlag 	= 1
			SEFlag 	= 0
			DiffFlag = 0
			break
		case 3: 	// Surface exchange only
			ORFlag 	= 0
			SEFlag 	= 1
			DiffFlag = 0
			break
		case 4: 	// Exchange & Diffusion
			ORFlag 	= 0
			SEFlag 	= 1
			DiffFlag = 1
			break
		case 5: 	// Ostwald & Exchange
			ORFlag 	= 1
			SEFlag 	= 1
			DiffFlag = 0
			break
		case 6: 	// All processes
			ORFlag 	= 1
			SEFlag 	= 1
			DiffFlag = 1
			break
	endswitch
End

Function CalciteTracking(i,TotalMass,RipeningDir)
	Variable i, TotalMass
	String RipeningDir

	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	Wave Calcite13C			= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
	Wave CalciteArea		= root:KINETICS:CalciteArea			// Surface area of each particle of N Layers
	Wave CalciteMass		= root:KINETICS:CalciteMass			// Mass of each particle of N Layers
	Wave LayerV				= root:KINETICS:LayerV				// Volume of each layer
	
	NVAR gCalcTrack 		= root:KINETICS:gCalcTrack			// Are we simulating and tracking a single particle or a full distribution? 
	NVAR gMeanLIndex		= root:KINETICS:gMeanLIndex			// Index of particles with (initial) mean size 
	
	// Waves tracking the change in solution and particle composition
	Wave Track13C			= $(RipeningDir+":Track13C")
	Wave Track13Cn			= $(RipeningDir+":Track13Cn")
	
	Variable j, index, NLPts		= DimSize(CalciteArray,0)
	Variable Particle13C, Total13C = 0
	
	// Case (gCalcTrack): 1 = single only; 2 = full only; 3 = both
	
		
	if (gCalcTrack > 1)
		
		// Update the solid content of 13C per particle size times number of particles in solution
		
		for (j=0;j<NLPts;j+=1)
			// !*! Not making any fucking sense, but to get a COLUMN I need the ROW operation
			// MatrixOp /FREE Col = col(CalciteArray,j)			// ... so this does not work. 
			MatrixOp /FREE Col = row(CalciteArray,j) ^t 			// 
			Calcite13C[j] 		= sum(Col) * CalciteNP[j]			// <--- The Calcite array already considers surface area so just need to multiple by number of particles
		endfor
			
		// Add up the total amount of 13C in suspension for each particle size (to be converted to µmoles per gram)
		
		// Sum over all the particles in the distribution
		//!*!*! THIS COULD BE A ONE-LINER
		for (j=0;j<NLPts;j+=1) 
			Total13C 		+= Calcite13C[j]
		endfor
		
		// Multiply by 1e6 to convert to micromoles. Divide by 1000 to convert from 1 m3 to 1L
		Track13C[i+1] = 1e3*Total13C/TotalMass
	endif
	
	// *** DOES NOT SAVE ANY TIME TO DO THIS SO FORGET ABOUT IT ***
	if (gCalcTrack != 2)
		// Track 13C incorporation of a SINGLE particle size
		MatrixOp /FREE Col = row(CalciteArray,gMeanLIndex) ^t
		Particle13C 		= sum(Col) * CalciteNP[gMeanLIndex]		// 
		
		// Scale to match the total surface area of the system ... hmmm ... I think better to scale to the total mass
		// Particle13C *= (sum(CalciteArea)/CalciteArea[gMeanLIndex])
		
		// Scale to match the Total Mass of the system 
		Particle13C *= (sum(CalciteMass)/CalciteMass[gMeanLIndex])
		
		// This is my estimate of the total uptaken for the whole distribution, based on the total for a single particle. 
		Track13Cn[i+1] 	= 1e3*Particle13C/TotalMass
	endif
	
End

// Record diffusion profiles of the mean size particle
Function DiffusionRecord(i,SimulationDir)
	Variable i
	String SimulationDir

	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave LayerV				= root:KINETICS:LayerV				// The Volume of Nth layer (? varies ?)
	
	NVAR gMeanLIndex 		= root:KINETICS:gMeanLIndex
	NVAR gDensity 			= root:KINETICS:gDensity
	NVAR gUnitA 				= root:KINETICS:gUnitA
	NVAR gFW 					= root:KINETICS:gFW
	
	Variable NLayers 				= DimSize(CalciteArray,1)
	
	Make /O/D/N=(NLayers) $(SimulationDir+":Diffusion:Calcite13CProfile_"+num2str(i)) /WAVE=Calcite13CProfile_i
	
	// Set the axis in nm
	Variable UnitA = 1e9*gUnitA
	SetScale /P x, 1.5*UnitA, 2*UnitA, "nm",Calcite13CProfile_i
	
	// !*! Not making any fucking sense, but to get a COLUMN I need the ROW operation
	// MatrixOp /FREE Col = col(CalciteArray,LNum)
	MatrixOp /FREE Col = row(CalciteArray,gMeanLIndex)^t
	
	// Moles of 13C per m3 (? I think ?)
//	Calcite13CProfile_i[] 	= (1000*Col[p])/(LayerV[p]/gDensity)
	
	// The ratio of 13C:12C per layer
	// Note that the moles of Ctot per layer = LayerV * gDensity/gFormulaWeight
	Calcite13CProfile_i[] 	= (Col[p]/LayerV[p])*(gFW/gDensity)
	
End

Function RipeningRecord(i,NLayers,SimulationDir)
	Variable i, NLayers
	String SimulationDir

	Wave CalciteNP			= root:KINETICS:CalciteNP			// 
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteLength_0	= root:KINETICS:CalciteLength_0	// The initial Length of Nth particle
	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	Wave Calcite13C			= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
	Wave CalciteDMoles		= root:KINETICS:CalciteDMoles		// Change in the number of moles for each particle
	
	Make /O/D/N=(NLayers) $(SimulationDir+":Ripening:Calcite13C_"+num2str(i)) /WAVE=Calcite13C_i
	Calcite13C_i[] 	= Calcite13C[p] * CalciteNP[p]
	
	// This is not really a useful record. 
//	Make /O/D/N=(NLayers) $(SimulationDir+":Ripening:CalciteDM_"+num2str(i)) /WAVE=CalciteDM_i
//	CalciteDM_i 	= CalciteDMoles
			
	Make /O/D/N=(NLayers) $(SimulationDir+":Ripening:CalciteMass_"+num2str(i)) /WAVE=CalciteMass_i
	CalciteMass_i 	= CalciteMass
	
	// *** 2017-07-28 Something strange seems to be happening when trying to re-interpolate onto initial Length axis. 
	
	// KEEP THE VARYING Length waves
	Make /O/D/N=(NLayers) $(SimulationDir+":Ripening:CalciteLen_"+num2str(i)) /WAVE=CalciteLen_i
	CalciteLen_i 	= CalciteLength
//	CalciteLen_i 	= CalciteLength_0
		
//	Make /FREE/D/N=(NLayers) CalciteNP_i
	
	// CalciteParticleInterpolate2(XtalLen,XtalLen_0,XtalNum,XtalNum_Interp,XtalMass,XtalMass_Interp)
//	CalciteParticleInterpolate2(CalciteLength,CalciteLength_0,CalciteNP,CalciteNP_i,CalciteMass,CalciteMass_i)
	
End


// Re-interpolate the Number and Mass distributions onto the original Length axis
Function CalciteParticleInterpolate2(XtalLen,XtalLen_0,XtalNum,XtalNum_Interp,XtalMass,XtalMass_Interp)
	Wave XtalLen,XtalLen_0,XtalNum,XtalNum_Interp,XtalMass,XtalMass_Interp
		
	NVAR gDensity 			= root:KINETICS:gDensity
	
	// This step should not increase the total mass! 
	Variable TotalMass, TotalMass_Interp, NLPts=DimSize(XtalLen,0)
	
	TotalMass 			= sum(XtalMass)
	
	// Interpolate2			{-----destination waves----}   {-----input  waves----}
	Interpolate2 /T=1/I=3/X=XtalLen_0/Y=XtalNum_Interp XtalLen, XtalNum
	
	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
	
	TotalMass_Interp 	= sum(XtalMass_Interp)
	
	XtalNum_Interp *= (TotalMass/TotalMass_Interp)
	
	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
	
	TotalMass_Interp 	= sum(XtalMass_Interp)
	
	// *** DO NOT ALTER THE INPUT WAVES AS WE ARE NOT INTERPOLATING THE Calcite Array
	// XtalLen 				= XtalLen_0
	// XtalNum 			= XtalNum_Interp
	
End

// Reports the properties of the ith particle
Function CalciteParticleProperties(i)
	Variable i

	NVAR gMolVol 			= root:KINETICS:gMolarVolume
	NVAR gDensity			= root:KINETICS:gDensity
	NVAR gUnitA 			= root:KINETICS:gUnitA
	
	WAVE CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	WAVE CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	WAVE CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	WAVE CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	WAVE Calcite13C		= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
	WAVE CalciteLastN		= root:KINETICS:CalciteLastN		// Index of the outermost layer
	
	Variable NSpts 	= DimSize(CalciteArray,1)
	Variable ParticleL, ParticleA, ParticleV, Surface13C, Bulk13C
	
	// The properties of the outermost layer. 
	Variable N, L, VL, VLf, VLe, ML, NC, N13C, FsurfL, SAL, C13CL
	
	ParticleL 	= CalciteLength[i]
	N	 			= CalciteLastN[i]
	L 				= (2*N - 1)*gUnitA								// The Length bounding the particle
	VL 			= gUnitA^3 * ((2*N-1)^3 - (2*N-3)^3)		// The Total Volume of the outer layer (in m3)
	VLf 			= ParticleL^3 - gUnitA^3*(2*N-3)^3		// The Volume of the partially filled final layer
	VLe 			= VL - VLf										// The Volume of the partially empty final layer
	ML 			= VLf * gDensity								// The Mass of the partially filled final layer (in kg)
	
	NC 			= VLf/gMolVol 									// The moles of C in the outermost layer
	N13C 			= CalciteArray[i][N]							// The moles of 13C in the outermost layer
	FsurfL 		= N13C/NC											// The 13C fraction
	SAL 			= (VLf/VL) * (6*L^2)							// The partial surface area of the outermost layer
	
	C13CL 		= (N13C*1e6)/(ML*1e3)							// The concentration of 13C in µmol/gram calcite
	
	
	// The properties of the lower layer. 
	Variable Nm, Lm, VLm, MLm, NmC, Nm13C, FsurfLm, SALm, C13CLm
	Nm 			= N-1											// The lower layer
	Lm 			= (2*Nm - 1)*gUnitA							// The Length of the lower layer particle
	VLm 			= gUnitA^3 * ((2*Nm-1)^3 - (2*Nm-3)^3)	// The Total Volume of the lower layer (completely filled)

	NmC 			= VLm/gMolVol 									// The moles of C in the lower layer
	Nm13C 		= CalciteArray[i][Nm]							// The moles of 13C in the lower layer
	FsurfLm 		= Nm13C/NmC									// The 13C fraction
	SALm 			= 6*Lm^2										// The full surface area of the lower layer
	MLm 			= VLm * gDensity								// The Mass of the lower layer (in kg)
	
	C13CLm 		= (Nm13C*1e6)/(MLm*1e3)					// The concentration of 13C in µmol/gram calcite
	
	
	MatrixOp /FREE Col = row(CalciteArray,i)^t
	Surface13C 	= Col[N]
	Bulk13C 		= sum(Col)
	
	Print " 	*** The properties of the",i,"particle in the distribution"
	Print "			Length 	=",CalciteLength[i]*1e6,"µm"
	
	Print " 			13C concentration in outer layer is",C13CL,"µmol/g and the molar fraction is",FsurfL
	Print " 			13C concentration in lower layer is",C13CLm,"µmol/g and the molar fraction is",FsurfLm
	
	
End
				
				

// These waves Track important properties of the entire distribution, or solution, as a function of Time
Function CalciteTrackingWaves(TStep,NTPts,TotalMass,CaAqInit,RipeningDir,SimNote)
	Variable TStep,NTPts,TotalMass,CaAqInit
	String RipeningDir,SimNote
	
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	Wave CalciteArea		= root:KINETICS:CalciteArea			// The Total ARea of Nth particle (varies)
	
	String OldDF = getDataFolder(1)
	NewDataFolder /O/S $RipeningDir
	
		// The solution concentration of Ca (moles/m3)
		Make /O/D/N=(NTPts) TrackCaAq=NaN
		TrackCaAq[0] 	= CaAqInit
	
		// The total # moles of 13C in the entire calcite particle distribution (moles)
		Make /O/D/N=(NTPts) Track13C=NaN, Track13Cn=NaN
		Track13C[0] 	= 0
		Track13Cn[0] 	= 0
		Note /K Track13C, SimNote
	
		// The total mass of calcite (kg)
		Make /O/D/N=(NTPts) TrackMass=NaN
		TrackMass[0] 	= TotalMass
	
		// The mean (weight-normalized) length (m)
		Make /O/D/N=(NTPts) TrackLength=NaN
		TrackLength[0] = MeanLength(CalciteLength,CalciteMass)
	
		// The surface area of the calcite particles (m2)
		Make /O/D/N=(NTPts) TrackSA=NaN
		TrackSA 			= sum(CalciteArea)
	
		// The moles of CaCO3 that have newly grown during the simulation
		Make /O/D/N=(NTPts) TrackReXtl=NaN
		TrackReXtl 			= 0
		
		// The time in Days
		Make /O/D/N=(NTPts) Track_Days
		Track_Days[] 	= p*TStep/MinToDays
		
	NewDataFolder /O/S $(RipeningDir+":Ripening")
		KillWaves /A/Z
		
	NewDataFolder /O $(RipeningDir+":Diffusion")
		KillWaves /A/Z

	SetDataFolder $OldDF
End

Function PauseORE()
	Variable dummy = 1
	
	return 1
End

// **************** 			Solid State Diffusion time point, i
// 	This does not change the size of the particle, so (isotope masses notwithstanding) we could treat TotalMass as fixed

// 	A single diffusion step using fully implicit discretization scheme
// 	The time step, dt, is contained in the A-matrix values. 

Function SSDiffusionStep(i,RipeningDir)
	Variable i
	String RipeningDir
	
	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave LayerV				= root:KINETICS:LayerV				// The Length of Nth particle (varies)
	
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	Wave Calcite13C			= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
	Wave CalciteLastNm 	= root:KINETICS:CalciteLastNm		// Quick look up for the LOWER LAYER of the particle of length L
	Wave Calcite13CProfile = root:KINETICS:Calcite13CProfile	//
	
	NVAR gCalcTrack 		= root:KINETICS:gCalcTrack			// Are we simulating and tracking a single particle or a full distribution? 
	NVAR gMeanLIndex		= root:KINETICS:gMeanLIndex		// Index of (initial) most numerous particle
	
	// The diffusion arrays
	Wave MatrixA 			= root:KINETICS:MatrixA
	Wave MatrixB 			= root:KINETICS:MatrixB
	
	// The solid-state diffusion coefficient for carbonate ions (in m2/min)
	NVAR gkDiff 		= root:KINETICS:gkDiff
	
	// The time step in Minutes
	NVAR gTStep 		= root:KINETICS:gTStep
	
	Variable NLPts		= DimSize(CalciteArray,0)
	Variable NBPts		= DimSize(MatrixB,0)
	
	// 	*** Always neglect the 2 smallest particle sizes. 
	Variable j, jStart=2, jStop=NLPts-1
	Variable n, Nm, SAm, ParticleL
	
	// Case (gCalcTrack): 1 = single only; 2 = full only; 3 = both
	if (gCalcTrack == 1)
		jStart 	= gMeanLIndex
		jStop 	= gMeanLIndex
	endif
	
	for (j=jStart;j<=jStop;j+=1)
	
		// The geometry of the particle
		ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
		Nm 				= CalciteLastNm[j]		// <---- The index for the LOWER outermost layer
		SAm 			= 6*ParticleL^2		// <---- The surface area of a single particle
		
		if (ParticleL > 0)
		
			// Extract the 13C concentration values and transfer to the B-Matrix. 
			MatrixB = 0
			for (n=Nm;n>=0;n-=1)
				// 	this indexes properly ... but incorrectly handles the fact that CalciteArray contains the TOTAL 13C for each layer, not the concentration. 
				// MatrixB[NBPts - (Nm - n)] 	= CalciteArray[j][n+1]/SAm	 		// <-- ** Re-divide by the Surface Area
				
				// ** Divide by the volume of each layer
				MatrixB[NBPts - (Nm - n)] 	= CalciteArray[j][n+1]/LayerV[n+1]
			endfor
			
			// Tridiagonal matrix solver
			MatrixLinearSolve /M=4 MatrixA, MatrixB		// MatrixLinearSolveTD might be more efficient ... 
			WAVE M_B = M_B								// <--- The results (values at time n+1) are recorded in this new array
			
//			if (i>39900)
//				PauseORE()
//			endif
			
			for (n=Nm;n>=0;n-=1)				
				// This indexes properly ... but has same error as above
				// CalciteArray[j][n] 			= M_B[NBPts - 1 - (Nm - n)][0] * SAm	// <-- ** Re-multiply by the Surface Area
				
				// ** Multiple by the volume of each layer
				CalciteArray[j][n] 			= M_B[NBPts - 1 - (Nm - n)][0] * LayerV[n]
			endfor
			
		endif
		
	endfor
End

// Prepare the B- and A-matrices
// 	The A-matrix is the N x N matrix in the equation A x X = B
// 	X are the unknowns at time n+1
//	B are the known values at time n
Function MakeSSDiffusionMatrices(dt,NLs)
	Variable dt,NLs
	
	NVAR gkDiff 		= root:KINETICS:gkDiff
	NVAR gUnitA 		= root:KINETICS:gUnitA
	
	Print " 		--- Carbonate diffusion coefficient = "+num2str(gkDiff)+" m2/min, or "+num2str(gkDiff/60)+"m2/s"
	
	// Just model diffusion in a PARTIAL layer 
	Variable i
	
	Variable a = (dt*gkDiff)/(gUnitA^2)
	
	// The B-matrix is reused. It will contain the concentration of each species
	Make /O/D/N=(NLs,0) MatrixB=0
	
	// The A-matrices describe how diffusion and other processes affect the local concentrations. 
	Make /O/D/N=(NLs,NLs) MatrixA = 0
	
	
	// Treat the edges separately
	for (i=1;i<NLs-1;i+=1)
		MatrixA[i][i-1] 	= -a		
		MatrixA[i][i+1] 	= -a
		MatrixA[i][i] 		= (1 + 2*a)
	endfor
	
//	// Zero gradient boundary conditions at INTERIOR
	MatrixA[0][0] 			= (1 + 2*a)
	MatrixA[0][1] 			= -2*a
	
	// Constant value boundary conditions at INTERIOR
//	MatrixA[0][0] 			= 1
//	MatrixA[0][1] 			= 0
	
	// Constant value boundary conditions at SURFACE
	MatrixA[NLs-1][NLs-1] 	= 1
	MatrixA[NLs-1][NLs-2] 	= 0
End

//// 	This is the N x N matrix in the equation A x X = B
//// 	X are the unknowns at time n+1
////	B are the known values at time n
//Function MakeDiffusionMatrix(AMatrix,dx,dt,D,C0,CN)
//	Wave AMatrix
//	Variable ,dx,dt,D,C0,CN
//	
//	Variable i, NPts=Dimsize(AMatrix,0)
//	Variable a = (dt*D)/(dx^2)
//	
//	AMatrix 	= 0
//	
//	// Treat the edges separately
//	for (i=1;i<NPts-1;i+=1)
//		AMatrix[i][i-1] 	= -a		
//		AMatrix[i][i+1] 	= -a
//		AMatrix[i][i] 		= (1 + 2*a)
//	endfor
//	
//	// Boundary conditions at LEFT side
//	if (C0 < 0)
//		//Zero gradient
//		AMatrix[0][0] 		= (1 + 2*a)
//		AMatrix[0][1] 		= -2*a
//	else
//		// Constant value
//		AMatrix[0][0] 		= 1
//		AMatrix[0][1] 		= 0
//	endif
//	
//	// Boundary conditions at RIGHT side
//	if (CN < 0)
//		//Zero gradient
//		AMatrix[NPts-1][NPts-1] 		= (1 + 2*a)
//		AMatrix[NPts-1][NPts-2] 		= -2*a
//	else
//		// Constant value
//		AMatrix[NPts-1][NPts-1] 		= 1
//		AMatrix[NPts-1][NPts-2] 		= 0
//	endif
//End


// **************** 			A single Surface Exchange time point, i
Function ExchangeStep(i,RipeningDir)
	Variable i
	String RipeningDir
	
	// 
	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	Wave Calcite13C		= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
	WAVE CalciteLastN 		= root:KINETICS:CalciteLastN
	WAVE CalciteLastNm 	= root:KINETICS:CalciteLastNm
	
	NVAR gCalcTrack 		= root:KINETICS:gCalcTrack			// Are we simulating and tracking a single particle or a full distribution? 
	NVAR gMeanLIndex		= root:KINETICS:gMeanLIndex		// Index of (initial) most numerous particle

	// Waves tracking the change in solution and particle composition
	Wave Track13C			= $(RipeningDir+":Track13C")
	
	// The rate of exchange of carbonate ions
	NVAR gkExch 		= root:KINETICS:gkExch
	
	// The time step in Minutes
	NVAR gTStep 		= root:KINETICS:gTStep
	
	// The thickness of a single layer
	NVAR gUnitA		= root:KINETICS:gUnitA
	
	// The molar volume, fixed at 3.12e-05	 m3/mol 
	NVAR gMolVol 		= root:KINETICS:gMolarVolume
	
	// The solution concentration of CARBONATE due to equilibration with the atmosphere
	// FIXED at 9.58e-3 moles/m3 = mM/L ... which is INCORRECT for the initial closed period. 
	NVAR gCO32Aq 		=  root:KINETICS:gCO32Aq
	
	// The proportion of 13C in aqueous CO2 -- FIXED at 1/(89.7949-1) 
	// Use this ratio to determine the 13C:12C of newly formed calcite. Currently does not consider fractionation during growth. 
	NVAR g13CAq 		= root:KINETICS:g13CAq
	
	// For clarity, we will rename this variable Fsoln
	Variable FsurfL, FsurfLm, Fsoln 		= g13CAq
	
	Variable NLPts		= DimSize(CalciteArray,0)
		
	// 	*** Always neglect the 2 smallest particle sizes. 
	Variable j, jStart=2, jStop=NLPts-1
	Variable N, L, SAL, VL, VLf, VLe, NC, N13C, Nm, Lm, SALm, VLm, NmC, Nm13C
	Variable d13CL, d13CLm, Total13C=0
	Variable ParticleL
	
	
	// Case (gCalcTrack): 1 = single only; 2 = full only; 3 = both
	if (gCalcTrack == 1)
		jStart 	= gMeanLIndex
		jStop 	= gMeanLIndex
	endif
	
	for (j=jStart;j<=jStop;j+=1)
	
		// The geometry of the particle
		ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
		
		if (ParticleL > 0)
			
			// The outer layer bounding the particle
			N 		= trunc ((ParticleL/gUnitA+1)/2)+1			// The outer layer bounding the particle, starting from 1 not 0
			L 		= (2*N - 1)*gUnitA									// The Length bounding the particle
			VL 		= gUnitA^3 * ((2*N-1)^3 - (2*N-3)^3)		// The Total Volume of the outer layer
			VLf 		= ParticleL^3 - gUnitA^3*(2*N-3)^3		// The Volume of the partially filled final layer
			VLe 	= VL - VLf											// The Volume of the partially empty final layer
			
			if (VLf > 0)
				NC 		= VLf/gMolVol 								// The moles of C in the outermost layer
				N13C 	= CalciteArray[j][N]							// The moles of 13C in the outermost layer
				FsurfL 	= N13C/NC										// The 13C fraction
				SAL 	= (VLf/VL) * (6*L^2)							// The partial surface area of the outermost layer
			
			
				// ------- SURFACE EXCHANGE WITH THE FINAL (PARTIAL) LAYER
				d13CL 	= gkExch * gTStep * SAL * (Fsoln - FsurfL)
				
				// ** DEBUG - disable this layer
				CalciteArray[j][N] 	+= d13CL
				// Calcite13C[j] 	+= d13CL	// <--- this is now updated separately
				//---------------------------------------------
				
				//---------------------------------------------
				CalciteLastN[j] = N 				// <--- This is IMPORTANT for debugging
				//---------------------------------------------
			else
				d13CL = 0
			endif
			
			
			// The lower layer of the particle
			if (N >1)
				Nm 		= N-1											// The lower layer
				Lm 		= (2*Nm - 1)*gUnitA						// The Length of the lower layer particle
				VLm 		= gUnitA^3 * ((2*Nm-1)^3 - (2*Nm-3)^3)	// The Total Volume of the lower layer (completely filled)
			
				NmC 		= VLm/gMolVol 								// The moles of C in the lower layer
				Nm13C 	= CalciteArray[j][Nm]						// The moles of 13C in the lower layer
				FsurfLm 	= Nm13C/NmC									// The 13C fraction
				SALm 		= 6*Lm^2										// The full surface area of the lower layer
			
				// ------- SURFACE EXCHANGE WITH THE LOWER (FULL) LAYER
				d13CLm 	= gkExch * gTStep * SALm * (Fsoln - FsurfLm)
				
				// ** DEBUG - disable this layer
				CalciteArray[j][Nm] 	+= d13CLm
				// Calcite13C[j] 		+= d13CLm 	// <--- this is now updated separately
				
				
				//---------------------------------------------
				CalciteLastNm[j] = Nm 		// <--- This is IMPORTANT for the diffusion routine
				//---------------------------------------------
				
			else
				// Basically do nothing 
				d13CLm = 0
			endif
		
		endif
	endfor
	
	
End


// **************** 			A single Ostwald Ripening time point, i
// ****************			VERSION 2 - consider unit cell layers on every particle
Function RipeningStep2(i,MixFlag,RipeningDir)
	Variable i,MixFlag
	String RipeningDir
	
	// Wave tracking particle growth and layer-by-layer incorporation of 13C
	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
	Wave CalciteArea		= root:KINETICS:CalciteArea			// The Total Mass of Nth particle (varies)
	Wave CalciteDMoles		= root:KINETICS:CalciteDMoles		// The number of moles lost or gained from each particle
	Wave CalciteKsp 		= root:KINETICS:CalciteKsp			// Solubility product for Nth particle (varies)
	Wave Calcite13C			= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers

	// Waves tracking the change in solution and particle composition
	Wave TrackCaAq			= $(RipeningDir+":TrackCaAq")	// The solution concentration of CALCIUM which varies due to calcite dissolution/precipitation
	Wave Track13C			= $(RipeningDir+":Track13C")
	Wave TrackSA				= $(RipeningDir+":TrackSA")
	Wave TrackMass			= $(RipeningDir+":TrackMass")
	Wave TrackLength		= $(RipeningDir+":TrackLength")
	Wave TrackReXtl			= $(RipeningDir+":TrackReXtl")
	
		
	// The formula weight of calcite, fixed at 0.100087 kg/mol	
	NVAR gFW 			= root:KINETICS:gFW
	
	// The desnity of calcite
	NVAR gDensity 		= root:KINETICS:gDensity
	
	// The interfacial free energy
	NVAR gIFE 			= root:KINETICS:gIFE
	
	// The molar volume, fixed at 3.12e-05	 m3/mol 
	NVAR gMolVol 		= root:KINETICS:gMolarVolume
	
	// The time step in Minutes
	NVAR gTStep 		= root:KINETICS:gTStep
	
	// The rate for surface dissolution or precipitation -- VARIABLE --
	NVAR gkDiss		= root:KINETICS:gkDiss		// <---- In Minutes!!!
	NVAR gkExch		= root:KINETICS:gkExch		// <---- In Minutes!!!
	
	// Option to fix the solution saturation state
	NVAR gManualOmega	= root:KINETICS:gManualOmega		// <--- Ignored if negative, fixed if positive
	
	// --------------------------------------------------
	
	// The solution concentration of CARBONATE due to equilibration with the atmosphere
	// FIXED at 9.58e-3 moles/m3 = mM/L ... which is INCORRECT for the initial closed period. 
	NVAR gCO32Aq 		=  root:KINETICS:gCO32Aq
	
	// The proportion of 13C in aqueous CO2 -- FIXED at 1/(89.7949-1) 
	// Use this ratio to determine the 13C:12C of newly formed calcite. Currently does not consider fractionation during growth. 
	NVAR g13CAq 		= root:KINETICS:g13CAq
	
	
	// The number of particle sizes (11111 layers up to 10 µm)
	Variable NLPts		= DimSize(CalciteArray,0)

	Variable j, IAP, Omega, TotalMass, Total13C=0
	Variable Moles_d, Vol_d, Vol_New
	Variable N, L, VL, VLf, VLe, N13C, Nm, Lm, VLm, Nm13C
	Variable ParticleNP, ParticleL, ParticleSA, ParticleVol, ParticleMoles
	
	// This should be a global variable
	Variable UnitA 		= 0.45e-9	// m
	
	// Account for the Ca released or taken from the solution at each time step
	Variable CaAq_D 	= 0
	
	// Account for the number of moles of new ("recrystallized") calcite
	Variable SurfaceArea, ReXtl = 0 
	
	// 			*** At Each Time Step ***
	
	// Track the number of moles lost from or gained by a single particle
	CalciteDMoles 		= 0
	
	// Calculate the Ksp for each size of particle in the Array
	ParticleKsp(CalciteKsp,CalciteLength)
	
	// Calculate the Ion Activity Product of the solution (in moles/L)
	IAP 	= TrackCaAq[i] * gCO32Aq * 1e-6
	
	// The proportion of 13C incoporated into newly-formed calcite (unitless)
	// Currently this is fixed at the aq-atm ratio and does not consider fractionation during growth. 
	Variable Fraction13C = (MixFlag == 1) ?  g13CAq :  0
	
	Variable Lost13C, Added13C
	
	// 	*** Loop over all the particle sizes ***
	for (j=0;j<NLPts;j+=1)
			
			// The geometry of the particle
			ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
			ParticleSA 		= 6 * ParticleL^2
			ParticleVol 		= ParticleL^3
			
			// Check whether there are any particles left in this size range
			ParticleMoles 	= ParticleVol/gMolVol
			
			if (ParticleMoles > 0)
			
				// The number of particles of this dimension
				ParticleNP 	= CalciteNP[j]
				
				// The geometries and composition of the outermost 2 layers: 
				
				// The outer layer bounding the particle
				N 		= trunc ((ParticleL/UnitA+1)/2)+1				// The outer layer bounding the particle, starting from 1 not 0
				L 		= (2*N - 1)*UnitA									// The Length bounding the particle
				VL 		= UnitA^3 * ((2*N-1)^3 - (2*N-3)^3)		// The Total Volume of the outer layer
				VLf 		= ParticleL^3 - UnitA^3*(2*N-3)^3			// The Volume of the partially filled final layer
				VLe 	= VL - VLf											// The Volume of the partially empty final layer
				Nm13C 	= CalciteArray[j][Nm]							// The moles of 13C in the outermost layer
				
				// The lower layer of the particle
				if (N >1)
					Nm 		= N-1											// The lower layer
					Lm 		= (2*Nm - 1)*UnitA							// The Length of the lower layer particle
					VLm 	= UnitA^3 * ((2*Nm-1)^3 - (2*Nm-3)^3)	// The Total Volume of the lower layer (completely filled)
					N13C 	= CalciteArray[j][N]							// The moles of 13C in the lower layer
				else
					Nm 		= 0
					Lm 		= 0
					VLm 	= VLm
					N13C 	= 0
				endif
		
				// 									*** Solution Chemistry ***
			
				// Calculate the saturation state of the solution with respect to a certain particle size
				if (gManualOmega <= 0)
					Omega 		= IAP/CalciteKsp[j]
				else
					Omega 		= gManualOmega
				endif
			
				// The number of moles of CaCO3 lost from or added a single particle size (negative means dissolution)
				Moles_d	= gkDiss * gTStep * ParticleSA * (Omega - 1)			// (Omega^m - 1)^n where m=n=1
				
				// Make sure we don't try to dissolve away more than available ... hmmm. 
				if ((Moles_d < 0) && (abs(Moles_d) > ParticleMoles))
					Moles_d = -1 * ParticleMoles
				endif
				
				
				// Account for the Ca released or taken from the solution, changing the aqueous calcium concentration
				CaAq_D		-=  ParticleNP * Moles_d	// moles per m3 = mM
				
				// Calculate the Absolute change in total volume for particle dissolution or growth
				// It is easiest if we consider the absolute value gained or lost here, and use the sign of moles to indicate dissolution or growth
				Vol_d 		= abs(Moles_d * gMolVol)
				
				
				// 									*** Particle Properties  ***
				
				// Calculate the Volume and Length of the new particle. 
				// Looks like we have to ensure that this is never negative
				Vol_New 			= max(0,ParticleVol + sign(Moles_d)*Vol_d)
				
				CalciteLength[j] 	= (Vol_New)^(1/3)		// <---- the new Length of the jth particle
				
				CalciteDMoles[j] 	= Moles_d*ParticleNP
				
				if (Moles_d < 0)			// DISSOLUTION
					if (Vol_d < VLf)
						// Partial loss of the outermost layer
						Lost13C 			= N13C * (Vol_d/VLf)
						CalciteArray[j][N] 	-= Lost13C
				
						// Update the amount of 13C
						// Calcite13C[j] 		-= Lost13C 	// <--- this is now updated separately
						
					else
						// Complete loss of the outermost layer ...
						Lost13C 			= CalciteArray[j][N]
						CalciteArray[j][N] 	= 0
				
						// Update the amount of 13C
						Calcite13C[j] 		-= Lost13C
						
						// ... and partial loss of the next one. 
						Lost13C 			= Nm13C * (1 - (Vol_d-VLf)/VLm)
						CalciteArray[j][Nm] -= Lost13C	// <--- this is fine for N=1
				
						// Update the amount of 13C
						// Calcite13C[j] 		-= Lost13C 	// <--- this is now updated separately
					endif
					
				else							// GROWTH
				
					// The moles of "recrystallized" calcite
					ReXtl += Moles_d*ParticleNP
					
					if (Vol_d < VLe)
						// Partial growth of the outermost layer
						Added13C 			= Fraction13C * Moles_d
						CalciteArray[j][N] += Added13C
				
						// Update the amount of 13C
						// Calcite13C[j] 		+= Added13C	// <--- this is now updated separately
						
					else
						// First, finish one layer ...
						Added13C 			= Fraction13C * Moles_d * (VLe/Vol_d)
						CalciteArray[j][N] += Added13C
				
						// Update the amount of 13C
						Calcite13C[j] 		+= Added13C
						
						// ... the start adding to the next one. 
						Added13C 			= Fraction13C * Moles_d * (1 - VLe/Vol_d)
						CalciteArray[j][N+1] = Added13C
				
						// Update the amount of 13C
						// Calcite13C[j] 		+= Added13C 	// <--- this is now updated separately
					endif
					
				endif
				
			endif
			
	endfor
	
	// 	*** 	Update the distribution of particle masses and surface areas
	CalciteMass[] 		= CalciteNP[p] * CalciteLength[p]^3 * gDensity
	
	CalciteArea[] 		= 6*CalciteLength[p]^2 * CalciteNP[p]
	
	// 	*** 	Track the changes in particle dimensions and solution chemistry that are only altered by growth processes
	
	// Update the solution concentration of Ca in solution (moles per m3 = mM)
	TrackCaAq[i+1] 	= TrackCaAq[i] + CaAq_D
	
	// Update the total mass of calcite, which should not change too much
	TotalMass 			= sum(CalciteMass)
	TrackMass[i+1] 		= TotalMass						// <--- In kg/m3 == g/L
	
	// Update the mean length and surface area of the calcite size distribution
	TrackLength[i+1] 	= MeanLength(CalciteLength,CalciteMass)
	TrackSA[i+1] 		= sum(CalciteArea)/(TotalMass*1000) //  in m2/g
	
	// Update the number of moles of calcite that have "recrystallized" PER m2 SURFACE AREA
	SurfaceArea 			= sum(CalciteArea) 		//  in m2
	TrackReXtl[i+1] 	= ReXtl/SurfaceArea		// 
//	TrackReXtl[i+1] 	= ReXtl/TrackSA[i+1]
	
	return TotalMass
End

Function Progress_Kinetics(NSteps)
	Variable NSteps
	
	NewPanel/FLT /N=myProgress/W=(285,111,739,193)
	ValDisplay valdisp0,pos={18,32},size={342,18},limits={0,NSteps,0},barmisc={0,0}
	ValDisplay valdisp0,value= _NUM:0, mode= 3			// bar with no fractional part
	
	Button bStop,pos={375,32},size={50,20},title="Abort"
	SetActiveSubwindow _endfloat_
	DoUpdate/W=myProgress/E=1	// mark this as our progress window
	SetWindow myProgress,hook(spinner)= MySpinner
End

Function MySpinner(s)
	STRUCT WMWinHookStruct &s
	
	if( s.eventCode == 23 )
		ValDisplay valdisp0,value= _NUM:1,win=$s.winName
		DoUpdate/W=$s.winName
		if( V_Flag == 2 )	// we only have one button and that means abort
			KillWindow $s.winName
			return 1
		endif
	endif
	return 0
End

Function NewCalciteParticles(NewParticles,NTPts,NLayers,CaAqInit)
	Variable NewParticles,NTPts, NLayers, CaAqInit

	NVAR gDensity 		= root:KINETICS:gDensity
	NVAR gUnitA 		= root:KINETICS:gUnitA
	
	String  AxisType="Layers"
	
	if (NewParticles == 1)
		// This creates a distribution of actual particle number vs length in meters: 
		if (CalciteNumberDistribution(AxisType) == 0)
			return 0
		endif
	endif
	
	// -------------------------------------------------------
	// *** The starting particle distributions are XtalPDFLen and XtalPDFNum ****
	WAVE XtalPDFNum 			= root:KINETICS:XtalPDFNum 	// <--- Normalized to unity
	WAVE XtalPDFLen 			= root:KINETICS:XtalPDFLen	
	// -------------------------------------------------------
	// 	Note that XtalPDFLen and CalciteLength are IDENTICAL
	// 	Note that XtalPDFNum and CalciteNP are IDENTICAL
	// 	Note that XtalPDFMass and CalciteMass are IDENTICAL
	// 	Note that XtalPDFArea and CalciteArea (FREE) are IDENTICAL
	// -------------------------------------------------------
	
	Variable n=1, MeanL, NLPts = DimSize(XtalPDFLen,0)
	
	// Create other Particle Distribution Function properties
	Duplicate /O XtalPDFNum, XtalPDFVol, XtalPDFVo, XtalPDFMass, XtalPDFMo, XtalPDFArea, XtalPDFAo
	Duplicate /O XtalPDFNum, XtalPDFKsp, XtalPDF13CVol, XtalNumLen, temp0
	XtalPDF13CVol = 0
	
	NVAR gMineralConc 		= root:KINETICS:gMineralConc
	CalciteParticleDistributions(XtalPDFNum, XtalPDFLen,XtalPDFMass,XtalPDFVol,XtalPDFArea,XtalPDFVo,XtalPDFAo,XtalPDFMo,1,gMineralConc)
	
	// Calculate the INITIAL size-dependence of the solubility product, Ksp
	ParticleKsp(XtalPDFKsp,XtalPDFLen)
	
	Variable TotalMassXX, TotalMass 		= sum(XtalPDFMass)
	if (NewParticles == 1)
		Print " 	*** Created a distribution of particles with total mass of",TotalMass,"kg/m3 (=g/L) at",Secs2Time(datetime,1),"on",Secs2Date(datetime,1)
		Print " 			Surface area =",sum(XtalPDFArea)/(TotalMass*1000),"m2/g"
	endif
	
	// The number of layers is now a global variable
	//	NLayers 	= trunc(DimSize(XtalPDFLen,0)/2)
	Variable NCols 		= NLayers + 100 // <--- *** Note, some longer simulations can grow more than 100 layers ... .
	
	// The fundamental array for tracking 13C concentration per layer. 
	// -------------------------------------------------------
	Make /O/N=(NLayers,NCols) CalciteArray=0
	// -------------------------------------------------------
	//	Make /O/N=(NLayers,NLayers) CalciteArray=0 		// <-- Square array does not allow for growth of the largest particles. 
	
	// -------------------------------------------------------
	// *** The fundamental array particle distributions are CalciteLength, CalciteNP and CalciteMass ****
	// -------------------------------------------------------
	
	// The fundamental array of length of a side of each cubic particle in the Calcite array
	Make /O/D/N=(NLayers) CalciteLength, CalciteNP_n				// 	<--- the "_n" wave is needed for interpolation
	Make /O/D/N=(NLayers) CalciteLength_0, CalciteMass_0		//	<--- these could probably be deleted
	Make /O/D/N=(NLayers) CalciteLastN, CalciteLastNm			// 	<--- these are needed
	
	Make /O/D/N=(NCols) Calcite13CProfile					// 	<--- useful to plot the profile of 13C within any particle dimensions
	SetScale /P x, 1.5*gUnitA, 2*gUnitA, "m",Calcite13CProfile
	
	// CalciteLength[] 		= (2*p+1) * gUnitA					// This MUST be identical to XtalPDFLen ...  should clarify code here
	// CalciteLength[] 		= 2*p * 1.5*gUnitA					// This MUST be identical to XtalPDFLen ...  should clarify code here
	CalciteLength[] 		= XtalPDFLen[p]
	CalciteLength_0 		= CalciteLength
	
	// The number of particles with a given number of layers - FIXED 
	Make /O/D/N=(NLayers) CalciteNP
	CalciteNP[] 		= XtalPDFNum[p]
	
	// The total mass of particles in each size distribution
	Make /O/D/N=(NLayers) CalciteMass, CalciteDMoles=0
	CalciteMass[] 		= CalciteNP[p] * CalciteLength[p]^3 * gDensity
	CalciteMass_0 		= CalciteMass
	
	// The total Surface Area of particles in each size distribution
	Make /O/D/N=(NLayers) CalciteArea = 0
	CalciteArea[] 		= 6*CalciteLength[p]^2 * CalciteNP[p]
	
	// Check - these MUST be identical
	TotalMass 		= sum(XtalPDFMass)
	TotalMassXX 		= sum(CalciteMass)
	
	// The solubility of each particle as a function of Length - VARIES
	Make /O/D/N=(NLayers) CalciteKsp
	
	// The number of moles of 13C in a single particle  - VARIES
	Make /O/D/N=(NLayers) Calcite13C = 0
	
	// Need to be able to look up the valume of each layer in a single particle 
	Make /O/D/N=(NCols) LayerV
	LayerV[] 	= gUnitA^3 * ((2*(p+1)-1)^3 - (2*(p+1)-3)^3)   
	
	// Hmmm ... sum(LayerV,0,5554) is very close but a little less than ParticleL^3
	// ... OK, that's fine. It is because the particle lengths are chosen such that the final layer is only half occupied. 
	
	// Determine the average particle length
	MeanL 		= MeanLength(CalciteLength, CalciteMass)
	FindLevel /Edge=1 /Q CalciteLength, MeanL
	Variable /G gMeanLIndex = trunc(V_LevelX)
	
	if (NewParticles == 1)
		Print " 	*** Created a distribution of particles with total mass of",TotalMassXX,"kg/m3 (= g/L) at",Secs2Time(datetime,1),"on",Secs2Date(datetime,1)
		Print " 			Surface area =",sum(CalciteArea)/(TotalMass*1000),"m2/g"  // <-- Divide by 1000 is correct because there are 1000x more particles in 1m3 vs 1L
		Print " 			The mean particle length is",MeanL*1e6,"µm at array index",gMeanLIndex
	endif
	
	return TotalMass
End



Function CalciteParticleDistributions(XtalNum, XtalLen,XtalMass,XtalVol,XtalArea,XtalVo,XtalAo,XtalMo,SingleParticle,MineralConc)
	Wave XtalNum, XtalLen,XtalMass,XtalVol,XtalArea,XtalVo,XtalAo,XtalMo
	Variable SingleParticle, MineralConc
	
	Variable TotalMass

	// Required physical constants
	NVAR gDensity 		= root:KINETICS:gDensity
	
	// *** 	SINGLE PARTICLE PROPERTIES
	
	// !*!* Don't need to recalculate these every time step if the Length axis is not changing
	
	if (SingleParticle)
		// The surface area of a single particle within a distribution
		XtalAo[] 	= 6*XtalLen[p]^2
		// The volume of a single particle within a distribution
		XtalVo[] 	= XtalLen[p]^3
		// The mass of a single particle within a distribution
		XtalMo[] 	= XtalVo[p] * gDensity
	endif	
	
	// *** 	DISTRIBUTION PROPERTIES
	
	// The total mass per distribution length interval
	XtalMass[] 	= XtalNum[p] * XtalMo[p]
	TotalMass 	= sum(XtalMass)
	
	// If we are creating these distributions for the FIRST time, ...
	// ... scale the particle number so that we arrive at the correct total mass. 
	if (MineralConc > 0)
		XtalNum[] *= MineralConc/TotalMass
		XtalMass[] 	= XtalNum[p] * XtalMo[p]
		// Check this is correct
		TotalMass 	= sum(XtalMass)
	endif
	
	XtalArea[] 	= XtalNum[p] * XtalAo[p]
	XtalVol[] 	= XtalNum[p] * XtalVo[p]
	
End

// Calculate the mean particle length based on the Mass PDF
// 	See Stats_Mean(x, Px, Ix1, Ix2)
Function MeanLength(Len, Mass)
	Wave Len, Mass
	
	WAVE temp0 	= root:KINETICS:temp0
	
	Variable Mu, NLPts=DimSize(Len,0)
	
	temp0[] 	= Len[p] * Mass[p]
	
	Mu 	= areaXY(Len,temp0,0,NLPts-1)/areaXY(Len,Mass,0,NLPts-1)
	
	return Mu
End

Function DiffusionKinetics(w,x) : FitFunc
	Wave w				// 0 = scale
	Variable x
						
	return w[0] * x^(1/2)
End
		

		
// **************** 			The Initial Log-normal distribution of particle number

// From http://mathworld.wolfram.com/LogNormalDistribution.html

// 		Impossible to avoid the Error Function returning zero at the low end of the distribution.
// 		printf "%+15.66f\r"erf(-5.921,1e-70)
// 		-0.999999999999999888977697537484345957636833190917968750000000000000

Function LogNormal_CDFVar(x,a,b)
	Variable x,a,b
	
//	Variable acc = 1e-50
	
	return 0.5 + 0.5*erf((ln(x)-a)/(b*sqrt(2)),1e-50)
End


Function CalciteNumberDistribution(AxisType)
	String AxisType
	
	Variable i, NLpts 	= 200
	
	NVAR gUnitA 		= root:KINETICS:gUnitA
	NVAR gNLayers 		= root:KINETICS:gNLayers
	
	Variable LStart, LStop, LScale, sigma
	Variable TotalMass, SurfaceArea
	
	String OldDF = getDataFolder(1)
	SetDataFolder root:KINETICS
	
		Variable MineralConc = NumVarOrDefault("root:KINETICS:gMineralConc",15)	// Expt conditions were 15g/L = 15kg/m3
		Prompt MineralConc, "Mass of mineral (g/L)"
		Variable LgNmPosn = NumVarOrDefault("root:KINETICS:LogNormal:gLgNmPosn",0.1)
		Prompt LgNmPosn, "Starting log-normal position (µm)"
		Variable LgNmWidth = NumVarOrDefault("root:KINETICS:LogNormal:gLgNmWidth",0.1)
		Prompt LgNmWidth, "Starting log-normal width (µm)"
		Variable LgNmXScale = NumVarOrDefault("root:KINETICS:LogNormal:gLgNmXScale",0.1)
		Prompt LgNmXScale, "Axis scale factor"
		
		DoPrompt "Create a starting distribution of particles", MineralConc, LgNmPosn, LgNmWidth, LgNmXScale
		if (V_flag)
			return 0
		endif
		
		Variable /G gMineralConc 	= MineralConc
	
		NewDataFolder /O/S root:KINETICS:LogNormal
		
			Variable /G gLgNmPosn 		= LgNmPosn
			Variable /G gLgNmWidth 	= LgNmWidth
			Variable /G gLgNmXScale 	= LgNmXScale
			
			// Length axis
			LStart 	= 0.001
			LStop 	= 20
			
			// Value in MICROMETERS
			Variable UnitA 	= 0.00045 // = 0.45 nm
			// 	Variable UnitA 	= gUnitA * 1e6
			
			StrSwitch (AxisType)
			
				case "Logarithmic":
					// 	------	Make a LOG-AXES 0 - 20 micron axis. 
					
					// 	For the Cumulative Distribution Function
					NLpts 	= 200
					LScale 	= exp((ln(LStop)-ln(Lstart))/(NLPts+1))
					Make /O/D/N=(NLPts+1) XtalCDFLogAxis, XtalCDF
					
					XtalCDFLogAxis[0] 	= 0.001 // = 1 nm
					XtalCDFLogAxis[1,] 	= XtalCDFLogAxis[p-1]*LScale
					
					// 	For the Actual Particle Number Distribution Function
					LScale 	= exp((ln(LStop)-ln(Lstart))/NLPts)
					Make /O/D/N=(NLPts) XtalPDFLogAxis, XtalPDF
					
					XtalPDFLogAxis[0] 	= 0.001 // = 1 nm
					XtalPDFLogAxis[1,] = XtalPDFLogAxis[p-1]*LScale
					
					break
				
				case "Layers":
					// 	------	Make Axis for each new monolayer of the CaCO3 formula unit (= 4.5 )
					
					// 	For the Cumulative Distribution Function
					// 	NLpts 	= 22222		// Up to 20 µm ... too much for memory
					// 	NLpts 	= 11111		// Up to 10 µm ... OK, single precision
					NLPts 	= gNLayers		// Currently 5555
					
					Make /O/D/N=(NLPts+1) XtalCDFLogAxis, XtalCDF
					
					// Make the particle lengths lie halfway through each layer
					XtalCDFLogAxis[] 		= 1.5*UnitA + 2*p*UnitA
					// XtalCDFLogAxis[] 	= UnitA + 2*p*UnitA
					
					// 	For the Actual Particle Number Distribution Function
					Make /O/D/N=(NLPts) XtalPDFLogAxis, XtalPDF
					XtalPDFLogAxis[] 	= 1.5*UnitA + 2*p*UnitA
					// XtalPDFLogAxis[] 	= UnitA + 2*p*UnitA
					
					break
				EndSwitch
			
			// 	------	Create the Distributions
			
			//	Make a Cumulative Distribution Function of Particle Number
			//	XtalCDF[] 	= StatsLogNormalCDF(XtalCDFLogAxis[p],LgNmWidth,LgNmPosn,LgNmMu)
			XtalCDF[] 	= LogNormal_CDFVar(XtalCDFLogAxis[p],LgNmPosn,LgNmWidth)
			
			// Add an exponential tail towards zero
			FindLevel /Q/EDGE=1 XtalCDF 1e-17
			
			for (i=trunc(V_LevelX);i>=0;i-=1)
				XtalCDF[i] = XtalCDF[i+1]/10
			endfor
	
			
			//	Make a distribution of Actual Number of Particles in a certain range
			XtalPDF[] 		= XtalCDF[p+1] - XtalCDF[p]
			
			// Now interpolate this distribution onto a SCALED axis
			Duplicate /O/D XtalPDFLogAxis, XtalPDFLogAxisScaled
			XtalPDFLogAxisScaled[] /= LgNmXScale
			
			// Interpolate back onto the non-shifted axis
			Duplicate /O/D XtalPDF, XtalPDFScaled
			
			// Interpolate2			{-------destination waves-----}   {-----input  waves----}
			Interpolate2 /T=1/I=3 /X=XtalPDFLogAxis/Y=XtalPDFScaled XtalPDFLogAxisScaled, XtalPDF
			
			XtalPDFScaled[] 	= max(XtalPDFScaled[p],0)
			
			// !*!* This step seems to leave a blip of non-zero points just before the start of the main distribution ... ignore for now
			
			// *** Now the relevant Particle Number distribution is XtalPDFScaled vs XtalPDFLogAxis ***
			
			// check that he sum of values in the Particle Distribution Function is unity. 
			//		print sum(XtalPDFNum)
	
			// 	------	Fit an exponential tail and paste it to the XtalPDFNumShift function
			
			// Find the maximum value of this distribution. 
			WaveStats /Q/M=1 XtalPDFScaled
			Variable DistMax = V_max, DistMaxLoc = V_maxloc
			
			// Find where the distribution tanks
//			Variable TankValue = DistMax/5e12		// *** <---- 	this is a delicate choice !!!!!!!!!!!
			
			// debug 2017-07-28
			Variable TankValue = DistMax/5e12		// *** <---- 	this is a delicate choice !!!!!!!!!!!
			
			Variable TankTol = TankValue
			FindValue /S=(DistMaxLoc)/T=(TankTol)/V=(TankValue) XtalPDFScaled
			
			Variable DistZero = V_value
			print " 	... checking ... the zero-intensity index of the particle size distribution is at index: ", DistZero
			if (V_value < 0)
				print " problem looking for ",TankValue,"with tolerance",TankTol,"starting from",DistMaxLoc," ... you probably need to increase gNLayers"
				return 0
			endif
			
			// Fit an exponential decay 
			Variable FitRange=max(5,NLpts*(20/1000))
			
			FitRange = 40
			Variable FitStart=DistZero-FitRange
			
			Make /O/D/N=(3) TailCfs={0,1,1}
			CurveFit /Q/N/H="100" exp, kwCWave=TailCfs, XtalPDFScaled[FitStart,DistZero-2] /X=XtalPDFLogAxis
			
			Duplicate /O/D XtalPDFScaled, XtalPDFFinal, XtalPDFTail
			XtalPDFTail = 0
			XtalPDFTail[FitStart,] 		= TailCfs[0] + TailCfs[1]*exp(-1*TailCfs[2]*XtalPDFLogAxis[p])
			XtalPDFFinal[FitStart,] 	= XtalPDFTail[p]
			
			// *** We now have starting distributions in MICRONS  XtalPDFNumFinal vs XtalPDFLogAxis ***
			
		NewDataFolder /O/S root:KINETICS
		
			// *** Create starting distributions in METERS
			Duplicate /O XtalPDFFinal, XtalPDFNum
			Duplicate /O XtalPDFLogAxis, XtalPDFLen
			
			XtalPDFLen /= 1e6		// <------ Convert to meters
		
	SetDataFolder $OldDf
	
	return 1
End



// DEbuggin - works ... 
Function CheckLayerNumber()

	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
	Wave CalciteLastN		= root:KINETICS:CalciteLastN		// The index of the last bounding layer
	
	NVAR gUnitA 		= root:KINETICS:gUnitA
	NVAR gMolVol 		= root:KINETICS:gMolarVolume
	
	Variable j, NLPts = DimSize(CalciteLength,0)
	Variable N, L, VL, VLf, VLe, N13C, Nm, Lm, VLm, Nm13C
	Variable ParticleNP, ParticleL, ParticleSA, ParticleVol, ParticleMoles
	
	for (j=0;j<NLPts;j+=1)
	
		// The geometry of the particle
		ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
		ParticleSA 		= 6 * ParticleL^2
		ParticleVol 		= ParticleL^3
		ParticleMoles 	= ParticleVol/gMolVol
		
		// The number of particles of this dimension
		ParticleNP 	= CalciteNP[j]
		
		// The geometries and composition of the outermost 2 layers: 
		
		// The outer layer bounding the particle
		N 		= trunc ((ParticleL/gUnitA+1)/2)+1			// The outer layer bounding the particle, starting from 1 not 0
		L 		= (2*N - 1)*gUnitA								// The Length bounding the particle
		VL 		= gUnitA^3 * ((2*N-1)^3 - (2*N-3)^3)		// The Total Volume of the outer layer
		VLf 		= ParticleL^3 - gUnitA^3*(2*N-3)^3			// The Volume of the partially filled final layer
		VLe 	= VL - VLf										// The Volume of the partially empty final layer
		
		CalciteLastN[j] = N
		
		// The lower layer of the particle
		if (N >1)
			Nm 		= N-1											// The lower layer
			Lm 		= (2*Nm - 1)*gUnitA							// The Length of the lower layer particle
			VLm 	= gUnitA^3 * ((2*Nm-1)^3 - (2*Nm-3)^3)	// The Total Volume of the lower layer (completely filled)
		else
			Nm 		= 0
			Lm 		= 0
			VLm 	= VLm
		endif
		
		CalciteLastN[j] = Nm
	endfor
end

// This really is pretty redundant ... 
Function CalciteEndRipening2(NSteps,TStep,RipeningDir)
	Variable NSteps,TStep
	String RipeningDir
	
	Wave TrackCaAq			= $(RipeningDir+":TrackCaAq")
	Wave Track13C			= $(RipeningDir+":Track13C")
	Wave TrackMass		= $(RipeningDir+":TrackMass")
	Wave TrackLength		= $(RipeningDir+":TrackLength")
	Wave TrackSatLen		= $(RipeningDir+":TrackSatLen")
	Wave TrackMinLen		= $(RipeningDir+":TrackMinLen")
	
	String OldDF = getDataFolder(1)
	SetDataFolder $RipeningDir
	
		Make /O/D/N=(NSteps) Track_Days, TrackCaAq_Days, Track13C_Days, TrackMass_Days, TrackLength_Days, TrackSatLen_Days, TrackMinLen_Days
		
		Track_Days[] 			= p*TStep/MinToDays
		TrackCaAq_Days[] 		= TrackCaAq[p]
		Track13C_Days[] 		= Track13C[p]
		TrackMass_Days[] 		= TrackMass[p]
		TrackLength_Days[] 	= TrackLength[p]*1e6
		TrackSatLen_Days[] 	= TrackSatLen[p]
		TrackMinLen_Days[] 	= TrackMinLen[p]
	
	SetDataFolder $OldDF
End


Function SSReadWriteTEst(j,nT)
	Variable j,nT
	
	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
	Wave CalciteLastNm 	= root:KINETICS:CalciteLastNm		// Quick look up for the outer edge of the particle of length L

	
	Wave MatrixB 			= root:KINETICS:MatrixB
	Duplicate /O MatrixB, MatrixB2
	
	Variable n, kk, Nm, SAm, ParticleL
	
	// The geometry of the particle
	ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
	Nm 				= CalciteLastNm[j]		// <---- The index for the LOWER outermost layer
	SAm 			= 6*ParticleL^2		// <---- The surface area of a single particle
	
	Variable NBPts		= DimSize(MatrixB,0)
	
	
	MatrixOp /O MatrixB2 = row(CalciteArray,j)^t
	
	// NOTE: The B-Matrix might be smaller or larger than the specific particle size. 
	MatrixB = 0
	for (n=Nm;n>=0;n-=1)
		// 	this works
		MatrixB[NBPts - (Nm - n)] 	= CalciteArray[j][n+1]//SAm	 					// <-- ** Important to re-divide by the Surface Area
	endfor
End


//// This assumes gTStep minute per setp
//Function SSDiffusionTest(PNum,nT)
//	Variable PNum,nT
//	
//	InitializeKinetics()
//	
//	SetDataFolder root:KINETICS
//	
//	Wave CalciteArray		= root:KINETICS:CalciteArray		// Fundamental array for tracking particle size and13C concentration per layer
//	Wave CalciteLength		= root:KINETICS:CalciteLength		// The Length of Nth particle (varies)
//	
//	Wave CalciteNP			= root:KINETICS:CalciteNP			// Number of particles in Nth array column (fixed)
//	Wave CalciteMass		= root:KINETICS:CalciteMass			// The Total Mass of Nth particle (varies)
//	Wave CalciteArea		= root:KINETICS:CalciteArea			// The Total Mass of Nth particle (varies)
//	Wave Calcite13C		= root:KINETICS:Calcite13C			// Total amount of 13C in each particle of N Layers
//	Wave CalciteLastNm 	= root:KINETICS:CalciteLastNm		// Quick look up for the outer edge of the particle of length L
//	
//	Wave Calcite13CProfile = root:KINETICS:Calcite13CProfile
//	
//	// The solid-state diffusion coefficient for carbonate ions (in m2/min)
//	NVAR gkDiff 		= root:KINETICS:gkDiff
//	
//	// The time step in Minutes
//	NVAR gTStep 		= root:KINETICS:gTStep
//	
//	// !*!*! Changing the time step to 1 hour
//	gTStep = 100
//	Print " 		--- The time step is",gTStep,"minutes and the total time of the simulation is",nT*gTStep/1440,"days"
//	
//	// The geometry of the particle
//	Variable n, kk, Nm, ParticleL, SAm
//	
//	Variable j 		= PNum
//	ParticleL 		= CalciteLength[j] 		// <---- Length of the jth particle before this growth/dissolution step. 
//	Nm 				= CalciteLastNm[j]		// <---- The index for the LOWER outermost layer
//	SAm 			= 6*ParticleL^2		// <---- The surface area of a single particle
//	
//	
//	// Change the dimension of the diffusion matrices to match the particle size
//	Wave MatrixB 			= root:KINETICS:MatrixB
//	Redimension /N=(Nm) MatrixB
//	MatrixB = 0
//	
//	MakeSSDiffusionMatrices(gTStep,Nm)
//	Wave MatrixA 			= root:KINETICS:MatrixA
//	
//	Variable NBPts			= DimSize(MatrixB,0)
//	Variable NLPts			= DimSize(CalciteArray,0)
//	
//	Variable TotalMass 		= sum(CalciteMass)
//	Variable AreaSF 		= sum(CalciteArea)/CalciteArea[PNum]
//	
//	Make /O/D/N=(nT) DiffusionRate, DiffusionDays
//	DiffusionRate 		= 0
//	DiffusionDays[] 	= (p*gTStep)/(1440)
//	
//	
//	Variable duration,timeRef = startMSTimer
//	
//	// 	This indexing loop works
//	for (n=Nm;n>=0;n-=1)
//		// The Calcite Array contains the total number of moles of 13C in the n'th layer.
//		// Divide by the outer surface area of the selected particle dimension
//		MatrixB[NBPts - (Nm - n)] 	= CalciteArray[j][n+1]/SAm
//	endfor
//	
//		
//	for (kk=0;kk<nT;kk+=1)
//	
//		// Tridiagonal matrix 
//		MatrixLinearSolve /M=4 MatrixA, MatrixB
//		// MatrixLinearSolveTD might be more efficient ... 
//		
//		// The results (values at time n+1) are recorded in this new array
//		WAVE M_B = M_B
//		
//		MatrixB[] 	= M_B[p][0]
//		
//		DiffusionRate[kk] = sum(MatrixB)
//		
//	endfor
//	
//	Calcite13CProfile = 0
//	
//	for (n=Nm;n>=0;n-=1)
//		if (0)
//			// This works
//			CalciteArray[j][n] 			= M_B[NBPts - 1 - (Nm - n)][0] * SAm
//		endif
//		
//		Calcite13CProfile[n] 			= M_B[NBPts - 1 - (Nm  - n)][0] * SAm
//		
//	endfor
//	
//	duration 	= stopMSTimer(timeRef)
//	Print " 		*** Diffusion test took",duration/60000000,"mins."
//	
//	// Scale to match the total surface area of the system
//	DiffusionRate *= AreaSF*SAm*CalciteNP[PNum]
//	
//	// convert to micromoles per gram of calcite
//	DiffusionRate *= 1e3/TotalMass
//			
//End
//
//
//	if (gCalcTrack != 2)
//		// Track 13C incorporation of a SINGLE particle size
//		MatrixOp /FREE Col = row(CalciteArray,gMeanLIndex) ^t
//		Particle13C 		= sum(Col) * CalciteNP[gMeanLIndex]		// 
//		
//		// Scale to match the total surface area of the system
//		Particle13C *= (sum(CalciteArea)/CalciteArea[gMeanLIndex])
//		
//		// This is my estimate of the total uptaken for the whole distribution, based on the total for a single particle. 
//		Track13Cn[i+1] 		= 1e3*Particle13C/TotalMass
//	endif





















































// ***************************************************************************
// **************** 			Ostwald Ripening
// ***************************************************************************

Function OstwaldRipening()

	InitializeKinetics()
	
	String AxisType = "Layers"
	
	Variable i, MixFlag, EndFlag, DebugFlag=0
	
	NVAR gCaAq 	= root:KINETICS:gCaAq
	
	String OldDF = getDataFolder(1)
	NewDataFolder /O/S root:KINETICS
	
		Variable NTPts = NumVarOrDefault("root:KINETICS:gNTPts",1000)
		Prompt NTPts, "# points for time axis (minutes)"
		Variable Temperature = NumVarOrDefault("root:KINETICS:gTemperature",295)
		Prompt Temperature, "Temperature (K)"
		Variable CaAqInit = NumVarOrDefault("root:KINETICS:gCaAqInit",gCaAq)	// Expt measurement was  42mg/L = 1.048 mM
		Prompt CaAqInit, "Initial calcium concentration (mM)"
		Variable MixTime = NumVarOrDefault("root:KINETICS:gMixTime",1000)
		Prompt MixTime, "Time step to start mixing"
		Variable ORCalc = NumVarOrDefault("root:KINETICS:gORCalc",1)
		Prompt ORCalc, "Calculation type", popup, "Particle distribution;Ostwald ripening;Ostwald ripening & Exchange;"
		
		DoPrompt "Ostwald ripening simulation", NTPts, Temperature, CaAqInit, MixTime, ORCalc
		if (V_flag)
			return 0
		endif
		
		Variable /G gNTPts 			= NTPts
		Variable /G gTemperature 	= Temperature
		Variable /G gCaAqInit 		= CaAqInit			// 1 mM is equivalent to 1 mole/m3
		Variable /G gMixTime 		= MixTime
		Variable /G gORCalc 		= ORCalc
		
		// This creates a distribution of actual particle number vs length in meters: 
		if (CalciteNumberDistribution(AxisType) == 0)
			return 0
		endif
		
		// -------------------------------------------------------
		// *** The starting particle distributions are XtalPDFLen and XtalPDFNum ****
		// -------------------------------------------------------
		//	XtalPDFNum vs XtalPDFLen is the UNITY normalized initialnumber distribution
		WAVE XtalPDFNum 			= root:KINETICS:XtalPDFNum
		WAVE XtalPDFLen 			= root:KINETICS:XtalPDFLen
		Variable n=1, NLPts = DimSize(XtalPDFLen,0)
		
		// Create other Particle Distribution Function properties
		Duplicate /O XtalPDFNum, XtalPDFVol, XtalPDFVo, XtalPDFMass, XtalPDFMo, XtalPDFArea, XtalPDFAo
		Duplicate /O XtalPDFNum, XtalPDFKsp, XtalPDF13CVol, XtalNumLen, temp0
		XtalPDF13CVol = 0
		
		NVAR gMineralConc 		= root:KINETICS:gMineralConc
		CalciteParticleDistributions(XtalPDFNum, XtalPDFLen,XtalPDFMass,XtalPDFVol,XtalPDFArea,XtalPDFVo,XtalPDFAo,XtalPDFMo,1,gMineralConc)
		
		// Calculate the size-dependence of the solubility product, Ksp
		ParticleKsp(XtalPDFKsp,XtalPDFLen)
		
		// These two approaches should give equal results: 
		Variable TotalMass 		= sum(XtalPDFMass)
		// Variable TotalMass 		= areaXY(XtalPDFLen,XtalPDFMass,0,NLPts-1)
		Print " 	*** Created a distribution of particles with total mass of",TotalMass,"kg/m3"
		Print " 			Surface area =",sum(XtalPDFArea)/(TotalMass*1000),"m2/g"
		
		if (ORCalc==1)
			return 0
		endif
		
		// Track the solution concentration of Ca (moles/m3)
		Make /O/D/N=(NTPts) CaAq=NaN
		CaAq[0] 	= CaAqInit
		
		
		// ------ These waves are relevant to Particle ARRAY method -------
		
			Variable UnitA 		= 0.45	// nm		<--- !!! Should use the global variable here !!!
			Variable NLayers 	= DimSize(XtalPDFLen,0)
			
			// The fundamental array for tracking particle size and13C concentration per layer. 
			// *** Definition of the CalciteArray: 
			Make /O/N=(NLayers,NLayers) CalciteArray=0
			
			// The number of particles with a given number of layers - FIXED 
			Make /O/D/N=(NLayers) CalciteNP
			CalciteNP[] 	= XtalPDFNum[p]
			
			// The Number of layers of each particle in a Calcite Array column - VARIES
			Make /O/D/N=(NLayers) CalciteNLayers
			CalciteNLayers[] 	= 1 + p
			
			// The Surface Area of a SINGLE particle with a given number of layers (m2) - FIXED
			Make /O/D/N=(NLayers) CalciteSA
			CalciteSA[] 		= 6 * (UnitA + (CalciteNLayers[p] -1) * 2 * UnitA) * (1e-9)^2
			
			// The Volume of a SINGLE layer as a function of layer number (m3) - FIXED
			Make /O/D/N=(NLayers) CalciteVol
			CalciteVol[] 	= CalciteSA[p] * UnitA * (1e-9)
			
			// The length of a side of each cubic particle in the Calcite array
			Make /O/D/N=(NLayers) CalciteLength
			CalciteLength[] 	= CalciteNLayers[p] * UnitA * (1e-9)
			
			// The length of a side of each cubic particle in the Calcite array - VARIES
			Make /O/D/N=(NLayers) CalciteKsp
			
			// The number of moles of 13C in a single particle 
			Make /O/D/N=(NLayers) Calcite13C = 0
			
		
		// -------------------------------------------------------
		
		// ------ These waves are relevant to Particle DISTRIBUTION method -------
			
			// Track the growth in the particle dimensions
			Make /O/D/N=(NTPts) MeanLen=NaN
			MeanLen[0] = MeanLength(XtalPDFLen,XtalPDFMass)
		
			// The initial particle concentration of 13C
			Make /O/D/N=(NTPts) C13Vol=0, C13Conc=0
			SetScale /P x, 0, 1, "minutes", C13Vol, C13Conc
			
			// Save the initial MASS scaled number distribution ... 
			// ... and make wave to re-interpolate the distributions back onto the original particle length axis
			Duplicate /O XtalPDFLen, XtalPDFLen_0, XtalPDFLen_dL
			Duplicate /O XtalPDFMass, XtalPDFMass_0, XtalPDFMass_dM, XtalPDFMass_Interp
			Duplicate /O XtalPDFNum, XtalPDFNum_0, XtalPDFNum_Interp
			// Save the mass distributions in a separate folder
			Duplicate /O XtalPDFMass, XtalPDFMass_0
			
			XtalPDFMass_dM 	= 0
			XtalPDFLen_dL 		= 0

			//  Keep track of the amount of 13C in the particles
			WAVE C13Conc		= root:KINETICS:C13Conc
			If (WaveExists(C13Conc))
				Duplicate /O C13Conc, C13ConcPrev
			endif
		// -------------------------------------------------------
		
		
		for (i=0;i<NTPts;i+=1)
			
			if (EndFlag)
				break
			elseif (mod(i,10000)==0)
				Duplicate /O XtalPDFMass, $("root:KINETICS:Ripening:XtalPDFMass_"+num2str(n))
				n += 1
			endif
			
			// Indicates whether atmosphere is introduced
			MixFlag = (i > MixTime) ? 1 : 0
			
			if (MixFlag && gORCalc==3)
//				ExchangeStep(i)
			endif
			
			strswitch(AxisType)
			case "Layers": 
//				EndFlag = RipeningStep2(i,MixFlag)
				break
			case "Logarithmic":
				EndFlag = RipeningStep(i,MixFlag)
				break
			endswitch
	
		endfor
		
		TotalMass 		= sum(XtalPDFMass)
//		TotalMass 		= areaXY(XtalPDFLen,XtalPDFMass,0,NLPts-1)
		Print " 			After ripening the total particle mass is",TotalMass,"kg/m3"
		Print " 			Surface area =",sum(XtalPDFArea)/(TotalMass*1000),"m2/g"
		
		CalciteEndRipening(i,C13Conc,CaAq,MeanLen)
		
	SetDataFolder $OldDF
End


Function CalciteEndRipening(i,C13Conc,CaAq,MeanLen)
	Wave C13Conc,CaAq,MeanLen
	Variable i
	
	Variable NDays 	= i/MinToDays
	
	Make /O/D/N=(NDays) C13ConcDays, CaAqDays, MeanLenDays
	SetScale /P x, 0, 1, "days", C13ConcDays, CaAqDays, MeanLenDays
	C13ConcDays[] 	= C13Conc[p*MinToDays]
	CaAqDays[] 	= CaAq[p*MinToDays]
	MeanLenDays[] = MeanLen[p*MinToDays]
	
End


// **************** 			A single Ostwald Ripening time point VERSION 1 - loop through the full distribution
Function RipeningStep(i,MixFlag)
	Variable i,MixFlag
	
	// Required Particle Distribution Functions
	WAVE XtalNum 		= root:KINETICS:XtalPDFNum
	WAVE XtalLen 		= root:KINETICS:XtalPDFLen
	WAVE XtalLen_0 	= root:KINETICS:XtalPDFLen_0
	WAVE XtalLen_dL 	= root:KINETICS:XtalPDFLen_dL
	WAVE XtalVol 		= root:KINETICS:XtalPDFVol
	WAVE XtalMass 		= root:KINETICS:XtalPDFMass
	WAVE XtalMass_dM 	= root:KINETICS:XtalPDFMass_dM
	WAVE XtalArea 		= root:KINETICS:XtalPDFArea
	WAVE XtalKsp 		= root:KINETICS:XtalPDFKsp
	WAVE Xtal13CVol 	= root:KINETICS:XtalPDF13CVol
	
	// Required Single-Particle properties
	WAVE XtalVo 		= root:KINETICS:XtalPDFVo
	WAVE XtalAo 		= root:KINETICS:XtalPDFAo
	WAVE XtalMo 		= root:KINETICS:XtalPDFMo
	
	// Required reaction constants
	NVAR gFW 			= root:KINETICS:gFW
	NVAR gIFE 			= root:KINETICS:gIFE
	NVAR gkDiss		= root:KINETICS:gkDiss
	NVAR gMolVol 		= root:KINETICS:gMolarVolume
	
	NVAR gCO32Aq 		=  root:KINETICS:gCO32Aq
//	NVAR gCaCO3aq 		= root:KINETICS:gCaCO3aq
	NVAR g13CAq 		= root:KINETICS:g13CAq
	
	// Waves tracking the change in solution and particle composition
	WAVE CaAq 			= root:KINETICS:CaAq
	WAVE C13Vol 		= root:KINETICS:C13Vol
	WAVE C13Conc 		= root:KINETICS:C13Conc
	WAVE MeanLen 		= root:KINETICS:MeanLen
	
	Variable NLPts=DimSize(XtalNum,0)
	
	Variable IAP, Omega, mm=1, nn=1, dd=0
	Variable NegligibleChange, EndFlag = 0, EndConc = 5000000
	Variable j, Len,Vo,Vol, NewLen, Moles, Moles_d, dMass, dVol, NewVo,NewVol, dCaAq=0
	
	// Calculate the IAP of the solution (in moles/L)
	IAP 	= CaAq[i] * gCO32Aq * 1e-6
	
	// Loop through all the particle sizes
	for (j=0;j<NLPts;j+=1)
		
		Len 	= XtalLen[j]
		Vo 		= XtalVo[j]
		Vol 		= XtalVol[j]
		Moles 	= XtalVol[j]/gMolVol
		
		if ((XtalLen[j] == 0) || (XtalMass[j] == 0))
			// Do nothing ... 
		else
			
			// Calculate the saturation state of the solution with respect to a certain particle size
			Omega 		= IAP/XtalKsp[j]
			
			// The number of moles lost from or added to the total surface area of this particle size (negative means dissolution)
			// Conceivably could adjust the expression to (Omega^m - 1)^n
			Moles_d	= XtalArea[j] * gkDiss * (Omega - 1)
			
			if ((sign(Moles_d) < 0) && (abs(Moles_d) >= Moles))			// Complete dissolution - does this ever happen? 
				Moles_d	= sign(Moles_d) * Moles
				
				XtalLen[j]	= 0
				XtalNum[j] 	= 0
				dd += 1
			else																	// Particle dissolution or growth
				// Calculate the change in total volume
				dVol 	= Moles_d * gMolVol
				NewVol 	= (XtalVol[j] + dVol)
				
				// ... new volume of a single particle ...
				NewVo 	= NewVol/XtalNum[j]
				
				// ... and the new length of a single particle
				NewLen = (NewVo)^(1/3)
				
				// Update the Particle Length value
				XtalLen[j] 	= NewLen
			endif
			
			// Make a record of how particle dimensions change at each step
			XtalMass_dM[j] += Moles_d * gFW
			XtalLen_dL[j] = NewLen - XtalLen_0[j]
			
			// Account for the Ca released or taken from the solution, changing the aqueous calcium concentration
			dCaAq		-=  Moles_d	// moles per m3 = mM
			
			if (MixFlag)
				if (Moles_d < 0)	
					// DISSOLUTION preferentially removes part or all of the particle volume with 13C
					Xtal13CVol[j] 	= max(Xtal13CVol[j]-abs(dVol),0)
				else	
					// GROWTH from solution adds a mixture of 13C:12C. 
					Xtal13CVol[j] += abs(dVol)
				endif
			endif
					
		endif
	endfor
	
	// Update the solution concentration of Ca in solution (moles per m3 = mM)
	CaAq[i+1] 	= CaAq[i] + dCaAq
	
	// Update the average particle dimensions
	MeanLen[i] = MeanLength(XtalLen,XtalMass)
	
	if (MixFlag)
		// The total amount of 13C in the particles
		C13Vol[i+1] 		= sum(Xtal13CVol)
		
		// The stoichiometric fraction of 13C:12C expressed as µmol 13C/g calcite
		// Note that 1g of calcite contains 10,000 µmoles of carbon
		C13Conc[i+1] 		= (1000) * (g13CAq/gFW) * (sum(Xtal13CVol)/ sum(XtalVol)) // 
		
		if (C13Conc[i+1] > EndConc)
			EndFlag = 1
		endif
	endif	

	// Re-interpolate the shifted particle distributions back onto the original length axis
	CalciteParticleInterpolate(XtalNum,XtalLen,XtalLen_0,XtalMass)
	
	// Update the particle distribution
	CalciteParticleDistributions(XtalNum,XtalLen,XtalMass,XtalVol,XtalArea,XtalVo,XtalAo,XtalMo,0,-1)
	
	// The size-dependent Ksp does not change. 
	
	return EndFlag
End


// After each Ripening step we have changed the Length and Volume. The Number should not have changed, unless there was complete dissolution
// Re-interpolate the P(number) vs Length distribution back onto a standard axis, XtalPDFLen_0

Function CalciteParticleInterpolate(XtalNum,XtalLen,XtalLen_0,XtalMass)
	Wave XtalNum,XtalLen,XtalLen_0,XtalMass
		
	NVAR gDensity 			= root:KINETICS:gDensity
	
	WAVE XtalNum_Interp 	= root:KINETICS:XtalPDFNum_Interp
	WAVE XtalMass_Interp 	= root:KINETICS:XtalPDFMass_Interp
	
	// This step should not increase the total mass! 
	Variable TotalMass, TotalMass_Interp, NLPts=DimSize(XtalLen,0)
	
	TotalMass 			= sum(XtalMass)
//	TotalMass 			= areaXY(XtalLen,XtalMass,0,NLPts-1)
	
	// Interpolate2			{-----destination waves----}   {-----input  waves----}
	Interpolate2 /T=1/I=3/X=XtalLen_0/Y=XtalNum_Interp XtalLen, XtalNum
	
	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
	
	TotalMass_Interp 	= sum(XtalMass_Interp)
//	TotalMass_Interp 	= areaXY(XtalLen_0,XtalMass_Interp,0,NLPts-1)
	
	XtalNum_Interp *= (TotalMass/TotalMass_Interp)
	
	XtalMass_Interp[] 	= XtalNum_Interp[p] * XtalLen_0[p]^3 * gDensity
	
	TotalMass_Interp 	= sum(XtalMass_Interp)
//	TotalMass_Interp 	= areaXY(XtalLen_0,XtalMass_Interp,0,NLPts-1)
	
	// The re-interpolated distributions
	XtalLen 				= XtalLen_0
	XtalNum 			= XtalNum_Interp
	
End


Function Calcite2TFit(w,point) : FitFunc
	Wave w
	Variable point
	
	WAVE timeaxis 	= C13_21C_50C_axis
	Variable tt 		= timeaxis[point]
	
	Variable Indx50C = 26
	Variable Cmax 	= w[0]
	Variable k 	= w[2]
	
	if (point < Indx50C)
		k = w[1]
	endif
	
	return Cmax * (1 - exp(-k * tt))
	
End



			// Either we update the solution concentration of Ca per size step ... 
	//		dMol 	= -1 * XtalArea[j] * gkDiss * (1 -  (CaAq[i]+dCaCO3)/XtalSolb[j])	
			// ... or per time step ... 	
//			Moles_d 	= -1 * XtalArea[j] * gkDiss * (1 -  CaAq[i]/XtalSolb[j])
	
	
//// *** Expression for Relative Solubility vs Length
//// 		Iggland & Mazzotti Cryst. Growth Design (2012)
//
//// Input: BulkSolubility in moles per m3
//// Input: Length in m
//// Input: Surface energy in J/m2
//// Input: Molar volume in m3 per mole
//// Input: Temperature in K
//
//// Output: ParticleSolubility in moles per m3
//
//Function ParticleSolubility(Length,BulkSolubility, IFE, MolarVol, T)
//	Variable Length, BulkSolubility, IFE, MolarVol, T
//	
//	Variable alpha 		= (4*IFE*MolarVol)/(T*cR)
//	
//	// Insanely high solubilities are predicted below 10 nm. 
//	Length 	= max(Length,2e-9)
//		
//	return exp(alpha/Length) * BulkSolubility
//End
//
//Function CalciteSolubility(XtalSolb,XtalLen)
//	Wave XtalSolb,XtalLen
//
//	NVAR gTemperature = root:KINETICS:gTemperature
//	NVAR gIFE 			= root:KINETICS:gIFE
//	NVAR gKsp 			= root:KINETICS:gKsp
//	NVAR gMolVol 		= root:KINETICS:gMolarVolume
//	
//	// Convert from the bulk Ksp to the equilibrium concentration of Ca in the solution
//	
//	// !*! But I don't have a good geochemistry code here, so use Andrew's value
//	
//	Variable CaAq 	= 0.492 	// moles/m2 converted from 0.492 mM
//	
//	XtalSolb[] 	= ParticleSolubility(XtalLen[p], CaAq, gIFE, gMolVol, gTemperature)
//	
//End





















// ***************************************************************************
// **************** 			Analysis of TR-XAS data
// ***************************************************************************

Function FerrousSurfaceRate(w,t)
	Wave w
	Variable t

	if (t > 0)
		return w[0] * exp(-t*(w[1] + w[2]))
	else
		return nan
	endif
End

Function FerrousInteriorRate(w,t)
	Wave w
	Variable t

	Variable prefactor = w[2]/(w[1] + w[2])
	
	if (t > 0)
		return w[0] * prefactor * (1 - exp(-t*(w[1] + w[2])))
	else
		return nan
	endif
End

Function FerrousTotalRate(w,t) :FitFunc
	Wave w				// w[0] = initial total ferrous concentration
	Variable t			// w[1] = k1, the rate of recombination
						// w[2] = k2, the rate of transfer into the interior
						
	Variable Fsurf, prefactor, Fint, Ftot	

	Fsurf 	= w[0] * exp(-t*(w[1] + w[2]))
	
	prefactor 	= w[2]/(w[1] + w[2])
	Fint 		= w[0] * prefactor * (1 - exp(-t*(w[1] + w[2])))

	Ftot 	= Fsurf + Fint

	return Ftot
End


//******************************************************************
//******* 				REACTION KINETICS RATE LAWS
//******************************************************************

// Here are some kinetics rate laws taken from:
//
//		H. Zhang & J. F. Banfield. 
//		American Mineralogist, Volume 84, pages 528Ð535, 1999
//
//		Further citations are given with each expression. 

//	STANDARD FIRST ORDER
//	Rao, 1961; Suzuki & Kotera, 1962. 
Function FirstOrderKinetics(w,t) :FitFunc
	Wave w
	Variable t
	
	Variable k = w[3]
	
	Variable dt = w[4]
	
	Variable alpha = 1 - exp(-k*(t-w[4]))
	
//	return alpha * (w[1] - w[0]) + w[0]
	return w[0] + w[1]*alpha
End

//	STANDARD SECOND ORDER
//	Czanderna et al., 1958
Function SecondOrderKinetics(w,t) :FitFunc
	Wave w
	Variable t
	
	Variable k = w[3]
	
	Variable dt = w[4]
	
	Variable alpha = 1 - 1/(k*(t-w[4]))
	
	return alpha * (w[1] - w[0]) + w[0]
End

// ********************************************************
// ******     			JMAK Kinetics fits
// ********************************************************

// NOTE: To convert kcal to joules, multiply kcal x 4190

Function JMAKKinetics(w,t) :FitFunc
	Wave w
	Variable t
	
	Variable n = max(0,min(4,w[2]))
	w[2]= n

	Variable k = w[3]
	
	Variable dt = w[4]
	
	Variable alpha = 1 - exp(-(k*(t-w[4]))^n)
	
	return alpha * (w[1] - w[0]) + w[0]
End

Proc JMAKKineticsCoefs(ctrlName) : ButtonControl
	String ctrlName
	PauseUpdate; Silent 1
	
	JMAKKineticsProc("CoefficientKinetics", "Coef_Kinetics")
End


Proc JMAKKineticsViewer(ctrlName) : ButtonControl
	String ctrlName
	PauseUpdate; Silent 1
	
	JMAKKineticsProc(gYData, "DataViewerPlot")
End
	
Proc JMAKKineticsProc(aVar, WindowName)
	String aVar, WindowName
	PauseUpdate; Silent 1

	if (exists("JMAKCoefs")==0)
		Variable gholdAoFlag=1, gholdAfFlag=1, gholdNFlag=1, gholdtOffsetFlag=1
		Make /O/D/N=5 JMAKCoefs
		JMAKCoefs[0] = $aVar[0]
		JMAKCoefs[1] = $aVar[BIG]
		JMAKCoefs[2] = 1
		JMAKCoefs[3] = 1
		JMAKCoefs[4] = 0
	
		Cursor A, $aVar, leftx($aVar)
		Cursor B, $aVar, rightx($aVar)
	endif
	if (exists("JMAKLegend")==0)
		Make /T/N=5 JMAKLegend
		JMAKLegend[0] = "Initial"
		JMAKLegend[1] = "Final"
		JMAKLegend[2] = "n"
		JMAKLegend[3] = "k"
		JMAKLegend[4] = "t offset"
		
//		Edit/W=(5,44,197,201) JMAKCoefs
		DisplayCoefficientsTable("JMAKCoefsTable","JMAK coefficients","JMAKLegend;JMAKCoefs;","_auto_;", "2;2;", 5,44,240,201,"yes")
	else
		DisplayCoefficientsTable("JMAKCoefsTable","JMAK coefficients","JMAKLegend;JMAKCoefs;","_auto_;", "2;2;", 5,44,240,201,"yes")
		RealKineticsFitCoefs(,,,,,,,,aVar,WindowName)
	endif
End

Proc RealKineticsFitCoefs(Ao,holdAoFlag,N,holdNFlag, Af,holdAfFlag,tOffset,holdtOffsetFlag,aVar,WindowName)
	Variable /G gholdAoFlag, gholdAfFlag, gholdNFlag, gholdtOffsetFlag
	//
	Variable Ao = JMAKCoefs[0]
	Prompt Ao, "The initial value"
	Variable holdAoFlag = gholdAoFlag
	Prompt holdAoFlag, "Fix initial value?", popup, "no;yes;"
	//
	Variable N = JMAKCoefs[2]
	Prompt N, "The dimensional coefficient, n"
	Variable holdNFlag = gholdNFlag
	Prompt holdNFlag, "Fix n?", popup, "no;yes;"
	//
	Variable Af = JMAKCoefs[1]
	Prompt Af, "The final value"
	Variable holdAfFlag = gholdAfFlag
	Prompt holdAfFlag, "Fix final value?", popup, "no;yes;"
	//
	Variable tOffset = JMAKCoefs[4]
	Prompt tOffset, "The initial time offset"
	Variable holdtOffsetFlag = gholdtOffsetFlag
	Prompt holdtOffsetFlag, "Fix the time offset?", popup, "no;yes;"
	//
	String aVar,WindowName
	
	JMAKCoefs[0] = Ao
	JMAKCoefs[1] = Af
	JMAKCoefs[2] = N
	JMAKCoefs[4] = tOffset
	
	gholdAoFlag=holdAoFlag
	gholdAfFlag=holdAfFlag
	gholdNFlag=holdNFlag
	gholdtOffsetFlag=holdtOffsetFlag
	
	String holdString =num2str(holdAoFlag-1)
	holdString +=num2str(holdAfFlag-1)
	holdString +=num2str(holdNFlag-1)
	holdString += "0"
	holdString +=num2str(holdtOffsetFlag-1)
	
	if ((holdtOffsetFlag == 1) && (JMAKCoefs[4] < 1e-10))
		JMAKCoefs[4] = -0.1
	endif
	
	if (numtype(Xcsr(A)) != 0)
		Cursor /W=$WindowName A, $aVar, leftx($aVar)
	endif
	if (numtype(Xcsr(B)) != 1)
		Cursor /W=$WindowName B, $aVar, rightx($aVar)
	endif
	
	if (numpnts($aVar) != numpnts(XWaveRefFromTrace(WindowName, aVar)))
		DoAlert 0, "The axis and data don't have the same number of points! Aborting. "
		return -1
	endif
		
	Duplicate /O/D $aVar, JMAKFit
	Duplicate /O/D JMAKCoefs, JMAKCoefs_save
	
	Variable V_FitQuitReason=0, V_FitError=0
	
	FuncFit /Q/H=holdString JMAKKinetics JMAKCoefs $aVar[pcsr(A),pcsr(B)] /X=XWaveRefFromTrace(WindowName, aVar) /D=JMAKFit
	
	if (V_FitError != 0)
		Print " *** A fitting error! Try holding all the variables. "
		gholdAoFlag=2
		gholdAfFlag=2
		gholdNFlag=2
		gholdtOffsetFlag=2
	
		JMAKCoefs = JMAKCoefs_save
	else
		Print " *** JMAK Fit to", aVar ,"completed sucessfuly. "
	endif
	KillWaves /Z JMAKCoefs_save

	RemoveFromGraph /W=$WindowName/Z JMAKFit
	AppendToGraph /W=$WindowName JMAKFit vs XWaveRefFromTrace(WindowName, aVar)
	ModifyGraph /W=$WindowName rgb(JMAKFit)=(3,52428,1)
End

