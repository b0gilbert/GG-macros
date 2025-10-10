#pragma rtGlobals=1		// Use modern global access method.



Proc GizmoControlPanel()
	
	InitGizmoControl()
	UpdateGizmoList()
		
	NewPanel /K=1/W=(500,50,800,500) as "Gizmo Control Panel"
	CheckWindowPosition("",500,50,800,500)
	
	PopupMenu GizmoListMenu,pos={10,25},proc=GizmoControlMenuProcs, size={282,20},title="Gizmo Window"
	PopupMenu GizmoListMenu,fSize=12,mode=1,popvalue=root:Packages:Gizmo:gGizmoSelection,value=#"root:Packages:Gizmo:gGizmoList"
	
//	Button NewLayoutButton,fSize=12,pos={243,25},size={46,16},proc=AddStructure,title="Add"

End

Function UpdateGizmoList()

	SVAR gGizmoList 		= root:Packages:Gizmo:gGizmoList
	SVAR gGizmoSelection 	= root:Packages:Gizmo:gGizmoSelection
	
	gGizmoList = WinList("*",";","WIN:4096")
	
	if (strlen(gGizmoSelection) == 0)
		gGizmoSelection = StringFromList(0,gGizmoList)
	endif
End

Function GizmoControlMenuProcs(ctrlName,popNum,popStr) : PopupMenuControl
	String ctrlName
	Variable popNum
	String popStr
	
	SVAR gGizmoSelection 	= root:Packages:Gizmo:gGizmoSelection
	
	if (cmpstr(GizmoListMenu,ctrlName) == 0)
		gGizmoSelection = popStr
	endif
End
	
Function GizmoToLayout()

//	NewLayout
End

Function InitGizmoControl()

	NewDataFolder/O/S root:Packages
	NewDataFolder/O/S root:Packages:Gizmo
	
		// Global strings to select DATAFOLDER names
		MakeStringIfNeeded("gGizmoList","")
		MakeStringIfNeeded("gGizmoSelection","")
		
	SetDataFolder root:
End

