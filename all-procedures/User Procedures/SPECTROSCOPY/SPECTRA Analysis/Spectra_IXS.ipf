#pragma rtGlobals=3		// Use modern global access method and strict wave access.


// http://www.coolprop.org/fluid_properties/fluids/CarbonDioxide.html#fluid-carbondioxide
// 	https://ibell.pythonanywhere.com/


// r is the specific refraction at a wavelength of 670 nm and is given by 1.51 × 10−4 m3 kg−1
Function RI_CO2(Rho)
	Variable Rho
	
	Variable rr 	= 1.51e-4
	
	// Classic Lorentz–Lorenz equation
	Variable RI 	= (2*rr*Rho+1)/(1 - rr*Rho)
	
	return RI
End

// For SSRL IXS, q = 0.27, so q^2 =  0.0729
//	Variable qq = 0.0729

// *** Use the Input Data Axis for all subsequent operations until the Hilbert Transform

Function InitEpsilonfromIXS()

	String OldDF = getDataFolder(1)
	NewDataFolder/O root:SPECTRA
	NewDataFolder/O/S root:SPECTRA:Fitting
	NewDataFolder/O/S root:SPECTRA:Fitting:IXSe
		
		// The list of data that can be plotted and fitted
		MakeVariableIfNeeded("root:SPECTRA:Fitting:IXSe:gNData",1)
		NVAR gNData	= root:SPECTRA:Fitting:IXSe:gNData
		
		// This command actually creates the wFitData and other waves
		gNData 	= SelectedDataList(0,1,"wFitData","root:SPECTRA:Fitting:IXSe","")
		if (gNData<2)
			SetDataFolder $(OldDF)
			return 0
		endif
		
		WAVE selWave 	= root:SPECTRA:Fitting:IXSe:wFitDataSel
		selWave = 0
		
		WAVE /D IXSEcoefs 	= root:SPECTRA:Fitting:IXSe:IXSEcoefs
		if (WaveExists(IXSEcoefs) == 0)
			Make /O/D/N=5 root:SPECTRA:Fitting:IXSe:IXSEcoefs={0.0,0.0046,0.131,0.09,1.54}
			IXS1CoefsToList()
		endif
		
		WAVE /D IXSMScoefs 	= root:SPECTRA:Fitting:IXSe:IXSMScoefs
		if (WaveExists(IXSMScoefs) == 0)
			Make /O/D/N=4 root:SPECTRA:Fitting:IXSe:IXSMScoefs={10,3,10,1}
			IXS1MSCoefsToList()
		endif

		WAVE /D IXSTcoefs 	= root:SPECTRA:Fitting:IXSe:IXSTcoefs
		if (WaveExists(IXSTcoefs) == 0)
			Make /O/D/N=3 root:SPECTRA:Fitting:IXSe:IXSTcoefs={0.0,1,-1}
			IXS2CoefsToList()
		endif
		
		// The ListBox waves for manually entering Elastic Peak coefficient values
		if (!WaveExists(root:SPECTRA:Fitting:IXSe:EcoefsSel))
			Make /O/D/N=(5,3) EcoefsSel=0
			Make /O/T/N=(5,3) EcoefsList=""
			SetDimLabel 1, 0, $"\\f01Legend", EcoefsList
			SetDimLabel 1, 1, $"\\f01Values", EcoefsList
			SetDimLabel 1, 2, $"\\f01Hold", EcoefsList
			
			// Allow the coefficient column to be editable. 
			EcoefsSel[][1] 	= BitSet(EcoefsSel[p][1],1)
			// Check boxes to hold all coefficients. 
			EcoefsSel[][2]	= BitSet(EcoefsSel[p][2],5)
			
			EcoefsList[0][0] 	= "Offset"
			EcoefsList[1][0] 	= "A1"
			EcoefsList[2][0] 	= "tau 1"
			EcoefsList[3][0] 	= "A2"
			EcoefsList[4][0] 	= "tau 2"
		endif
		
		// The ListBox waves for manually entering Multiple Scattering coefficient values
		if (!WaveExists(root:SPECTRA:Fitting:IXSe:MScoefsSel))
			Make /O/D/N=(4,3) MScoefsSel=0
			Make /O/T/N=(4,3) MScoefsList=""
			SetDimLabel 1, 0, $"\\f01Legend", MScoefsList
			SetDimLabel 1, 1, $"\\f01Values", MScoefsList
			SetDimLabel 1, 2, $"\\f01Hold", MScoefsList
			
			// Allow the coefficient column to be editable. 
			MScoefsSel[][1] 	= BitSet(MScoefsSel[p][1],1)
			// Check boxes to hold all coefficients. 
			MScoefsSel[][2]	= BitSet(MScoefsSel[p][2],5)
			
			MScoefsList[0][0] 	= "Scale"
			MScoefsList[1][0] 	= "Width"
			MScoefsList[2][0] 	= "Shift"
			MScoefsList[3][0] 	= "Asymm"
		endif
		
		// The ListBox waves for manually entering Power-Law Tail coefficient values
		if (!WaveExists(root:SPECTRA:Fitting:IXSe:TcoefsSel))
			Make /O/D/N=(3,3) TcoefsSel=0
			Make /O/T/N=(3,3) TcoefsList=""
			SetDimLabel 1, 0, $"\\f01Legend", TcoefsList
			SetDimLabel 1, 1, $"\\f01Values", TcoefsList
			SetDimLabel 1, 2, $"\\f01Hold", TcoefsList
			
			// Allow the coefficient column to be editable. 
			TcoefsSel[][1] 	= BitSet(TcoefsSel[p][1],1)
			// Check boxes to hold all coefficients. 
			TcoefsSel[][2]	= BitSet(TcoefsSel[p][2],5)
			
			TcoefsList[0][0] 	= "Offset"
			TcoefsList[1][0] 	= "Intensity"
			TcoefsList[2][0] 	= "Exponent"
		endif
		
	SetDataFolder $(OldDF)
End


Function PlotEpsilonfromIXS()

	DoWindow/K IXSePanel
	NewPanel /K=1/W=(196,65,993,1022) as "Dielectric Function from Small-Angle Inelastic X-ray Scattering"
	DoWindow/C IXSePanel
	CheckWindowPosition("IXSePanel",196,65,993,1022)
	
	SetWindow IXSePanel, hook(IXSeHook)=IXSePanelHooks
	
	Variable /G gTabChoice = 0
	TabControl IXSePanelTab pos={5,5},size={785,290}
	TabControl IXSePanelTab,tabLabel(0)="Data", tabLabel(1)="Low E"
	TabControl IXSePanelTab,tabLabel(2)="High E",tabLabel(3)="OOS", tabLabel(4)="ε(E)"
	TabControl IXSePanelTab, proc=IXSePanelTabAction,value= gTabChoice
	
	// The List of the spectra
	ListBox IXSDataListBox pos={40,100},size={230,155}
	ListBox IXSDataListBox,mode= 4, proc=SelectIXSDataToPlot
	ListBox IXSDataListBox,listWave=root:SPECTRA:Fitting:IXSe:wFitDataList
	ListBox IXSDataListBox,selWave=root:SPECTRA:Fitting:IXSe:wFitDataSel
	
	Button IXSDuplicateButton,pos={15,268},size={80,20},proc=IXSButtonAction,title="Duplicate"
	Button IXSRemoveButton,pos={100,268},size={80,20},proc=IXSButtonAction,title="Remove"

	// ****		TAB 0:	Select and scale Data and Background
	IXSeTab0Items()
	SelectIXSDataOrBack(1,0)
	SelectIXSDataOrBack(0,1)
	IXSeTab0Plots()

	// ****		TAB 1:	Fit the Elastic Peak
	IXSeTab1Items()
	IXSeTab1Plots()

	// ****		TAB 2:	Fit the Power-law Tail
	IXSeTab2Items()
	IXSeTab2Plots()
	
	// ****		TAB 3:	Normalize the Oscillator Strength
	IXSeTab3Items()
	IXSeTab3Plots()
	
	// ****		TAB 4:	Calculate the Dielectric Function
	IXSeTab4Items()
	IXSeTab4Plots()
	
	DoUpdate
	
	// By Default, choose the first Tab ... 
	IXSePanelTabDisplay("IXSePanel",0)
End


Function SelectIXSDataToPlot(lb) : ListboxControl
	STRUCT WMListboxAction &lb
	
	WAVE Group 	= root:SPECTRA:Fitting:IXSe:wFitDataGroup
	WAVE Sel 		= root:SPECTRA:Fitting:IXSe:wFitDataSel
	
	Variable i, NData = DimSize(lb.selWave,0)
	
	ControlInfo /W=IXSePanel IXSePanelTab
	String PlotName = "IXSePanel#Tab"+num2str(V_value)+"Plot"
	
	if ((lb.eventCode==4) || (lb.eventCode==5))
		for (i=0;i<NData;i+=1)
			String SpectrumName = lb.listWave[i]
			String DataAndFolderName = "root:SPECTRA:Data:Load"+num2str(Group[i])+":"+lb.listWave[i]
// 			if (i != lb.row) 	// This is ELEGANT as it uses lb.row to choose a single trace to display. 
			if (Sel[i] == 0)	// ... however, this does not allow multiple selections. 
				RemoveFromGraph /Z/W=$PlotName $lb.listWave[i]
			else
				CheckDisplayed /W=$PlotName $DataAndFolderName
				if (!V_flag)
					AppendToGraph /W=$PlotName $DataAndFolderName vs $ReplaceString("_data",DataAndFolderName,"_axis")
					ModifyGraph /W=$PlotName lsize($SpectrumName)=1.5,rgb($SpectrumName)=(26214,26212,0)
				endif
			endif
		endfor
	endif
	
	return 0
End

// Display or remove duplicates of the processed data for the relevant tab
Function IXSButtonAction(bs) : ButtonControl
	STRUCT WMButtonAction &bs
	
	if(bs.eventCode==2)	// Mouse up
		
		ControlInfo /W=IXSePanel IXSePanelTab
		String PlotName = "IXSePanel#Tab"+num2str(V_value)+"Plot"
		
		Variable DRFlag = (cmpstr(bs.CtrlName,"IXSDuplicateButton") == 0) ? 1 : 0
		
		switch (V_value)
			case 0:
				IXSDuplicates(PlotName,"IXS0",$"root:SPECTRA:Fitting:IXSe:IXS0_Data3",$"root:SPECTRA:Fitting:IXSe:IXS0_DataAxis",DRFlag)
				break
			case 1: 
				IXSDuplicates(PlotName,"IXS1",$"root:SPECTRA:Fitting:IXSe:IXS0_Data4",$"root:SPECTRA:Fitting:IXSe:IXS0_DataAxis",DRFlag)
				break
			case 2: 
				IXSDuplicates(PlotName,"IXS2",$"root:SPECTRA:Fitting:IXSe:IXS2_Data5",$"root:SPECTRA:Fitting:IXSe:IXS2_Axis2",DRFlag)
				break
			case 3: 
				IXSDuplicates(PlotName,"IXS3",$"root:SPECTRA:Fitting:IXSe:IXS3_OOS",$"null",DRFlag)
				break
			case 4: 
				IXSDuplicates(PlotName,"IXS41",$"root:SPECTRA:Fitting:IXSe:IXS4_e1",$"null",DRFlag)
				IXSDuplicates(PlotName,"IXS42",$"root:SPECTRA:Fitting:IXSe:IXS4_e2",$"null",DRFlag)
				break
			default:
				WAVE Spectrum = $"null"
				WAVE Axis = $"null"
		endswitch
	endif
	return 0
End

Function IXSDuplicates(PlotName,DRName,spectrum,axis,DRFlag)
	String PlotName, DRName
	Wave spectrum,axis
	Variable DRFlag
	
	// CheckDisplayed uses waves not traces	
	CheckDisplayed /W=$PlotName $("root:SPECTRA:Fitting:IXSe:"+DRName)
	
	if (DRFlag)
		Duplicate/O spectrum, $("root:SPECTRA:Fitting:IXSe:"+DRName)/Wave=dupspec
		if (WaveExists(axis))
			Duplicate/O axis, $("root:SPECTRA:Fitting:IXSe:"+DRName+"a")/Wave=dupaxis
			if (!V_flag)
				AppendToGraph /W=$PlotName dupspec vs dupaxis
				ModifyGraph /W=$PlotName lstyle($DRName)=2,rgb($DRName)=(26214,26214,26214)
			endif
		else
			if (!V_flag)
				AppendToGraph /W=$PlotName dupspec
				ModifyGraph /W=$PlotName lstyle($DRName)=2,rgb($DRName)=(26214,26214,26214)
			endif
		endif
	else
		if (V_flag)
			RemoveFromGraph /W=$PlotName $DRName
		endif
	endif
End

Function IXSePanelTabAction(tc) : TabControl
	STRUCT WMTabControlAction &tc
	
	if(tc.eventCode == 2) // Mouse up
			IXSePanelTabDisplay(tc.win,tc.tab)
	endif
	return 0
End

// The display of Tab Controls and Plots
Function IXSePanelTabDisplay(WName,tab)
	String WName
	Variable tab
	
	String ControlList, PlotList, PlotName
	Variable i, j, HostTab, NControls, NPlots, DisableFlag
	Variable NTabs=5
	
	for (i=0;i<NTabs;i+=1) 	// Loop through the Tabs
	
		// All the controls in this Tab
		DisableFlag 	= (tab == i) ? 0 : 1
		ControlList 	= ControlNameList(WName,";","IXSeT"+num2str(i)+"*")
		ModifyControlList ControlList, win=$WName, disable=DisableFlag
		
		// All the plots in this Tab
		PlotList 		= InclusiveWaveList(ChildWindowList(WName),"Tab"+num2str(i),";")
		NPlots 		= ITemsInList(PlotList)
		for (j=0;j<NPlots;j+=1)
			PlotName 	= StringFromList(j,PlotList)
			SetWindow $("IXSePanel#"+PlotName) hide=DisableFlag, needUpdate=1
		endfor
		
		// Run the Data Processing Function of this and all later Tabs
		if (i>=tab)
			FUNCREF IXSCorrection f= $("IXSCorrection"+num2str(i))
			f()
		endif
		
	endfor
End

// ************************************************************************************************
// *******	Tab 0 - Data and Background Correction and Subtraction

Function SelectIXSDataOrBack(DataFlag,row)
	Variable DataFlag,row

	WAVE wGroup 	= root:SPECTRA:Fitting:IXSe:wFitDataGroup
	WAVE /T wList = root:SPECTRA:Fitting:IXSe:wFitDataList
	
	WAVE Spectrum = $("root:SPECTRA:Data:Load"+num2str(wGroup[row])+":"+wList[row])
	WAVE Axis = $("root:SPECTRA:Data:Load"+num2str(wGroup[row])+":"+ReplaceString("_data",wList[row],"_axis"))
		
	if (DataFlag)
		Duplicate /O Spectrum, root:SPECTRA:Fitting:IXSe:IXS0_Data
		Duplicate /O Axis, root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
		Note root:SPECTRA:Fitting:IXSe:IXS0_Data, "The input spectrum is "+NameOfWave(Spectrum)
	else
		Duplicate /O Spectrum, root:SPECTRA:Fitting:IXSe:IXS0_Back
		Duplicate /O Axis, root:SPECTRA:Fitting:IXSe:IXS0_BackAxis
		Note root:SPECTRA:Fitting:IXSe:IXS0_Back, "The input spectrum is "+NameOfWave(Spectrum)
	endif
	
	IXSArray0()
	IXSCorrection0()
End

// This has to happen every time the data or background selection is changed. 
// *!*! 2018-12-23 I think I need to create more waves here. 
Function IXSArray0()
	
	WAVE Data 		= root:SPECTRA:Fitting:IXSe:IXS0_Data
	WAVE DataAxis	= root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	WAVE Back 		= root:SPECTRA:Fitting:IXSe:IXS0_Back
	WAVE BackAxis	= root:SPECTRA:Fitting:IXSe:IXS0_BackAxis
	
	//Interpolate the background onto the data axis
	Duplicate /O DataAxis, root:SPECTRA:Fitting:IXSe:IXS0_Back1//, root:SPECTRA:Fitting:IXSe:IXS0_BackAxis1
	WAVE Back1 = root:SPECTRA:Fitting:IXSe:IXS0_Back1
	
	Interpolate2 /T=1/I=3/X=DataAxis/Y=Back1 BackAxis, Back
	
	// The data and background scaled by Transmission values. These are the PLOTTED waves
	Duplicate /O Data, root:SPECTRA:Fitting:IXSe:IXS0_Data2
	Duplicate /O Back1, root:SPECTRA:Fitting:IXSe:IXS0_Back2
	
	// This is the data minus the background
	Duplicate /O Data, root:SPECTRA:Fitting:IXSe:IXS0_Data3

	// *** The input waves for this Tab processing routines
	WAVE Data3 = root:SPECTRA:Fitting:IXSe:IXS0_Data3
	WAVE Axis = root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	
	// *** Make the necessary waves here
	Duplicate /O/D Data3, root:SPECTRA:Fitting:IXSe:IXS0_Data4, root:SPECTRA:Fitting:IXSe:IXS1_Elastic
	WAVE Data4 = root:SPECTRA:Fitting:IXSe:IXS0_Data4
	WAVE Elastic = root:SPECTRA:Fitting:IXSe:IXS1_Elastic
	
End

Function IXSCorrection()
	Print "Must be an error in function calling"
End

// This has to happen every time the data or background selection is changed OR the global variables are changed
Function IXSCorrection0()

	NVAR gIXSeSampleT 	= root:SPECTRA:Fitting:IXSe:gIXSeSampleT
	NVAR gIXSeBackT 		= root:SPECTRA:Fitting:IXSe:gIXSeBackT
	
	WAVE Data 			= root:SPECTRA:Fitting:IXSe:IXS0_Data
	WAVE Data2 		= root:SPECTRA:Fitting:IXSe:IXS0_Data2
	WAVE Data3 		= root:SPECTRA:Fitting:IXSe:IXS0_Data3
	WAVE Back1 		= root:SPECTRA:Fitting:IXSe:IXS0_Back1
	WAVE Back2 		= root:SPECTRA:Fitting:IXSe:IXS0_Back2
	
	Variable Corr1 = gIXSeSampleT
	Variable Corr2 = gIXSeSampleT*gIXSeBackT
	
	Data2 	= Data
	Back2 	= Back1 * Corr1
//	Data3 	= (Data2 - Back2)/Corr2
	Data3 	= (Data2 - Back2)
End

Function IXSeTab0Plots()
	
	IXSArray0()
	IXSCorrection0()

	Display/W=(11,304,784,946)/HOST=# root:SPECTRA:Fitting:IXSe:IXS0_Data2 vs root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
		AppendToGraph root:SPECTRA:Fitting:IXSe:IXS0_Back2, root:SPECTRA:Fitting:IXSe:IXS0_Data3 vs root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
		ModifyGraph rgb(IXS0_Back2)=(3,52428,1), rgb(IXS0_Data3)=(0,0,0)
		ModifyGraph mirror=2, lowTrip(left)=0.01
		SetAxis/A/E=1 left
		Legend/C/N=text0/J/F=0/A=RT/X=6.60/Y=7.32 "\\s(IXS0_Data2) Data\r\\s(IXS0_Back2) Background\r\r\\s(IXS0_Data3) Difference"
		Label left "Raw Spectrum Intensity"
		Label bottom "Energy (eV)"
		RenameWindow #, Tab0Plot
	SetActiveSubwindow ##
End

Function IXSeTab0Items()
	
	Button IXSeT0_SelectDataButton,pos={40,45},size={115,20},proc=SelectIXSAction,title="Select data"
	Button IXSeT0_SelectBackButton,pos={40,72},size={160,20},proc=SelectIXSAction,title="Select background"
	
	GroupBox IXSeT0_Group1,pos={300,35},size={300,150},fSize=12,fColor=(39321,1,1),title="Subtract the background"

	// Sample and container transmissions
	NVAR gIXSeSampleT = root:SPECTRA:Fitting:IXSe:gIXSeSampleT
	if (!NVar_Exists(gIXSeSampleT))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeSampleT 	= 1
	endif
	NVAR gIXSeBackT = root:SPECTRA:Fitting:IXSe:gIXSeBackT
	if (!NVar_Exists(gIXSeBackT))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeBackT 	= 1
	endif
	
	SetVariable IXSeT0_SampleTVar,title="Sample transmission",proc=IXSTransActions,fSize=14,pos={320,100},size={210,23},limits={0,10,0.02},value=root:SPECTRA:Fitting:IXSe:gIXSeSampleT
	SetVariable IXSeT0_BackTVar,title="Container transmission",proc=IXSTransActions,fSize=14,pos={320,140},size={210,23},limits={0,10,0.02},value=root:SPECTRA:Fitting:IXSe:gIXSeBackT
End

Function IXSTransActions(sv) : SetVariableControl
	STRUCT WMSetVariableAction &sv
	
	if (sv.eventCode>0)
			IXSCorrection0()
	endif
	return 0
End

Function SelectIXSAction(bs) : ButtonControl
	STRUCT WMButtonAction &bs
	
	if(bs.eventCode==2)	// Mouse up
			Variable DataFlag = (cmpstr(bs.ctrlName,"IXSeT0_SelectDataButton") == 0) ? 1 : 0
			// The ControlInfo only returns a row number in "single-selection mode". 
//			ControlInfo /W=IXSePanel IXSDataListBox	
//			SelectIXSDataOrBack(DataFlag,V_Value) 
			
			// Instead, look up the first selected row
			WAVE Sel = root:SPECTRA:Fitting:IXSe:wFitDataSel
			FindValue /V=1 Sel
			SelectIXSDataOrBack(DataFlag,V_Value) 
	endif
	return 0
End

// ************************************************************************************************
// *******	Tab 1 - Elastic Peak Correction and Subtraction
// 					- 2017-10 Add a function to approximate multiple scattering contribution

// 
Function IXSCorrection1()
	
	WAVE Axis 			= root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	WAVE Data3 		= root:SPECTRA:Fitting:IXSe:IXS0_Data3
	WAVE Data4 		= root:SPECTRA:Fitting:IXSe:IXS0_Data4
	
	WAVE IXSEcoefs 	= root:SPECTRA:Fitting:IXSe:IXSEcoefs
	WAVE EcoefsSel 	= root:SPECTRA:Fitting:IXSe:EcoefsSel
	WAVE Elastic 		= root:SPECTRA:Fitting:IXSe:IXS1_Elastic
	
	WAVE IXSMScoefs 	= root:SPECTRA:Fitting:IXSe:IXSMScoefs
	WAVE MScoefsSel 	= root:SPECTRA:Fitting:IXSe:MScoefsSel
	WAVE MS 			= root:SPECTRA:Fitting:IXSe:IXS1_MS
	
	NVAR gIXSeEPeak1 	= root:SPECTRA:Fitting:IXSe:gIXSeEPeak1
	NVAR gIXSeEPeak2 	= root:SPECTRA:Fitting:IXSe:gIXSeEPeak2
	
	// Arctan parameters
	NVAR gIXSeMSCheck 	= root:SPECTRA:Fitting:IXSe:gIXSeMSCheck
	
	String HoldString = 	ListBoxToHoldString(EcoefsSel,2,0,4,1)//; print HoldString
	IXS1ListToCoefs()
		FuncFit/Q/H=HoldString IXS_Elastic IXSEcoefs Data3[BinarySearchInterp(Axis,max(gIXSeEPeak1,Axis[0])),BinarySearchInterp(Axis,min(gIXSeEPeak2,Axis[inf]))] /X=Axis 
	IXS1CoefsToList()

	Elastic = IXS_Elastic(IXSEcoefs,Axis)
	Data4 = Data3 - Elastic
	
	// Optional pseudo Multiple Scattering subtraction
	if (gIXSeMSCheck)
		// Make sure the MS wave has the correct size
		Variable NPts=DimSize(Data4,0)
		Redimension /N=(NPts) MS
		MS = IXS_MS(IXSMScoefs,Axis)
		
		// Make sure there is no background subtraction lower in energy than the second cursor
		Variable AToffset = MS[BinarySearchInterp(Axis,min(gIXSeEPeak2,Axis[inf]))]
		Data4[] = (Axis[p] < gIXSeEPeak2) ? Data4[p] : Data4[p] - (MS[p] - AToffset) 
	endif
	
	// Zero the start of the data
	Data4[0,BinarySearchInterp(Axis,max(gIXSeEPeak1,Axis[0]))] = 0
End

// A double exponential decay - point-by-point function
Function IXS_Elastic(w,E) : FitFunc
	Wave w
	Variable E
	
	return w[0] + w[1]*exp(-E*w[2]) + w[3]*exp(-E*w[4])
End

// An arctangent background function
Function IXS_MS(w,E) : FitFunc
	Wave w
	Variable E
	
	Variable ampl = (pi/2)*w[0] + w[0]*atan((E-w[2])/w[1])
	
	if (E>w[2])
		ampl *= exp(-w[3]*(E-w[2]))
	endif
	
	return ampl
End

Function IXSeTab1Items()

	GroupBox IXSeT1_Group1,pos={300,35},size={250,150},fSize=12,fColor=(39321,1,1),title="Subtract the Elastic Scattering"
	
	// List displaying the elastic peak fit coefficients 
	ListBox IXSeT1_EcoefsListBox pos={320,60},size={200,115},widths={50,65,25}
	ListBox IXSeT1_EcoefsListBox,mode= 4,fsize=11,proc=IXS1ListActions
	ListBox IXSeT1_EcoefsListBox,listWave=root:SPECTRA:Fitting:IXSe:EcoefsList
	ListBox IXSeT1_EcoefsListBox,selWave=root:SPECTRA:Fitting:IXSe:EcoefsSel
	
	// Fit ranges for elastic peak subtraction
	NVAR gIXSeEPeak1 = root:SPECTRA:Fitting:IXSe:gIXSeEPeak1
	if (!NVar_Exists(gIXSeEPeak1))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeEPeak1 	= 0.5
	endif
	NVAR gIXSeEPeak2 = root:SPECTRA:Fitting:IXSe:gIXSeEPeak2
	if (!NVar_Exists(gIXSeEPeak2))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeEPeak2 	= 5
	endif
	
	SetVariable IXSeT1_EPeak1Var,title="E\Bmin",proc=IXS1CsrActions,fSize=14,pos={320,210},size={100,17},limits={0,50,0.1},value=root:SPECTRA:Fitting:IXSe:gIXSeEPeak1
	SetVariable IXSeT1_EPeak2Var,title="E\Bmax",proc=IXS1CsrActions,fSize=14,pos={320,235},size={100,17},limits={0,50,0.1},value=root:SPECTRA:Fitting:IXSe:gIXSeEPeak2
	
	NVAR gIXSeMSCheck = root:SPECTRA:Fitting:IXSe:gIXSeMSCheck
	if (!NVar_Exists(gIXSeMSCheck))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeMSCheck 	= 0
	endif
	CheckBox IXSeT1_MSCheck,pos={575,200},size={74,205},title="Multiple scattering",fSize=14, variable=gIXSeMSCheck, disable=1 , proc=IXSeT1_MSCheck
	
	GroupBox IXSeT1_Group2,pos={550,35},size={230,150},fSize=12,fColor=(39321,1,1),title="Subtract Multiple Scattering"
	
	// List displaying the elastic peak fit coefficients 
	ListBox IXSeT1_MScoefsListBox pos={575,60},size={200,115},widths={50,65,25}
	ListBox IXSeT1_MScoefsListBox,mode= 4,fsize=11,proc=IXS1MSListActions
	ListBox IXSeT1_MScoefsListBox,listWave=root:SPECTRA:Fitting:IXSe:MScoefsList
	ListBox IXSeT1_MScoefsListBox,selWave=root:SPECTRA:Fitting:IXSe:MScoefsSel
	
End

Function IXSeTab1Plots()
	
	// *** The input waves for this Tab processing routines
	WAVE Data3 = root:SPECTRA:Fitting:IXSe:IXS0_Data3
	WAVE Axis = root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	
	// *** Make the necessary waves here
	Duplicate /O/D Data3, root:SPECTRA:Fitting:IXSe:IXS0_Data4, root:SPECTRA:Fitting:IXSe:IXS1_Elastic
	WAVE Data4 = root:SPECTRA:Fitting:IXSe:IXS0_Data4
	WAVE Elastic = root:SPECTRA:Fitting:IXSe:IXS1_Elastic
	
//	WAVE MS = root:SPECTRA:Fitting:IXSe:IXS1_MS
	
	Duplicate /O/D Data3, root:SPECTRA:Fitting:IXSe:IXS1_MS /WAVE=MS
	MS = 0
	
	// *** Run the Data Processing function
	IXSCorrection1()
	
	Display/W=(11,304,784,946)/HOST=# Data3 vs Axis
		AppendToGraph Elastic, MS, Data4 vs Axis
		ModifyGraph rgb(IXS1_Elastic)=(1,16019,65535), rgb(IXS0_Data4)=(0,0,0), rgb(IXS1_MS)=(1,39321,19939)
		ModifyGraph mirror=2, lowTrip(left)=0.01
		SetAxis/A/E=1 left
		Legend/C/N=text0/J/F=0/A=RT/X=6.60/Y=7.32 "\s(IXS0_Data3) Data - background\r\\s(IXS1_Elastic) Elastic peak\r\r\\s(IXS0_Data4) Data - Elastic"
		Label left "Spectrum Intensity"
		Label bottom "Energy (eV)"
		RenameWindow #, Tab1Plot
		
		IXS1CsrFunction()
		
	SetActiveSubwindow ##
End

// Transfer the Multiple Scattering coefficent values
Function IXS1MSListActions(lb) : ListboxControl
	STRUCT WMListboxAction &lb
	
	if (lb.eventCode==7)
		IXS1MSListToCoefs()
	endif
	return 0
End

Function IXS1MSCoefsToList()

	WAVE IXSMScoefs 		= root:SPECTRA:Fitting:IXSe:IXSMScoefs
	WAVE /T MScoefsList = root:SPECTRA:Fitting:IXSe:MScoefsList
	
	Variable i, NCfs=DimSize(IXSMScoefs,0)
	String NValue
	
	for (i=0;i<NCfs;i+=1)
		sprintf NValue, "%4.4f", IXSMScoefs[i]
		MScoefsList[i][1] = NValue
	endfor
End

Function IXS1MSListToCoefs()

	WAVE IXSMScoefs 		= root:SPECTRA:Fitting:IXSe:IXSMScoefs
	WAVE /T MScoefsList = root:SPECTRA:Fitting:IXSe:MScoefsList
	
	IXSMScoefs[] = str2num(MScoefsList[p][1])
End

// Transfer the Elastic Peak coefficent values
Function IXS1ListActions(lb) : ListboxControl
	STRUCT WMListboxAction &lb
	
	if (lb.eventCode==7) 	// Manual change value
		IXS1ListToCoefs()
		IXSCorrection1()
	endif
	return 0
End

Function IXS1CoefsToList()

	WAVE IXSEcoefs 		= root:SPECTRA:Fitting:IXSe:IXSEcoefs
	WAVE /T EcoefsList = root:SPECTRA:Fitting:IXSe:EcoefsList
	
	Variable i, NCfs=DimSize(IXSEcoefs,0)
	String NValue
	
	for (i=0;i<NCfs;i+=1)
		sprintf NValue, "%4.4f", IXSEcoefs[i]
		EcoefsList[i][1] = NValue
	endfor
End

Function IXS1ListToCoefs()

	WAVE IXSEcoefs 		= root:SPECTRA:Fitting:IXSe:IXSEcoefs
	WAVE /T EcoefsList = root:SPECTRA:Fitting:IXSe:EcoefsList
	
	IXSEcoefs[] = str2num(EcoefsList[p][1])
End

// Move the Cursors
Function IXS1CsrActions(sv) : SetVariableControl
	STRUCT WMSetVariableAction &sv
	
	if (sv.eventCode>0)
		IXS1CsrFunction()
		IXSCorrection1()	//<--- 	perform the background subtraction automatically when cursor positions are changed
	endif
	return 0
End

Function IXS1CsrFunction()

	NVAR gIXSeEPeak1 = root:SPECTRA:Fitting:IXSe:gIXSeEPeak1
	NVAR gIXSeEPeak2 = root:SPECTRA:Fitting:IXSe:gIXSeEPeak2
	
	Cursor /P/W=IXSePanel#Tab1Plot A IXS0_Data3 BinarySearchInterp(root:SPECTRA:Fitting:IXSe:IXS0_DataAxis,gIXSeEPeak1)
	Cursor /P/W=IXSePanel#Tab1Plot B IXS0_Data3 BinarySearchInterp(root:SPECTRA:Fitting:IXSe:IXS0_DataAxis,gIXSeEPeak2)
End

Function IXSeT1_MSCheck(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	IXSCorrection1()
End

// ************************************************************************************************
// *******	Tab 2 - Power-law continuation of the spectrum

Function IXSCorrection2()
	
	WAVE IXSTcoefs 		= root:SPECTRA:Fitting:IXSe:IXSTcoefs
	WAVE TcoefsSel 		= root:SPECTRA:Fitting:IXSe:TcoefsSel
	
	WAVE Data4 			= root:SPECTRA:Fitting:IXSe:IXS0_Data4
	WAVE Axis 			= root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	WAVE Data5 			= root:SPECTRA:Fitting:IXSe:IXS2_Data5
	WAVE Axis2 			= root:SPECTRA:Fitting:IXSe:IXS2_Axis2
	WAVE Power 			= root:SPECTRA:Fitting:IXSe:IXS2_Power
	
	NVAR gIXSePower1 	= root:SPECTRA:Fitting:IXSe:gIXSePower1
	NVAR gIXSePower2 	= root:SPECTRA:Fitting:IXSe:gIXSePower2

	// Must make sure these values are correct - seems to work fine
	Axis2[0,numpnts(Axis)-1] 	= Axis[p]
	Axis2[numpnts(Axis),] 		= Axis2[p-1]+0.1
	
	String HoldString = 	ListBoxToHoldString(TcoefsSel,2,0,2,1)
	IXS2ListToCoefs()
		FuncFit/Q/H=HoldString IXS_Tail IXSTcoefs Data4[BinarySearchInterp(Axis,gIXSePower1),BinarySearchInterp(Axis,gIXSePower2)] /X=Axis 
	IXS2CoefsToList()
	
	Power = NaN
	Power[BinarySearchInterp(Axis2,gIXSePower1),] 	= IXS_Tail(IXSTcoefs,Axis2)
	Data5[0,BinarySearchInterp(Axis2,gIXSePower2)] 	= Data4[p]
	Data5[BinarySearchInterp(Axis2,gIXSePower2),] 	= Power[p]
End

Function IXSeTab2Items()

	// List displaying the elastic peak fit coefficients 
	ListBox IXSeT2_EcoefsListBox pos={340,80},size={200,85},widths={50,65,25}
	ListBox IXSeT2_EcoefsListBox,mode= 4,fsize=11,proc=IXS2ListActions
	ListBox IXSeT2_EcoefsListBox,listWave=root:SPECTRA:Fitting:IXSe:TcoefsList
	ListBox IXSeT2_EcoefsListBox,selWave=root:SPECTRA:Fitting:IXSe:TcoefsSel	
	
	GroupBox IXSeT2_Group1,pos={300,35},size={300,200},fSize=12,fColor=(39321,1,1),title="Append a Power-Law Tail"
	
	// Fit ranges for elastic peak subtraction
	NVAR gIXSePower1 = root:SPECTRA:Fitting:IXSe:gIXSePower1
	if (!NVar_Exists(gIXSePower1))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSePower1 	= 70
	endif
	NVAR gIXSePower2 = root:SPECTRA:Fitting:IXSe:gIXSePower2
	if (!NVar_Exists(gIXSePower2))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSePower2 	= 80
	endif
	
	SetVariable IXSeT2_Power1Var,title="E\Bmin",proc=IXS2CsrActions,fSize=14,pos={320,210},size={100,17},limits={0,1000,0.2},value=gIXSePower1
	SetVariable IXSeT2_Power2Var,title="E\Bmax",proc=IXS2CsrActions,fSize=14,pos={320,235},size={100,17},limits={0,1000,0.2},value=gIXSePower2

End

Function IXSeTab2Plots()
	
	// *** The input waves for this Tab processing routines
	WAVE Data4 = root:SPECTRA:Fitting:IXSe:IXS0_Data4
	WAVE Axis = root:SPECTRA:Fitting:IXSe:IXS0_DataAxis
	
	// *** Make the necessary waves here
	Variable NEpts = (1000 - Axis[Inf])/0.1 + DimSize(Data4,0)
	Make /O/D/N=(NEPts) root:SPECTRA:Fitting:IXSe:IXS2_Axis2/Wave=Axis2
	Make /O/D/N=(NEPts) root:SPECTRA:Fitting:IXSe:IXS2_Power/Wave=Power
	Make /O/D/N=(NEPts) root:SPECTRA:Fitting:IXSe:IXS2_Data5/Wave=Data5

	// *** Run the Data Processing function
	IXSCorrection2()
	
	Display/W=(11,304,784,946)/HOST=# Data4 vs Axis
		AppendToGraph Power vs Axis2
		ModifyGraph rgb(IXS2_Power)=(1,16019,65535), rgb(IXS0_Data4)=(0,0,0)
		ModifyGraph mirror=2, lowTrip(left)=0.01
		SetAxis/A/E=1 left
		Legend/C/N=text0/J/F=0/A=RT/X=6.60/Y=7.32 "\s(IXS0_Data4) Data - Elastic\r\\s(IXS2_Power) Power-law decay"
		Label left "Spectrum Intensity"
		Label bottom "Energy (eV)"
		RenameWindow #, Tab2Plot	
	SetActiveSubwindow ##
		
	IXS2CsrFunction()
End

// Need to transfer coefficent values
Function IXS2ListActions(lb) : ListboxControl
	STRUCT WMListboxAction &lb
	
	if (lb.eventCode==7)
	// ??????????????????????????
//		IXS1ListToCoefs()
		IXS2ListToCoefs()
		IXSCorrection2()
	endif
	return 0
End

Function IXS2CoefsToList()

	WAVE IXSTcoefs 		= root:SPECTRA:Fitting:IXSe:IXSTcoefs
	WAVE /T TcoefsList = root:SPECTRA:Fitting:IXSe:TcoefsList
	
	Variable i, NCfs=DimSize(IXSTcoefs,0)
	String NValue
	
	for (i=0;i<NCfs;i+=1)
		sprintf NValue, "%4.4f", IXSTcoefs[i]
		TcoefsList[i][1] = NValue
	endfor
End

Function IXS2ListToCoefs()

	WAVE IXSTcoefs 		= root:SPECTRA:Fitting:IXSe:IXSTcoefs
	WAVE /T TcoefsList = root:SPECTRA:Fitting:IXSe:TcoefsList
	
	IXSTcoefs[] = str2num(TcoefsList[p][1])
End

Function IXS2CsrActions(sv) : SetVariableControl
	STRUCT WMSetVariableAction &sv
	
	if (sv.eventCode>0)
		IXS2CsrFunction()
		IXSCorrection2()
	endif
	return 0
End

Function IXS2CsrFunction()

	NVAR gIXSePower1 = root:SPECTRA:Fitting:IXSe:gIXSePower1
	NVAR gIXSePower2 = root:SPECTRA:Fitting:IXSe:gIXSePower2
	
	Cursor /P/W=IXSePanel#Tab2Plot A IXS0_Data4 BinarySearchInterp(root:SPECTRA:Fitting:IXSe:IXS0_DataAxis,gIXSePower1)
	Cursor /P/W=IXSePanel#Tab2Plot B IXS0_Data4 BinarySearchInterp(root:SPECTRA:Fitting:IXSe:IXS0_DataAxis,gIXSePower2)
End

// ************************************************************************************************
// *******	Tab 3 - Normalization of the Optical Oscillator Strength (OOS)

Function IXSCorrection3()
	
	WAVE Data5 		= root:SPECTRA:Fitting:IXSe:IXS2_Data5
	WAVE Axis2 		= root:SPECTRA:Fitting:IXSe:IXS2_Axis2
	WAVE OOS 			= root:SPECTRA:Fitting:IXSe:IXS3_OOS
	
	NVAR gIXSNe 			= root:SPECTRA:Fitting:IXSe:gIXSNe
	NVAR gIXSeOOS1 		= root:SPECTRA:Fitting:IXSe:gIXSeOOS1
	NVAR gIXSeOOS2 		= root:SPECTRA:Fitting:IXSe:gIXSeOOS2
	NVAR gIXSOOSCheck 	= root:SPECTRA:Fitting:IXSe:gIXSOOSCheck
	
	Variable OOSArea
	
	SetScale/P x 0,0.1,"eV", OOS
	Interpolate2/T=1/Y=OOS/I=3 Axis2,Data5
	
	
	if (gIXSOOSCheck)
		// First, convert the signal to the OOS. 
		// There are a few additional constants, but these are irrelevant as the Bethe sum rule will be applied
		OOS 			*= x
		
		OOSArea 	= area(OOS,gIXSeOOS1,gIXSeOOS2)
		OOS 			*= gIXSNe/OOSArea		// <--- this is correct
		
	else
		// This is an option to avoid multiplication by x. It is WRONG but instructive
		OOS/=gIXSNe
	endif 
	
End

Function IXSeT3_OOSCheck(CB_Struct) : CheckBoxControl 
	STRUCT WMCheckboxAction &CB_Struct 
	
	Variable eventCode		= CB_Struct.eventCode
	if (eventCode != 2)
		return 0
	endif
	
	IXSCorrection3()
End
	
Function IXSeTab3Items()
	
	GroupBox IXSeT3_Group1,pos={300,35},size={300,200},fSize=12,fColor=(39321,1,1),title="Normalize OOS to number of electrons per formula unit"
	
	// Number of electrons per formula unit
	NVAR gIXSNe = root:SPECTRA:Fitting:IXSe:gIXSNe
	if (!NVar_Exists(gIXSNe))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSNe 	= 30
	endif
	SetVariable IXSeT3_NeVar,title="# Electrons",proc=IXS3CsrActions,fSize=14,pos={320,175},size={140,17},limits={1,1000,0.2},value=gIXSNe
	
	// Fit ranges for OOS area integration
	NVAR gIXSeOOS1 = root:SPECTRA:Fitting:IXSe:gIXSeOOS1
	if (!NVar_Exists(gIXSeOOS1))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeOOS1 	= 0
	endif
	NVAR gIXSeOOS2 = root:SPECTRA:Fitting:IXSe:gIXSeOOS2
	if (!NVar_Exists(gIXSeOOS2))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSeOOS2 	= 80
	endif
	
	SetVariable IXSeT3_OOS1Var,title="E\Bmin",proc=IXS3CsrActions,fSize=14,pos={320,210},size={100,17},limits={0,1000,0.2},value=gIXSeOOS1
	SetVariable IXSeT3_OOS2Var,title="E\Bmax",proc=IXS3CsrActions,fSize=14,pos={320,235},size={100,17},limits={0,1000,0.2},value=gIXSeOOS2
	
	NVAR gIXSOOSCheck = root:SPECTRA:Fitting:IXSe:gIXSOOSCheck
	if (!NVar_Exists(gIXSOOSCheck))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSOOSCheck 	= 1
	endif
	
	CheckBox IXSeT3_OOSCheck,pos={575,200},size={74,205},title="Convert to OOS",fSize=14, variable=gIXSOOSCheck, disable=1 , proc=IXSeT3_OOSCheck

End

Function IXSeTab3Plots()
	
	// *** The input waves for this Tab processing routines
	WAVE Data5 = root:SPECTRA:Fitting:IXSe:IXS2_Data5
	WAVE Axis2 = root:SPECTRA:Fitting:IXSe:IXS2_Axis2
	
	// *** Make the necessary waves here
	Make /O/D/N=10000 root:SPECTRA:Fitting:IXSe:IXS3_OOS/Wave=OOS
	
	// *** Run the Data Processing function
	IXSCorrection3()
	
	Display/W=(11,304,784,946)/HOST=# OOS
		ModifyGraph mirror=2, lowTrip(left)=0.01
		SetAxis/A/E=1 left
		Legend/C/N=text0/J/F=0/A=RT/X=6.60/Y=7.32 "\s(IXS3_OOS) Optical oscillator strength"
		Label left "oscillator strength (eV-1)"
		Label bottom "Energy (eV)"
		RenameWindow #, Tab3Plot	
	SetActiveSubwindow ##
End

Function IXS3CsrActions(sv) : SetVariableControl
	STRUCT WMSetVariableAction &sv
	
	if (sv.eventCode>0)
		IXS3CsrFunction()
		IXSCorrection3()
	endif
	return 0
End

Function IXS3CsrFunction()

	NVAR gIXSeOOS1 = root:SPECTRA:Fitting:IXSe:gIXSeOOS1
	NVAR gIXSeOOS2 = root:SPECTRA:Fitting:IXSe:gIXSeOOS2
	
	Cursor /P/W=IXSePanel#Tab3Plot A IXS3_OOS x2pnt(root:SPECTRA:Fitting:IXSe:IXS3_OOS,gIXSeOOS1)
	Cursor /P/W=IXSePanel#Tab3Plot B IXS3_OOS x2pnt(root:SPECTRA:Fitting:IXSe:IXS3_OOS,gIXSeOOS2)
End

// ************************************************************************************************
// *******	Tab 4 - Generation of the Complex Dielectric Function

Function IXSCorrection4()

	WAVE OOS 			= root:SPECTRA:Fitting:IXSe:IXS3_OOS
	WAVE S0E 			= root:SPECTRA:Fitting:IXSe:IXS4_S0E
	WAVE ImInve 		= root:SPECTRA:Fitting:IXSe:IXS4_ImInve
	WAVE ReInve 		= root:SPECTRA:Fitting:IXSe:IXS4_ReInve
	
	NVAR gIXSNe 		= root:SPECTRA:Fitting:IXSe:gIXSNe
	NVAR gERho 		= root:SPECTRA:Fitting:IXSe:gIXSERho
	NVAR gIXSRI 		= root:SPECTRA:Fitting:IXSe:gIXSRI
	
	// Option not to do the IXS procedure but a more general KK
	NVAR gIXSOOSCheck 	= root:SPECTRA:Fitting:IXSe:gIXSOOSCheck
	
	
	// *** Make the Hilbert Transform waves here
	Make /O/D/N=19999 root:SPECTRA:Fitting:IXSe:ImInveL /Wave=ImInveL
	Make /O/D/N=19999 root:SPECTRA:Fitting:IXSe:ReInveL /Wave=ReInveL
	
	Make /O/D/N=20000 root:SPECTRA:Fitting:IXSe:HilbertAxis /Wave=HilbertAxis
	SetScale/P x -999.9,0.1,"", ImInveL, ReInveL // So point 9999 is zero
	HilbertAxis[] = -999.9 + 0.1*p
	
	if (gIXSOOSCheck)
		S0E[1,] 			= OOS/x
		S0E[0] 		= 0
		
		ImInve[1,] 		= (2*pi^2*gERho*OOS[p])/x
		ImInve[0] 	= 0
	
	else
			ImInve[] 		= OOS[p]
	endif
	
	// Implement the KK transform via Hilbert
	// Hilbert works for a function f(-x) = -f(x) 
	
	// This correctly places both + and - waves on the right points
	ImInveL[0,10000-1] 	= -ImInve[10000-p-1]
	ImInveL[9999,] 		= ImInve[p-10000+1]
	
	// Add a point to end as we need an even number of points
	Redimension /N=20000 ImInveL	
	ImInveL[19999]=ImInveL[19998]   		// The input to the Hilbert transform is the Imaginary part of the inverse dielectric function 

	// Signs need careful handingl as the Hilbert transform in Igor and the Kramers-Kronig relation are sign-opposite.
	
	HilbertTransform /DEST=IXS4_Hilbert ImInveL
	ReInveL 		= 1 - IXS4_Hilbert				// Conversion to the real part of the inverse dielectric function 
	
	// New re-populate the half-space real function
	ReInve[] = -ReInveL[p+9999]			// Point 9999 is zero for Hilbert
	
	Duplicate /O ReInve, root:SPECTRA:Fitting:IXSe:IXS4_e1/WAVE=e1
	Duplicate /O ReInve, root:SPECTRA:Fitting:IXSe:IXS4_e2/WAVE=e2
	
	if (gIXSOOSCheck)
		e1 = -1*ReInve/(ReInve^2+ImInve^2)
		e2 = ImInve/(ReInve^2+ImInve^2)
	else
		e1 = ReInve+90/gIXSNe
		e2 = ImInve
		e1*= gERho
		e2*= gERho
	endif
	
	gIXSRI 	= sqrt( 0.5 * ( sqrt(e1[0]^2+e2[0]^2) + e1[0]) )
End

//Function IXSCorrection4()
//
//	WAVE OOS 			= root:SPECTRA:Fitting:IXSe:IXS3_OOS
//	WAVE S0E 			= root:SPECTRA:Fitting:IXSe:IXS4_S0E
//	WAVE ImInve 		= root:SPECTRA:Fitting:IXSe:IXS4_ImInve
//	WAVE ReInve 		= root:SPECTRA:Fitting:IXSe:IXS4_ReInve
//	
//	NVAR gERho 			= root:SPECTRA:Fitting:IXSe:gIXSERho
//
//	S0E 	= OOS/x
//	S0E[0] = 0
////	S0E[] = (S0E[p] < 0) ? 0 : S0E[p]
//	
//	// *** APPEARS TO BE A FACTOR 2 ERROR ***
////	ImInve[] 		= (2*pi^2*gERho*S0E[p])/x
//
//	// Here we also need to know q = 0.27, so q^2 =  0.0729
//	Variable qq = 0.0729
//	
//	ImInve[] 		= (2*pi^2*gERho*OOS[p])/(x)
//	ImInve[0] 	= 0
//
//	HilbertTransform /DEST=IXS4_Hilbert ImInve
//	ReInve 		= 1 - IXS4_Hilbert
//	
//	Duplicate /O ReInve, root:SPECTRA:Fitting:IXSe:IXS4_e1/WAVE=e1
//	Duplicate /O ReInve, root:SPECTRA:Fitting:IXSe:IXS4_e2/WAVE=e2
//	
//	e1 = ReInve/(ReInve^2+ImInve^2)
//	e2 = ImInve/(ReInve^2+ImInve^2)
//	
////	Variable NEPts = numpnts(e1)
////	Make /O/D/C/N=(NEPts) root:SPECTRA:Fitting:IXSe:IXS4_e/WAVE=e
////	e = cmplx(e1,e2)
//End

Function IXSeTab4Items()
	
	GroupBox IXSeT4_Group1,pos={300,35},size={300,200},fSize=12,fColor=(39321,1,1),title="Calculate the complex dielectric constant"
	
	// Number of electrons per unit volume
	NVAR gIXSERho = root:SPECTRA:Fitting:IXSe:gIXSERho
	if (!NVar_Exists(gIXSERho))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSERho 	= 30
	endif
	SetVariable IXSeT4_ERhoVar,title="Electron number density nm\S-3",proc=IXS4CsrActions,fSize=14,pos={320,110},size={270,17},limits={0,1000,0.05},value=gIXSERho
	
	// Low-energy refractive index
	NVAR gIXSRI = root:SPECTRA:Fitting:IXSe:gIXSRI
	if (!NVar_Exists(gIXSRI))
		Variable /G root:SPECTRA:Fitting:IXSe:gIXSRI 	= -1
	endif
	ValDisplay IXSeT4_RIDisplay,title="Refractive index",proc=IXS4CsrActions,fSize=14,pos={320,175},size={220,17},value=#"root:SPECTRA:Fitting:IXSe:gIXSRI"

End

Function IXSeTab4Plots()
	
	// *** The input waves for this Tab processing routines
	WAVE OOS 			= root:SPECTRA:Fitting:IXSe:IXS3_OOS
	
	// *** Make the necessary waves here
	Duplicate /O OOS, root:SPECTRA:Fitting:IXSe:IXS4_S0E, root:SPECTRA:Fitting:IXSe:IXS4_ImInve, root:SPECTRA:Fitting:IXSe:IXS4_ReInve
	
	// *** Run the Data Processing function
	IXSCorrection4()
	
	WAVE IXS4_e1 	= root:SPECTRA:Fitting:IXSe:IXS4_e1
	WAVE IXS4_e2 	= root:SPECTRA:Fitting:IXSe:IXS4_e2
	WaveStats /Q/M=1 IXS4_e1
	
	Display/W=(11,304,784,946)/HOST=# IXS4_e1, IXS4_e2
		ModifyGraph lsize=1.5,rgb(IXS4_e1)=(3,52428,1)
		ModifyGraph mirror=2, grid=2, nticks(left)=10
		ModifyGraph margin(left)=126, lblRot(left)=-90
		SetAxis left -0.1,1.1*V_max
		SetAxis bottom *,100
		Legend/C/N=text0/J/F=0/A=RT/X=6.60/Y=7.32 "\s(IXS4_e1) \Z28ε\B1\M\r\\s(IXS4_e2) \Z28ε\B2\M"
		Label left "\Z32ε(E)"
		Label bottom "\Z28Energy (eV)"
		RenameWindow #, Tab4Plot	
		Cursor /H=2/W=IXSePanel#Tab4Plot A IXS4_e2 50
	SetActiveSubwindow ##
End

Function IXS4CsrActions(sv) : SetVariableControl
	STRUCT WMSetVariableAction &sv
	
	if (sv.eventCode>0)
		IXSCorrection4()
		
		WAVE IXS4_e1 	= root:SPECTRA:Fitting:IXSe:IXS4_e1
		WaveStats /Q/M=1 IXS4_e1
//		SetAxis/W=IXSePanel#Tab4Plot left -0.1,1.1*V_max
	
	endif
	return 0
End


// To fit the tail, A at x=549 x=54.9, B at x=800 x=80


Function ComplexDielectric(Ree,Ime)
	Wave Ree,Ime
	
	Duplicate /O Ree, IXSeps1, IXSeps2
	
	IXSeps1 = Ree/(Ree^2+Ime^2)
	
	IXSeps2 = Ime/(Ree^2+Ime^2)
End

Function PrepareIXSTransform()

//	Area

End

// A power law decay - as an point-by-point function
Function IXS_Tail(w,E) : FitFunc
	Wave w
	Variable E
	
	return w[0] + w[1]*E^w[2]
End


// A double exponential decay - as an all-at-once function
//Function IXS_Elastic(w,yw,xw) : FitFunc
//	Wave w,yw,xw		
//	
//	yw = w[0] + w[1]*exp(-xw*w[2]) + w[3]*exp(-xw*w[4])
//		
//End

//I have already performed Kramers-Kronig integrals on absorption spectra to
//get the respective refractive index spectra.
//You need to use the Hilbert transform. This does exactly what you need.
//This is the code I used. Before using this code, you must scale your
//absorption wave with the wavelengths.
//
//Be aware that if you wish to perform exact Kramers-Kronig numerical
//computation, you must have a spectrum ranging from 0 to infinity, which is,
//in practice, never the case. To overcome this problem, you could use bounds
//but that is a challenge I have not tried with Igor (see " Finite Frequency
//Range Kramers Kronig Relations: Bounds on the Dispersion", Physical Review
//Letters, 79, 3062 1997)).


 // Absn is the $("abs_"+nom_ech[i]+"_unexposed")
 // WaveLn is the $(nom_ech[i]+"_Wavelength")
 
 // Absn_KK is the $("K_"+nom_ech[i]+"_unexposed")
 // Absn_n is the $("n_"+nom_ech[i]+"_unexposed")

Function KK(Absn,WaveLn)
	Wave Absn, WaveLn
	
	Variable AbsnMin, AbsnMax
	
	// Absorption coefficient in cm-1.
	Duplicate /O Absn, Absn_KK
	
	// Imaginary part of the refractive index (unitless).
	Absn_KK 	= ((WaveLn*10^-9)/(4*PI)) * Absn*100		
	
	// Convert wavelengths (nm) into angular frequencies (rad/s).
	WaveStats WaveLn
	AbsnMin=2*PI*cLightSpeed/(V_min*10^-9)	
	AbsnMax=2*PI*cLightSpeed/(V_max*10^-9)
	
	// Rescale the imaginary part with the angular frequencies.
	SetScale/I x AbsnMin,AbsnMax,"", Absn_KK
	
	// Redimension into complex wave (needed for the Hilbert transform).
	Redimension/C Absn_KK
	Duplicate/O Absn_KK Abns_n
	
	// Create the real part of the refractive index.
	// Do Hilbert transform.
	HilbertTransform /DEST=Abns_n Absn_KK
	
	// Redimension into real wave (physical value).
	Redimension/R Abns_n
	SetScale/I x V_min,V_max,"", Abns_n
	
	// There is a sign "-" because the Hilbert transform in Igor and the Kramers-Kronig relation are sign-opposite.
	Abns_n += -1
	
End
