#pragma rtGlobals=1		// Use modern global access method.

Menu "Plots"
	"Layout Control Panel"
	"Images to PPT"
End

Function ImagesToPPT()

	String cmd, PanelList, PanelName, LayoutName, ImageName, NewImageName
	String LayoutPlotList="", subWName = "EEMPlot"
	Variable i, j, n=0, NImages, NLayouts, NToDisplay, width=2.5
	
	// List the Image plots to transfer to a layout
	PanelList 	= ListOfImagePanels(subWName)
	NImages 	= ItemsInList(PanelList)
	NLayouts	= ceil(NImages/12)
	
	PanelList 	= SortList(PanelList,";",9)
	
	if (NLayouts > 12)
		Print " *** 	Creating",NLayouts,"layouts for printing all displayed 2D plots"
	else
		Print " *** 	Creating a layout for printing all displayed 2D plots"
	endif
	
	for (i=0;i<NLayouts;i+=1)
		LayoutPlotList = ""
		LayoutName 	= "Layout_"+subWName+"_"+num2str(i)
		DoWindow /K $LayoutName
		NewLayout /K=1/P=Landscape/N=$LayoutName/W=(220,277,721,853) as "Excitation-emission matrices"
		SetWindow $LayoutName, hook(Layout2DHook)=Layout2DHook
		
		NToDisplay 	= mod(NImages,12)
		
		for (j=0;j<NToDisplay;j+=1)
			PanelName 		= StringFromList(j,PanelList)
			ImageName 		= StringFromList(j,PanelList)+"#"+subWName
			NewImageName 	= RecreateSubWindow2DPlot(PanelName,ImageName)
			LayoutPlotList 	= AddListItem(NewImageName,LayoutPlotList)
			AppendLayoutObject /W=$LayoutName graph $NewImageName
		endfor
		
		Execute "Tile/A=(3,4)/O=1"
		SetWindow $LayoutName,userdata+= "LayoutPlotList="+LayoutPlotList+","
		
		for (j=0;j<NToDisplay;j+=1)
			NewImageName 	= StringFromList(j,LayoutPlotList)
			ModifyLayout/I width($NewImageName)=(width),height($NewImageName)=(width) //(in inches)
		endfor
	endfor
	
End

Function Layout2DHook(H_Struct) 
	STRUCT WMWinHookStruct &H_Struct 

	Variable eventCode	= H_Struct.eventCode
	String windowName	= H_Struct.winName
	
	Variable i, NPlots
	String LayoutPlotList, PlotName
	
	// Delete the images shown in the layout
	if (eventCode == 2)
		LayoutPlotList 	= StringByKey("LayoutPlotList",GetUserData(windowName, "", ""),"=",",")
		NPlots 			= ItemsInList(LayoutPlotList)
		for (i=0;i<NPlots;i+=1)
			DoWindow /K $(StringFromList(i,LayoutPlotList))
		endfor 
		return 1
	endif
	
	return 0
End

Function /T RecreateSubWindow2DPlot(PanelName,subWName)
	String PanelName, subWName
	
	String subWInfo, ImageName, ImagePath, XAxisPath, YAxisPath
	String RecStr, ModStr, CmdStr
	
	subWInfo 	= ImageInfo(subWName,"",0)
	ImageName 	= StringByKey("ZWAVE",subWInfo)
	ImagePath 	= StringByKey("ZWAVEDF",subWInfo)+StringByKey("ZWAVE",subWInfo)
	XAxisPath 	= StringByKey("XWAVEDF",subWInfo)+StringByKey("XWAVE",subWInfo)
	YAxisPath 	= StringByKey("YWAVEDF",subWInfo)+StringByKey("YWAVE",subWInfo)
	RecStr 		= GetRECREATIONFromInfo(subWInfo)
	
	Variable scale=1
	
	GetWindow  $subWName gsize
	Display /K=0/HIDE=1/W=(scale*V_left,scale*V_top,scale*V_right,scale*V_bottom)
	AppendImage $ImagePath vs {$XAxisPath,$YAxisPath}
	
	ModStr 		= StringByKey("ctab",RecStr, "=")
	CmdStr 		= "ModifyImage /W="+S_name+" "+ImageName+" ctab="+ModStr
	Execute CmdStr
	
	ModStr 		= AxisLabelText(PanelName, "left")
	Label /W=$S_name/Z left, ModStr
	
	ModStr 		= AxisLabelText(PanelName, "bottom")
	Label /W=$S_name/Z bottom, ModStr
	
	TextBox/C/N=text0/A=LT/X=40/Y=0 ImageName
	
//	ColorScale /A=LT/X=-0.3/Y=-0.3 heightPct=50, width=20
	
//	WaveStats /Q/M=1 $ImagePath
//	ColorScale/C/N=ColorScale0/A=LT/X=-0.3/Y=-0.3  ctab={V_min,V_max,Geo,0} gColorScaleLabel
//	ColorScale/C/N=ColorScale0 heightPct=40, width=12
	
	return S_name
end


	
//	GetWindow  $subWName wsize
//	GetWindow  $subWName wsizeOuter
//	print AxisInfo(subWName,"left")
//	GetAxis
//	Label

Function/S GetRECREATIONFromInfo(info)
	String info	// from ImageInfo, ContourInfo, TraceInfo, or AxisInfo

	String key=";RECREATION:"
	Variable sstop= strsearch(info, key, 0)
	info= info[sstop+strlen(key),inf]		// want just recreation stuff
	return info
end

Function /T ListOfImagePanels(subWName)
	String subWName
	
	String PanelList, PanelName, PlotList
	Variable i, j, NPanels
	
	PanelList 	= WinList("*",";","WIN:64")
	NPanels 	= ItemsInList(PanelList)
	
	for (i=0;i<NPanels;i+=1)
		PanelName 	= StringFromList(j,PanelList)
		PlotList 	= ChildWindowList(PanelName)
		if (WhichListItem(subWName,PlotList) == -1)
			PanelList 	= RemoveListItem(j,PanelList)
		else
			j+=1
		endif
	endfor
	
	return PanelList
End






















Proc LayoutControlPanel()
	
	InitLayoutControl()
	UpdateWindowLists("")
	
	DoWindow /K LayoutControlPanel
	NewPanel /K=1/W=(500,50,800,500) as "Layout Control Panel"
	DoWindow /C LayoutControlPanel
	CheckWindowPosition("",500,50,800,500)
	
	PopupMenu GraphListMenu,pos={10,25},proc=LayoutControlMenuProcs, size={282,20},title="Plots"
	PopupMenu GraphListMenu,fSize=12,mode=1,value=#"root:Packages:Layouts:gGraphList"
	
	PopupMenu TableListMenu,pos={10,85},proc=LayoutControlMenuProcs, size={282,20},title="Tables"
	PopupMenu TableListMenu,fSize=12,mode=1,value=#"root:Packages:Layouts:gTableList"
	
	PopupMenu GizmoListMenu,pos={10,145},proc=LayoutControlMenuProcs, size={282,20},title="Gizmos"
	PopupMenu GizmoListMenu,fSize=12,mode=1,value=#"root:Packages:Layouts:gGizmoList"
	
	PopupMenu LayoutListMenu,pos={10,200},proc=LayoutControlMenuProcs, size={282,20},title="Layouts"
	PopupMenu LayoutListMenu,fSize=12,mode=1,value=#"root:Packages:Layouts:gLayoutList"
	
	Button UpdateButton,fSize=12,pos={75,5},size={140,20},proc=UpdateWindowLists,title="Update"
	Button GraphAddButton,fSize=12,pos={44,50},size={140,20},proc=AddToLayout,title="Add Plot To Layout"
	Button TableAddButton,fSize=12,pos={44,110},size={140,20},proc=AddToLayout,title="Add Table To Layout"
	Button GizmoAddButton,fSize=12,pos={44,170},size={140,20},proc=AddToLayout,title="Add Gizmo To Layout"

End

Function UpdateWindowLists(ctrlname):ButtonControl
	String ctrlname

	UpdateWindowList("Graph")
	UpdateWindowList("Table")
	UpdateWindowList("Gizmo")
	UpdateWindowList("Layout")
End

Function UpdateWindowList(WindowType)
	String WindowType

	SVAR gWinList 			= $("root:Packages:Layouts:g"+WindowType+"List")
	SVAR gWinSelection 	= $("root:Packages:Layouts:g"+WindowType+"Selection")
	
	String OptionStr, ControlName
	if (cmpstr(WindowType,"Graph") == 0)
		OptionStr = "WIN:1"
	elseif (cmpstr(WindowType,"Table") == 0)
		OptionStr = "WIN:2"
	elseif (cmpstr(WindowType,"Layout") == 0)
		OptionStr = "WIN:4"
	elseif (cmpstr(WindowType,"Gizmo") == 0)
		OptionStr = "WIN:4096"
	endif
	
	gWinList = WinList("*",";",OptionStr)
	
	if (strlen(gWinList) == 0)
		if (cmpstr(WindowType,"Layout") == 0)
			gWinList 		= "new;"
			gWinSelection	= "new"
		else
			gWinList 		= "_none_;"
		endif
	else
		if (cmpstr(WindowType,"Layout") == 0)
			gWinList		= "new;" + gWinList
		endif
		if (strlen(gWinSelection) == 0)
			gWinSelection = StringFromList(0,gWinList)
		endif
	endif
	
	ControlName = WindowType+"ListMenu"
	ControlUpdate $ControlName
End

Function LayoutControlMenuProcs(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	String WindowType = ReplaceString("ListMenu",ctrlName,"")
	SVAR gWinSelection 	= $("root:Packages:Layouts:g"+WindowType+"Selection")
	
	gWinSelection = popStr
End
	
Function AddToLayout(ctrlname):ButtonControl
	String ctrlname

	String WindowType = ReplaceString("AddButton",ctrlName,"")
	SVAR gWinSelection 	= $("root:Packages:Layouts:g"+WindowType+"Selection")
	SVAR gLayoutSelection 	= $("root:Packages:Layouts:gLayoutSelection")
	
	AddWindowToLayout(gWinSelection,WindowType,gLayoutSelection)
	
	UpdateWindowLists("")
End

Function AddWindowToLayout(WinSelection,WindowType,LayoutSelection)
	String WinSelection,WindowType,LayoutSelection

	if (strlen(WinSelection) > 0)
		if (cmpstr(LayoutSelection,"new") == 0)
			NewLayout /K=1
			LayoutSelection = WinName(0, 4)
		endif
		
		if (cmpstr(WindowType,"Gizmo") == 0)
			Execute "ExportGizmo clip"
			LoadPict/Q/O "Clipboard",tempGizmoImage
			AppendLayoutObject /W=$LayoutSelection picture tempGizmoImage
			DoWindow /K tempGizmoImage
		else
			AppendLayoutObject /W=$LayoutSelection $WindowType $WinSelection
		endif
		
//		ModifyLayout
	endif
End

Function InitLayoutControl()

	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:Layouts
	
		// Global strings to select DATAFOLDER names
		MakeStringIfNeeded("gGraphList","")
		MakeStringIfNeeded("gGraphSelection","")
		
		MakeStringIfNeeded("gTableList","")
		MakeStringIfNeeded("gTableSelection","")
		
		MakeStringIfNeeded("gGizmoList","")
		MakeStringIfNeeded("gGizmoSelection","")
		
		MakeStringIfNeeded("gLayoutList","")
		MakeStringIfNeeded("gLayoutSelection","")
		
	SetDataFolder root:
End

