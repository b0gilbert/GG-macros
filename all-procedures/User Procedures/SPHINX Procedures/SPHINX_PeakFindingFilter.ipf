#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.

Menu "SPHINX"
	SubMenu "Stacks"
		"Create Spectral Peak Mask", DoPeakFiltering()
	End
End

Function TestWaveInput(Wave w)
    Print "Wave dims:", DimSize(w, 0), DimSize(w, 1), DimSize(w, 2)
    return 0
End

ThreadSafe Function FindLocalMaximaBounds(Wave stackWave, Variable row, Variable col,
                               Wave outputBounds)
    Variable lvls = DimSize(stackWave, 2)
    Variable peakCount = 0
    Variable i = 1
    Variable start

    for (; i < lvls - 1 ;) // seems Igor doesn't like while loops?
        if (stackWave[row][col][i] > stackWave[row][col][i - 1])
            start = i

            // walk across plateaus
            for (; (i < lvls - 2) && (stackWave[row][col][i] == stackWave[row][col][i + 1]) ;)
                i += 1
            endfor

            if (stackWave[row][col][i] > stackWave[row][col][i + 1])
                outputBounds[peakCount][0] = start
                outputBounds[peakCount][1] = i
                peakCount += 1
            endif
        endif
        i += 1
    endfor

    return peakCount
End

ThreadSafe Function FindLeftTrough(Wave stackWave, Variable row, Variable col,
                        Variable ind)
    for (; (ind > 0) && (stackWave[row][col][ind] >= stackWave[row][col][ind - 1]) ;)
        ind -= 1
    endfor
    return ind
End

ThreadSafe Function FindRightTrough(Wave stackWave, Variable row, Variable col,
                        Variable ind)
    Variable n = DimSize(stackWave, 2)
    for (; (ind < n - 1) && (stackWave[row][col][ind] >= stackWave[row][col][ind + 1]) ;)
        ind += 1
    endfor
    return ind
End

ThreadSafe Function ComputePeakProminence(Wave stackWave, Variable row, Variable col,
                                          Variable lInd, Variable rInd)
    // we have the left and right indices for a peak/plateau
    Variable peakVal = stackWave[row][col][lInd]
    // get the surrounding trough points and measure difference
    Variable lTroughInd = FindLeftTrough(stackWave, row, col, lInd)
    Variable lTrough = stackWave[row][col][lTroughInd]
    Variable rTroughInd = FindRightTrough(stackWave, row, col, rInd)
    Variable rTrough = stackWave[row][col][rTroughInd]
    return peakVal - min(lTrough, rTrough) // the biggest height difference
End

ThreadSafe Function GetAllPeakProminencesForRows(Wave stackWave, Variable rowBeg, Variable rowEnd,
                                      Variable nCols, Variable maxPeaks, Wave prominenceWave)
    Variable i
    Variable j
    Variable k
    Variable peakCount = 0
    Variable prominence
    Variable peakL
    Variable peakR
    // create temporary wave to store bounds info for each column
    Make/FREE/U/B/N=(maxPeaks, 2) boundsWave
    for (i = rowBeg; i < rowEnd; i += 1)
        for (j = 0; j < nCols; j += 1)
            // and store the peak counts for output
            peakCount = FindLocalMaximaBounds(stackWave, i, j, boundsWave)
            // for each peak, find the prominence
            for (k = 0; k < peakCount; k += 1)
                peakL = boundsWave[k][0]
                peakR = boundsWave[k][1]
                prominence = ComputePeakProminence(stackWave, i, j, peakL, peakR)
                prominenceWave[i][j][k] = prominence
            endfor
            // and fill the remainder of elements with 0
            for (k = peakCount; k < maxPeaks; k += 1)
                prominenceWave[i][j][k] = 0
            endfor
        endfor
    endfor
End

Function GetAllPeakProminences(Wave stackWave, Wave prominenceWave)
    Variable i
    Variable rows = DimSize(stackWave, 0)
    Variable cols = DimSize(stackWave, 1)
    Variable lvls = DimSize(stackWave, 2)
    Variable maxPeaks = ceil(lvls / 2)
    
    // compute rows of prominence in parallel
    Variable nThreads = ThreadProcessorCount  // how many CPUs available
    if (nThreads < 1)
        nThreads = 1
    endif
    // create a thread group
    Variable tg = ThreadGroupCreate(nThreads)
    // compute the number of rows for each thread
    Variable rowsPerThread = ceil(rows / nThreads)
    // for each thread
    for (i = 0; i < nThreads; i += 1)
        Variable rowBeg = i * rowsPerThread
        Variable rowEnd = min(rowBeg + rowsPerThread, rows)
        // launch thread worker
        ThreadStart tg, i, GetAllPeakProminencesForRows(stackWave, rowBeg, rowEnd, cols, maxPeaks, prominenceWave)
    endfor

    Variable tgStatus = 1
    // wait for all threads to finish
    do
        tgStatus = ThreadGroupWait(tg, 100)
    while (tgStatus != 0)

    // clean up
    Variable dummy = ThreadGroupRelease(tg)
End

Function CountPeaksByProminence(Wave promWave, Wave countWave, Variable minProm)
    Variable rows = DimSize(promWave, 0)
    Variable i
    Variable cols = DimSize(promWave, 1)
    Variable j
    Variable maxPeaks = DimSize(promWave, 2)
    Variable k
    Variable currProm = 0
    Variable currCount = 0
    // for each row and column in the prominences
    for (i = 0; i < rows; i += 1)
        for (j = 0; j < cols; j += 1)
            // reset the count of prominent peaks for each pixel
            currCount = 0
            // check every peak
            for (k = 0; k < maxPeaks; k += 1)
                currProm = promWave[i][j][k]
                // check against min
                if (currProm >= minProm)
                    currCount += 1
                endif
                // seeing a 0 means we've reached the end too
                if (currProm <= 0)
                    k = maxPeaks
                endif
            endfor
            countWave[i][j] = currCount
        endfor
    endfor
End

Function MaskByProminenceCount(Wave countWave, Wave maskWave, Variable minCount)
    Variable rows = DimSize(countWave, 0)
    Variable i
    Variable cols = DimSize(countWave, 1)
    Variable j
    // for each row and column check prominent peak count
    for (i = 0; i < rows; i += 1)
        for (j = 0; j < cols; j += 1)
            // 1 if meets minCount else 0
            maskWave[i][j] = (countWave[i][j] >= minCount)
        endfor
    endfor
End

Function InitPeakFindingIfNeeded(Wave stackWave)
    // some important paths for folders and data
    String stackName = NameOfWave(stackWave)
    String peakFindFolder = "root:SPHINX:PeakFindingFilter"
    String promWavePath = peakFindFolder + ":" + "stackProminences"
    // the peak filter mask needs to adhere to a naming scheme
    // like A129_somename - this in turn needs to match the panel it
    // is displayed in, in order to be used as a mask for analysis
    String pfMaskWaveName = stackName + "_PeakFilterMask"
    String pfMaskWavePath = peakFindFolder + ":" + pfMaskWaveName
    String dupeMaskFolder = "root:SPHINX:" + pfMaskWaveName
    String dupeMaskPath = dupeMaskFolder + ":" + pfMaskWaveName
    
    // initial information about the stack
    Variable stRows = DimSize(stackWave, 0)
    Variable stCols = DimSize(stackWave, 1)
    Variable stLvls = DimSize(stackWave, 2)
    
    // create the canonical data folder
    if (!DataFolderExists(peakFindFolder))
        NewDataFolder/O $(peakFindFolder)
        // *********** NOTE ***********************
        // turns out ROI masking requires mask info
        // to be in a folder of the same name  as
        // the mask so we will add that info now to
        // another folder with a matching name
        //****************************************
        NewDataFolder /O $(dupeMaskFolder)
        String imageMinName = dupeMaskFolder+":gImageMin"
        String imageMaxName = dupeMaskFolder+":gImageMax"
        MakeVariableIfNeeded(imageMinName, 1)
        MakeVariableIfNeeded(imageMaxName, 1)
    endif
    
    // create the prominence wave to be calculated
    if (!WaveExists($promWavePath))
        // can't have more peaks than half the levels
        Variable maxPeaks = ceil(stLvls / 2)
        Make/O/N=(stRows, stCols, stLvls) $promWavePath
        Wave promWave = $promWavePath
        // now do the initial prominence calculation
        GetAllPeakProminences(stackWave, promWave)
    endif
    
    // create the mask wave
    if (!WaveExists($pfMaskWavePath))
        Make/O/U/B/N=(stRows, stCols) $pfMaskWavePath
        Wave maskWave = $pfMaskWavePath
        maskWave = 0
        Wave promWave = $promWavePath
        // and calculate an initial mask by default prominence limits
        Make/FREE/U/B/N=(stRows,stCols) promCounts
        CountPeaksByProminence(promWave, promCounts, 20)
        // and update the peak filter mask by minimum count
        MaskByProminenceCount(promCounts, maskWave, 2)
    endif
End

Function ApplyMaskParameters()
    // look up the mask - it's in the peak finding filter folder
    String maskFolder = "root:SPHINX:PeakFindingFilter"
    SVAR maskName = $(maskFolder + ":maskName") // name varies by experiment
    Wave maskWave = $(maskFolder + ":" + maskName)
    // prominence wave is just called stackProminences within that folder
    String promWavePath = maskFolder + ":stackProminences"
    Wave promWave = $(promWavePath)
    // grab the global masking parameters
    NVAR gPromMin 	= $(maskFolder+":gPromMin")
    NVAR gPeakMin 	= $(maskFolder+":gPeakMin")
    // ***recompute the mask***
    // count prominences by a limit
    Variable rows = DimSize(promWave, 0)
    Variable cols = DimSize(promWave, 1)
    Make/FREE/B/N=(rows,cols) promCounts
    CountPeaksByProminence(promWave, promCounts, gPromMin)
    // and update the peak filter mask by minimum count
    MaskByProminenceCount(promCounts, maskWave, gPeakMin)
End

Function MaskParameters(String ctrlName, Variable varNum, String varStr, String varName) : SetVariableControl
    ApplyMaskParameters()
End

Function DisplayPeakFilterPanel(Wave stackWave)
    // get inital stack wave traits
    Variable rows = DimSize(stackWave, 0)
    Variable cols = DimSize(stackWave, 1)
    String stackName = NameOfWave(stackWave)
    // and some initial names/locations
    String panelFolder = "root:SPHINX:PeakFindingFilter"
    // this needs to follow a convention for ROI image masking
    // e.g. StackA129_somename - the mask name follows similar
    String panelName   = "Stack" + stackName + "_PeakFilterMask"
    String title       = "PeakFilterMask"
    // grab the mask wave too
    // the mask itself needs to match the panel name without Stack
    // on the front in order to use for ROI image masking
    String maskName = stackName + "_PeakFilterMask"
    String maskPath = panelFolder + ":" + maskName
    Wave maskWave = $maskPath

    String oldDf = GetDataFolder(1)
    SetDataFolder $(panelFolder)

    DoWindow /K $panelName
    NewPanel /K=1/W=(6,44,440,520) as title
    Dowindow /C $panelName
    CheckWindowPosition(panelName,6,44,440,520)

    Display/W=(7,111,419,441)/HOST=#
    AppendImage maskWave
    ModifyImage $maskName ctab= {0,1,Grays,0}
    ModifyGraph mirror=2
    RenameWindow #, StackImage
    
    // add the transfer controls
    Button TransferCrsButton,pos={220,448}, size={25,18},fSize=13,proc=TransferImageCsrs,title="\\W642"
    Button TransferZoomButton,pos={250,448}, size={25,18},fSize=13,proc=TransferImageZoom,title="\\W605"
    // and add the cursors on the mask itself
    AppendCursors(maskName,panelName,"StackImage",panelFolder,rows,cols,450,0)
    
    // add prominence and peak controls with defaults
    String promMinName = panelFolder+":gPromMin"
    String peakMinName = panelFolder+":gPeakMin"
    MakeVariableIfNeeded(promMinName, 20)
    MakeVariableIfNeeded(peakMinName, 2)
    NVAR gPromMin 	= $(promMinName)
    NVAR gPeakMin 	= $(peakMinName)
    GroupBox PromGroup title="Mask Parameters",pos={5,0},size={150,81},fColor=(39321,1,1)
    SetVariable PromMinSetVar,title="Min Prominence",pos={12,36},limits={0,Inf,1},size={140,17},fsize=12,proc=MaskParameters,value=gPromMin
    SetVariable PeakMinSetVar,title="Min Peaks",pos={12,58},limits={0,Inf,1},size={140,17},fsize=12,proc=MaskParameters,value=gPeakMin
    
    // add various control hooks
    //SetWindow $panelName, hook(PanelCloseHook)=KillPanelHooks
    SetWindow $panelName, hook(PanelKeyHooks)=ImageDisplayHooks, hookevents=4

    // create some more global variables to store needed info
    MakeStringIfNeeded(panelFolder+":maskName", maskName)
    MakeStringIfNeeded(panelFolder+":subWName", panelName+"#StackImage")
    
    // actually need to store some variables in userdata for cursor functions
    SetWindow $panelName,userdata  = "PanelFolder="+panelFolder+";"
    SetWindow $panelName,userdata += "subWName="+panelName+"#StackImage;"
    SetWindow $panelName,userdata += "ImageName="+maskName+";"
    SetWindow $panelName,userdata += "ImageFolder="+panelFolder+";"

    SetDataFolder $(oldDf)
End

Function DoPeakFiltering()
    String stackFolder = "root:SPHINX:Stacks"
    // first pull the stack we're working with
    String stackList = ReturnStackList(stackFolder)
    String stackName = StringFromList(0, stackList, ";")
    Wave stackWave = $(stackFolder + ":" + stackName)
    // initialize needed data and folders
    InitPeakFindingIfNeeded(stackWave)
    // get stack dimensions
    DisplayPeakFilterPanel(stackWave)
End