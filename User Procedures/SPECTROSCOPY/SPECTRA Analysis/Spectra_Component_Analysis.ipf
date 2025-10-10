// Created 12.08.2014 16:31
// Updated 03.12.2015 09:28

#pragma rtGlobals=1		// Use modern global access method.

Function DisplayComponentAnalysisPanel()

	String Title = "Component Analysis"
	String PanelName = "CompAnalysis"
	String PanelFolder = "root:SPHINX:ComponentAnalysis"

	NewDataFolder /O/S $PanelFolder

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,360,135) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,360,135)

		Button CreateRGBMap,pos={5,5}, size={150,25},fSize=13,proc=ComponentAnalysisButtons,title="Create RGB Map"
		Button CreateRGBMapMasked,pos={160,5}, size={60,25},fSize=13,proc=ComponentAnalysisButtons,title="Masked"
		Button CreateRGBMapBE,pos={225,5}, size={40,25},fSize=13,proc=ComponentAnalysisButtons,title="BE"
		Button CreateRGBMapBEMasked,pos={270,5}, size={80,25},fSize=13,proc=ComponentAnalysisButtons,title="BE Masked"

		Button CreateRGBYMap,pos={5,35}, size={150,25},fSize=13,proc=ComponentAnalysisButtons,title="Create RGBY Map"
		Button CreateRGBYMapMasked,pos={160,35}, size={60,25},fSize=13,proc=ComponentAnalysisButtons,title="Masked"
		Button CreateRGBYMapBE,pos={225,35}, size={40,25},fSize=13,proc=ComponentAnalysisButtons,title="BE"
		Button CreateRGBYMapBEMasked,pos={270,35}, size={80,25},fSize=13,proc=ComponentAnalysisButtons,title="BE Masked"

		MakeVariableIfNeeded(PanelFolder+":Comp0",0)
		SetVariable Comp0,title="Components:     R",pos={5,65},limits={0,65535,1},size={145,25},fsize=13,value=$("root:SPHINX:ComponentAnalysis:Comp0")
		MakeVariableIfNeeded(PanelFolder+":Comp1",1)
		SetVariable Comp1,title="G",pos={155,65},limits={0,65535,1},size={50,25},fsize=13,value=$("root:SPHINX:ComponentAnalysis:Comp1")
		MakeVariableIfNeeded(PanelFolder+":Comp2",2)
		SetVariable Comp2,title="B",pos={215,65},limits={0,65535,1},size={50,25},fsize=13,value=$("root:SPHINX:ComponentAnalysis:Comp2")
		MakeVariableIfNeeded(PanelFolder+":Comp3",3)
		SetVariable Comp3,title="Y",pos={275,65},limits={0,65535,1},size={50,25},fsize=13,value=$("root:SPHINX:ComponentAnalysis:Comp3")

End

Function CreateRGBMap()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	Variable i, j, k

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))

		if (!waveExists(pmap0))
			print "Missing image " + StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0)
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image " + StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1)
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image " + StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2)
			return 0
		endif

		WAVE /D RGB_Map = $(StackFolder+":RGB_Map")
		if (!waveExists(RGB_Map))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGB_Map") /WAVE = RGB_Map
			RGB_Map = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				RGB_Map[i][j][0] = pmap0[i][j] * 66535
				RGB_Map[i][j][1] = pmap1[i][j] * 66535
				RGB_Map[i][j][2] = pmap2[i][j] * 66535

				for (k = 0; k < 3; k +=1)
					RGB_Map[i][j][k] = (RGB_Map[i][j][k] > 65535) ? 65535 : RGB_Map[i][j][k]
					RGB_Map[i][j][k] = (RGB_Map[i][j][k] < 0) ? 0 : RGB_Map[i][j][k]
				endfor

			endfor
		endfor

		RGBMapDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBMapMasked()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	Variable i, j, k

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE mask = $(StackFolder + ":" + gStackName + "_Map_mask")

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(mask))
			print "no mask"
			return 0
		endif

		WAVE /D RGB_Map_Masked = $(StackFolder+":RGB_Map_Masked")
		if (!waveExists(RGB_Map))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGB_Map_Masked") /WAVE = RGB_Map_Masked
			RGB_Map_Masked = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				RGB_Map_Masked[i][j][0] = pmap0[i][j] * 66535
				RGB_Map_Masked[i][j][1] = pmap1[i][j] * 66535
				RGB_Map_Masked[i][j][2] = pmap2[i][j] * 66535

				for (k=0; k < 3; k+=1)
					RGB_Map_Masked[i][j][k] = (RGB_Map_Masked[i][j][k] > 65535) ? 65535 : RGB_Map_Masked[i][j][k]
					RGB_Map_Masked[i][j][k] = (RGB_Map_Masked[i][j][k] < 0) ? 0 : RGB_Map_Masked[i][j][k]
					RGB_Map_Masked[i][j][k] = (mask[i][j] != 0) ? 0 : RGB_Map_Masked[i][j][k]
				endfor

			endfor
		endfor

		RGBMapMaskedDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBMapBE()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	Variable i, j, k, scaleFactor

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif

		WAVE /D RGB_Map_BE = $(StackFolder+":RGB_Map_BE")
		if (!waveExists(RGB_Map_BE))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGB_Map_BE") /WAVE = RGB_Map_BE
			RGB_Map_BE = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				scaleFactor = 65535 / max(pmap0[i][j], max(pmap1[i][j], pmap2[i][j]))
				RGB_Map_BE[i][j][0] = pmap0[i][j] * scaleFactor
				RGB_Map_BE[i][j][1] = pmap1[i][j] * scaleFactor
				RGB_Map_BE[i][j][2] = pmap2[i][j] * scaleFactor

				for (k=0; k < 3; k+=1)
					RGB_Map_BE[i][j][k] = (RGB_Map_BE[i][j][k] > 65535) ? 65535 : RGB_Map_BE[i][j][k]
					RGB_Map_BE[i][j][k] = (RGB_Map_BE[i][j][k] < 0) ? 0 : RGB_Map_BE[i][j][k]
				endfor

			endfor
		endfor

		RGBMapBEDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBMapBEMasked()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	Variable i, j, k, scaleFactor

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE mask = $(StackFolder + ":" + gStackName + "_Map_mask")

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(mask))
			print "no mask"
			return 0
		endif

		WAVE /D RGB_Map_BE_Masked = $(StackFolder+":RGB_Map_BE_Masked")
		if (!waveExists(RGB_Map_BE_Masked))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGB_Map_BE_Masked") /WAVE = RGB_Map_BE_Masked
			RGB_Map_BE_Masked = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				scaleFactor = 65535 / max(pmap0[i][j], max(pmap1[i][j], pmap2[i][j]))
				RGB_Map_BE_Masked[i][j][0] = pmap0[i][j] * scaleFactor
				RGB_Map_BE_Masked[i][j][1] = pmap1[i][j] * scaleFactor
				RGB_Map_BE_Masked[i][j][2] = pmap2[i][j] * scaleFactor

				for (k=0; k < 3; k+=1)
					RGB_Map_BE_Masked[i][j][k] = (RGB_Map_BE_Masked[i][j][k] > 65535) ? 65535 : RGB_Map_BE_Masked[i][j][k]
					RGB_Map_BE_Masked[i][j][k] = (RGB_Map_BE_Masked[i][j][k] < 0) ? 0 : RGB_Map_BE_Masked[i][j][k]
					RGB_Map_BE_Masked[i][j][k] = (mask[i][j] != 0) ? 0 : RGB_Map_BE_Masked[i][j][k]
				endfor

			endfor
		endfor

		RGBMapBEMaskedDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBYMap()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	NVAR Comp3 = $(PanelFolder+":Comp3")
	Variable i, j, k

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE pmap3 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp3))

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(pmap3))
			print "Missing image pMap_3"
			return 0
		endif

		WAVE /D RGBY_Map = $(StackFolder+":RGBY_Map")
		if (!waveExists(RGBY_Map))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGBY_Map") /WAVE = RGBY_Map
			RGBY_Map = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				RGBY_Map[i][j][0] = pmap0[i][j] * 66535 + pmap3[i][j] * 65535
				RGBY_Map[i][j][1] = pmap1[i][j] * 66535 + pmap3[i][j] * 65535
				RGBY_Map[i][j][2] = pmap2[i][j] * 66535

				for (k=0; k < 3; k+=1)
					RGBY_Map[i][j][k] = (RGBY_Map[i][j][k] > 65535) ? 65535 : RGBY_Map[i][j][k]
					RGBY_Map[i][j][k] = (RGBY_Map[i][j][k] < 0) ? 0 : RGBY_Map[i][j][k]
				endfor

			endfor
		endfor

		RGBYMapDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBYMapMasked()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	NVAR Comp3 = $(PanelFolder+":Comp3")
	Variable i, j, k

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE pmap3 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp3))
		WAVE mask = $(StackFolder + ":" + gStackName + "_Map_mask")

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(pmap3))
			print "Missing image pMap_3"
			return 0
		endif
		if (!waveExists(mask))
			print "no mask"
			return 0
		endif

		WAVE /D RGBY_Map_Masked = $(StackFolder+":RGBY_Map_Masked")
		if (!waveExists(RGBY_Map_Masked))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGBY_Map_Masked") /WAVE = RGBY_Map_Masked
			RGBY_Map_Masked = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				RGBY_Map_Masked[i][j][0] = pmap0[i][j] * 66535 + pmap3[i][j] * 65535
				RGBY_Map_Masked[i][j][1] = pmap1[i][j] * 66535 + pmap3[i][j] * 65535
				RGBY_Map_Masked[i][j][2] = pmap2[i][j] * 66535

				for (k=0; k < 3; k+=1)
					RGBY_Map_Masked[i][j][k] = (RGBY_Map_Masked[i][j][k] > 65535) ? 65535 : RGBY_Map_Masked[i][j][k]
					RGBY_Map_Masked[i][j][k] = (RGBY_Map_Masked[i][j][k] < 0) ? 0 : RGBY_Map_Masked[i][j][k]
					RGBY_Map_Masked[i][j][k] = (mask[i][j] != 0) ? 0 : RGBY_Map_Masked[i][j][k]
				endfor

			endfor
		endfor

		RGBYMapMaskedDisplayPanel()

	else
		print "no stack exists"
	endif

End

Function CreateRGBYMapBE()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	NVAR Comp3 = $(PanelFolder+":Comp3")
	Variable i, j, k, scaleFactor

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE pmap3 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp3))

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(pmap3))
			print "Missing image pMap_3"
			return 0
		endif

		WAVE /D RGBY_Map_BE = $(StackFolder+":RGBY_Map_BE")
		if (!waveExists(RGBY_Map_BE))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGBY_Map_BE") /WAVE = RGBY_Map_BE
			RGBY_Map_BE = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				scaleFactor = 65535 / max(pmap0[i][j], max(pmap1[i][j], max(pmap2[i][j], pmap3[i][j])))
				RGBY_Map_BE[i][j][0] = pmap0[i][j] * scaleFactor + pmap3[i][j] * scaleFactor
				RGBY_Map_BE[i][j][1] = pmap1[i][j] * scaleFactor + pmap3[i][j] * scaleFactor
				RGBY_Map_BE[i][j][2] = pmap2[i][j] * scaleFactor

				for (k=0; k < 3; k+=1)
					RGBY_Map_BE[i][j][k] = (RGBY_Map_BE[i][j][k] > 65535) ? 65535 : RGBY_Map_BE[i][j][k]
					RGBY_Map_BE[i][j][k] = (RGBY_Map_BE[i][j][k] < 0) ? 0 : RGBY_Map_BE[i][j][k]
				endfor

			endfor
		endfor

		RGBYMapBEDisplayPanel()

	else
		print "no stack exists"
	endif
End

Function CreateRGBYMapBEMasked()

	String PanelFolder	= "root:SPHINX:ComponentAnalysis"
	String StackFolder	= "root:SPHINX:Stacks"
	SVAR gStackName	= root:SPHINX:Browser:gStackName

	NVAR Comp0 = $(PanelFolder+":Comp0")
	NVAR Comp1 = $(PanelFolder+":Comp1")
	NVAR Comp2 = $(PanelFolder+":Comp2")
	NVAR Comp3 = $(PanelFolder+":Comp3")
	Variable i, j, k, scaleFactor

	WAVE SPHINXStack	= $("root:SPHINX:Stacks:"+gStackName)
	if (WaveExists(SPHINXStack) == 1) 

		Variable NumX = Dimsize(SPHINXStack,0)
		Variable NumY = Dimsize(SPHINXStack,1)

		WAVE pmap0 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp0))
		WAVE pmap1 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp1))
		WAVE pmap2 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp2))
		WAVE pmap3 = $(StackFolder + ":" + gStackName + "_pMap_" + num2str(Comp3))
		WAVE mask = $(StackFolder + ":" + gStackName + "_Map_mask")

		if (!waveExists(pmap0))
			print "Missing image pMap_0"
			return 0
		endif
		if (!waveExists(pmap1))
			print "Missing image pMap_1"
			return 0
		endif
		if (!waveExists(pmap2))
			print "Missing image pMap_2"
			return 0
		endif
		if (!waveExists(pmap3))
			print "Missing image pMap_3"
			return 0
		endif
		if (!waveExists(mask))
			print "no mask"
			return 0
		endif

		WAVE /D RGBY_Map_BE_Masked = $(StackFolder+":RGBY_Map_BE_Masked")
		if (!waveExists(RGBY_Map_BE_Masked))
			Make /O/N=(NumX, NumY, 3)/D $(StackFolder+":RGBY_Map_BE_Masked") /WAVE = RGBY_Map_BE_Masked
			RGBY_Map_BE_Masked = NaN
		endif

		for (i = 0; i < NumX; i+=1)
			for (j = 0; j < NumY; j+=1)
				scaleFactor = 65535 / max(pmap0[i][j], max(pmap1[i][j], max(pmap2[i][j], pmap3[i][j])))
				RGBY_Map_BE_Masked[i][j][0] = pmap0[i][j] * scaleFactor + pmap3[i][j] * scaleFactor
				RGBY_Map_BE_Masked[i][j][1] = pmap1[i][j] * scaleFactor + pmap3[i][j] * scaleFactor
				RGBY_Map_BE_Masked[i][j][2] = pmap2[i][j] * scaleFactor

				for (k=0; k < 3; k+=1)
					RGBY_Map_BE_Masked[i][j][k] = (RGBY_Map_BE_Masked[i][j][k] > 65535) ? 65535 : RGBY_Map_BE_Masked[i][j][k]
					RGBY_Map_BE_Masked[i][j][k] = (RGBY_Map_BE_Masked[i][j][k] < 0) ? 0 : RGBY_Map_BE_Masked[i][j][k]
					RGBY_Map_BE_Masked[i][j][k] = (mask[i][j] != 0) ? 0 : RGBY_Map_BE_Masked[i][j][k]
				endfor

			endfor
		endfor

		RGBYMapBEMaskedDisplayPanel()

	else
		print "no stack exists"
	endif
End

Function /S RGBMapDisplayPanel()

	Wave RGB_Map = root:SPHINX:Stacks:RGB_Map

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGB"
	String PanelName = "RGBMap"
	String StackName = NameOfWave(RGB_Map)
	String title = gStackName + " RGB Map"

	Variable NumX = Dimsize(RGB_Map,0)
	Variable NumY = Dimsize(RGB_Map,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGB_Map, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGB_Map
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGB_Map)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGB_Map,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBMapMaskedDisplayPanel()

	Wave RGB_Map_Masked = root:SPHINX:Stacks:RGB_Map_Masked

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGB_Masked"
	String PanelName = "RGBMapMasked"
	String StackName = NameOfWave(RGB_Map_Masked)
	String title = gStackName + " RGB Map Masked"

	Variable NumX = Dimsize(RGB_Map_Masked,0)
	Variable NumY = Dimsize(RGB_Map_Masked,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGB_Map_Masked, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGB_Map_Masked
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBMaskedImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGB_Map_Masked)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGB_Map_Masked,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBMapBEDisplayPanel()

	Wave RGB_Map_BE = root:SPHINX:Stacks:RGB_Map_BE

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGB_BE"
	String PanelName = "RGBMapBE"
	String StackName = NameOfWave(RGB_Map_BE)
	String title = gStackName + " RGB Map BE"

	Variable NumX = Dimsize(RGB_Map_BE,0)
	Variable NumY = Dimsize(RGB_Map_BE,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGB_Map_BE, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGB_Map_BE
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBBEImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGB_Map_BE)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGB_Map_BE,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBMapBEMaskedDisplayPanel()

	Wave RGB_Map_BE_Masked = root:SPHINX:Stacks:RGB_Map_BE_Masked

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGB_BE_Masked"
	String PanelName = "RGBMapBEMasked"
	String StackName = NameOfWave(RGB_Map_BE_Masked)
	String title = gStackName + " RGB Map BE Masked"

	Variable NumX = Dimsize(RGB_Map_BE_Masked,0)
	Variable NumY = Dimsize(RGB_Map_BE_Masked,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGB_Map_BE_Masked, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGB_Map_BE_Masked
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBBEMaskedImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGB_Map_BE_Masked)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGB_Map_BE_Masked,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBYMapDisplayPanel()

	Wave RGBY_Map = root:SPHINX:Stacks:RGBY_Map

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGBY"
	String PanelName = "RGBYMap"
	String StackName = NameOfWave(RGBY_Map)
	String title = gStackName + " RGBY Map"

	Variable NumX = Dimsize(RGBY_Map,0)
	Variable NumY = Dimsize(RGBY_Map,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGBY_Map, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGBY_Map
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBYImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGBY_Map)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGBY_Map,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBYMapMaskedDisplayPanel()

	Wave RGBY_Map_Masked = root:SPHINX:Stacks:RGBY_Map_Masked

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGBY_Masked"
	String PanelName = "RGBYMapMasked"
	String StackName = NameOfWave(RGBY_Map_Masked)
	String title = gStackName + " RGBY Map Masked"

	Variable NumX = Dimsize(RGBY_Map_Masked,0)
	Variable NumY = Dimsize(RGBY_Map_Masked,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGBY_Map_Masked, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGBY_Map_Masked
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBYMaskedImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGBY_Map_Masked)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGBY_Map_Masked,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBYMapBEDisplayPanel()

	Wave RGBY_Map_BE = root:SPHINX:Stacks:RGBY_Map_BE

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGBY_BE"
	String PanelName = "RGBYMapBE"
	String StackName = NameOfWave(RGBY_Map_BE)
	String title = gStackName + " RGBY Map BE"

	Variable NumX = Dimsize(RGBY_Map_BE,0)
	Variable NumY = Dimsize(RGBY_Map_BE,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGBY_Map_BE, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGBY_Map_BE
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBYBEImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGBY_Map_BE)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGBY_Map_BE,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function /S RGBYMapBEMaskedDisplayPanel()

	Wave RGBY_Map_BE_Masked = root:SPHINX:Stacks:RGBY_Map_BE_Masked

	SVAR gStackName = root:SPHINX:Browser:gStackName
	String PanelFolder = "root:SPHINX:RGBY_BE_Masked"
	String PanelName = "RGBYMapBEMasked"
	String StackName = NameOfWave(RGBY_Map_BE_Masked)
	String title = gStackName + " RGBY Map BE Masked"

	Variable NumX = Dimsize(RGBY_Map_BE_Masked,0)
	Variable NumY = Dimsize(RGBY_Map_BE_Masked,1)

	NewDataFolder /O/S $PanelFolder

		Duplicate /O RGBY_Map_BE_Masked, BlankImage
		BlankImage = 125

		DoWindow /K $PanelName
		NewPanel /K=1/W=(6,44,440,520) as Title
		DoWindow /C $PanelName
		CheckWindowPosition(PanelName,6,44,440,520)

		Display/W=(7, 111, 419, 441)/HOST=#
		AppendImage BlankImage
		ModifyImage BlankImage ctab = {1,200,Yellow,0}

		AppendImage RGBY_Map_BE_Masked
		ModifyGraph mirror=2
		RenameWindow #, StackImage

		AppendCursors(StackName,PanelName,"StackImage",PanelFolder,NumX,NumY,450)
//		NewAppendContrastControls(PanelName)

		// Permit saving for images or stacks
		Button RGBYBEMaskedImageSaveButton,pos={5,80}, size={55,24},fSize=13,proc=ComponentAnalysisButtons,title="Export"
		Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
		Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"

		SetWindow $PanelName, hook(PanelCloseHook)=KillPanelHooks
		SetWindow $PanelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4
		
		// Give this panel all the information it needs about the displayed image
		SetWindow $PanelName,userdata= "PanelFolder="+PanelFolder+";"
		SetWindow $PanelName,userdata+= "subWName="+PanelName+"#StackImage;"
		SetWindow $PanelName,userdata+= "ImageName="+NameOfWave(RGBY_Map_BE_Masked)+";"
		SetWindow $PanelName,userdata+= "ImageFolder="+GetWavesDataFolder(RGBY_Map_BE_Masked,1)+";"
		SetWindow $PanelName,userdata+= "ImageNumX="+num2str(NumX)+";"
		SetWindow $PanelName,userdata+= "ImageNumY="+num2str(NumY)+";"
End

Function ComponentAnalysisButtons(B_Struct)
	STRUCT WMButtonAction &B_Struct

	String ctrlName = B_Struct.ctrlName
	String WindowName = B_Struct.win

	Variable eventCode = B_Struct.eventCode
	if (eventCode != 2)
		return 0	// Mouse up after pressing
	endif
	
	SVAR gStackName = root:SPHINX:Browser:gStackName

	if (cmpstr(ctrlName,"CreateRGBMap") == 0)
		CreateRGBMap()
	elseif (cmpstr(ctrlName,"CreateRGBMapMasked") == 0)
		CreateRGBMapMasked()
	elseif (cmpstr(ctrlName,"CreateRGBMapBE") == 0)
		CreateRGBMapBE()
	elseif (cmpstr(ctrlName,"CreateRGBMapBEMasked") == 0)
		CreateRGBMapBEMasked()
	elseif (cmpstr(ctrlName,"CreateRGBYMap") == 0)
		CreateRGBYMap()
	elseif (cmpstr(ctrlName,"CreateRGBYMapMasked") == 0)
		CreateRGBYMapMasked()
	elseif (cmpstr(ctrlName,"CreateRGBYMapBE") == 0)
		CreateRGBYMapBE()
	elseif (cmpstr(ctrlName,"CreateRGBYMapBEMasked") == 0)
		CreateRGBYMapBEMasked()
		
	elseif (cmpstr(ctrlName, "RGBImageSaveButton") == 0)
		ExportComponentRGBMap(gStackName,"RGB_Map")
//		String rgb_name = gStackName + "_RGB_Map"
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGB_Map rgb_name
		
	elseif (cmpstr(ctrlName, "RGBMaskedImageSaveButton") == 0)
		ExportComponentRGBMap(gStackName,"RGB_Map_masked")
//		String rgb_masked_name = gStackName + "_RGB_Map_masked"
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGB_Map_Masked rgb_masked_name
		
	elseif (cmpstr(ctrlName, "RGBBEImageSaveButton") == 0)
		ExportComponentRGBMap(gStackName,"RGB_Map_BE")
//		String rgb_be_name = gStackName + "_RGB_Map_BE"
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGB_Map_BE rgb_be_name
		
	elseif (cmpstr(ctrlName, "RGBBEMaskedImageSaveButton") == 0)
		ExportComponentRGBMap(gStackName,"RGB_Map_BE_masked")
//		String rgb_be_masked_name = gStackName + "_RGB_Map_BE_masked"
//		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGB_Map_BE_Masked rgb_be_masked_name
		
		
	elseif (cmpstr(ctrlName, "RGBYImageSaveButton") == 0)
		String rgby_name = gStackName + "_RGBY_Map"
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGBY_Map rgby_name
		
	elseif (cmpstr(ctrlName, "RGBYMaskedImageSaveButton") == 0)
		String rgby_masked_name = gStackName + "_RGBY_Map_masked"
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGBY_Map_Masked rgby_masked_name
		
	elseif (cmpstr(ctrlName, "RGBYBEImageSaveButton") == 0)
		String rgby_be_name = gStackName + "_RGBY_Map_BE"
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGBY_Map_BE rgby_be_name
		
	elseif (cmpstr(ctrlName, "RGBYBEMaskedImageSaveButton") == 0)
		String rgby_be_masked_name = gStackName + "_RGBY_Map_BE_masked"
		ImageSave /U/D=32/T="tiff" root:SPHINX:Stacks:RGBY_Map_BE_Masked rgby_be_masked_name
	endif

End



// !*!*!* BGilbert 2021-06-01
Function ExportGrayScalePMaps(gStackName)
	String gStackName
	Variable pMax

	String exportName
	Variable i
	
	for (i=0;i<pMax;i+=1)
		exportName 	= ""
	
	endfor

End

Function ExportComponentRGBMap(StackName,RGBName)
	String StackName,RGBName
	
	String FolderFile = "root:SPHINX:Stacks:"+RGBName
	String FileName = StackName+"_"+RGBName
	
	if (WaveExists($FolderFile))
		ImageSave /U/D=32/T="tiff" $FolderFile fileName
	endif

End




// 		Exporting the RGB as CMY looks awful! 	
//		rgb_be_name = gStackName + "_RGB_Map_BE.tiff"
//		SavePICT /C=1/E=-7 /WIN=$("RGBMapBE#StackImage")  as rgb_be_name
//		rgb_be_name = gStackName + "_CMY_Map_BE.tiff"
//		SavePICT /C=2/E=-7 /WIN=$("RGBMapBE#StackImage")  as rgb_be_name