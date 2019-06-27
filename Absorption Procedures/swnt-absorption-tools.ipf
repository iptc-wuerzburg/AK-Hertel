#pragma rtGlobals=3		// Use modern global access method and strict wave access.

//Change this path to your prefered Folder to allow for quick folder and file selection
Static strConstant str_PreferedPath = "C:Users:flo12af:Florian Oberndorfer:Promotion:Daten:Absorptionsspektroskopie:"

//adapted function GetListOfFolderCont() from http://www.entorb.net/wickie/IGOR_Pro
Function /S GetListOfFolderCont(objectType)
	Variable objectType //1==Waves, 2==Vars, 3==Strings, 4==Folders
	//local variables
	String strSourceFolder, strList
	Variable i
	
	//init
	strSourceFolder = GetDataFolder(1) //":" is already added at the end of the string
	strList = ""
	
	//get List
	for(i=0;i<CountObjects(strSourceFolder, objectType ); i+=1)
		strList += strSourceFolder + GetIndexedObjName(strSourceFolder, objectType, i )+";"
	endFor
	
	return strList
End

//adapted function PopUpChooseFolder() from http://www.entorb.net/wickie/IGOR_Pro 
Function/S PopUpChooseFolder()
	//init local var
	String strSaveDataFolder, strList, strFolders
	
	//Save current DataFolder
	strSaveDataFolder = GetDataFolder(1)	
	//Move to root	
	SetDataFolder root:
	//Get List of Folders in root and add root foler
	strList = GetListOfFolderCont(4)
	strList = "root:;" + strList
	strFolders = "root:"
	Prompt strFolders,"Folder",popup,strList
	DoPrompt "",strFolders
	if (V_Flag == 1) 
		strFolders="" //return ""
	endif 
	//Move back to Old Data Folder
	SetDataFolder $strSaveDataFolder	
	Return strFolders
End


Function/S PopUpChooseWave(strDataFolder, [strText])
	String strDataFolder, strText
	strText = selectstring(paramIsDefault(strText), strText, "choose wave")
	//init local var
	String strSaveDataFolder, strList, strWave
	
	//Save current DataFolder
	strSaveDataFolder = GetDataFolder(1)	
	//Move to root	
	SetDataFolder $strDataFolder
	//Get List of Waves in root and add root foler
	strList = GetListOfFolderCont(1)

	Prompt strWave,strText,popup,strList
	DoPrompt "",strWave
	if (V_Flag == 1) 
		strWave=""//return ""
	endif 
	//Move back to Old Data Folder
	SetDataFolder $strSaveDataFolder	
	Return strWave
End

//adapted from function OpenFileDialog on http://www.entorb.net/wickie/IGOR_Pro
Function/S PopUpChooseFile([strPrompt])
	String strPrompt
	strPrompt = selectstring(paramIsDefault(strPrompt), strPrompt, "choose file")
	
	Variable refNum
	String outputPath
	String fileFilters = "Delimited Text Files (*.csv,*.txt,*.ibw):.csv,.txt,.ibw;"

	//Browse to Absorption-Folder
	String strPath = str_PreferedPath
	//String strPath = "C:Users:mak24gg:Documents:RAW:Absorption:"
	NewPath/O/Q path, strPath
	PathInfo/S path
	
	Open/D/F=fileFilters/R/M=strPrompt refNum
	outputPath = S_fileName
	return outputPath
End 



Function/S PopUpChooseDirectory()
	//Go to Base Path
	String strPath = str_PreferedPath
	NewPath/O/Q path, strPath
	PathInfo/S path
	//Open Dialog Box for choosing path
	NewPath/M="choose Folder"/O/Q path
	PathInfo path
	strPath = S_path
	GetFileFolderInfo/Q/Z=1 strPath

	if (V_isFolder)
		return strPath
	else
		return ""
	endif
End

Function/S PopUpChooseFileFolder([strPrompt])
	String strPrompt
	strPrompt = selectstring(paramIsDefault(strPrompt), strPrompt, "choose file")
	String strPath, strFiles, strFile	
	
	strPath = PopUpChooseDirectory()
	NewPath/O/Q path, strPath
	strFiles = IndexedFile(path,-1,".csv")
	if (strlen(strFiles)==0)
		print "No Files in selected Folder"
		return ""
	endif
	
	Prompt strFile,strPrompt,popup,strFiles
	DoPrompt "",strFile
	if (V_Flag == 1) 
		return ""
	endif
	
	return (strPath + strFile)
End

Function/S GetWave([strPrompt])
	String strPrompt
	//This Function basically tests the String for convertability to a wave reference.
	String strWave = PopUpChooseWave(PopUpChooseFolder(), strText=strPrompt)
	wave wavWave = $strWave
	if (WaveExists(wavWave))
	//if (stringmatch(GetWavesDataFolder(wavWave, 2), strWave))
		return strWave
	else
		return ""
	endif
End

Function DisplayWave()
	wave wavWave = $GetWave(strPrompt="test")
	if (WaveExists(wavWave))
		display wavWave
	endif
End

Function/S SetWaveScale([strX, strY, strXUnit strYUnit])
	String strX, strY, strXUnit, strYUnit
	strX	= selectstring(paramIsDefault(strX), strX, "")
	strY	= selectstring(paramIsDefault(strY), strY, "")
	strXUnit	= selectstring(paramIsDefault(strXUnit), strXUnit, "")	
	strYUnit	= selectstring(paramIsDefault(strYUnit), strYUnit, "")		

	//local Variables
	String strDirectory
	String strScaledWave = "", strDeltaWave = ""
	Wave wavX, wavY
	Variable numSize, numOffset, numDelta, numEnd
	Variable i

	//strDirectory = PopUpChooseFolder()
	strDirectory = "root:"	//by now, function only works in root directory.
	if (stringmatch(strX,""))
		strX=PopUpChooseWave(strDirectory, strText="choose x wave")
	endif
	if (stringmatch(strY,""))
		strY=PopUpChooseWave(strDirectory, strText="choose y wave")
	endif	

	if (!waveExists($strX) && !waveExists($strY))
		print "Error: Waves do not exist or user cancelled at Prompt"
		return ""
	endif
	
	wave wavX 	= $strX
	wave wavY 	= $strY
	

	numSize		= DimSize(wavX,0)
	numOffset	= wavX[0]
	numEnd 		= wavX[(numSize-1)]
	
	// calculate numDelta
	strDeltaWave = nameofwave(wavY) + "_Delta"
	Make/O/N=(numSize-1) $strDeltaWave
	wave wavDeltaWave = $strDeltaWave	
	// extract delta values in wave
	for (i=0; i<(numSize-1); i+=1)
		wavDeltaWave[i] = (wavX[(i+1)] - wavX[i])
	endfor
	WaveStats/Q/W wavDeltaWave
	KillWaves/Z  wavDeltaWave
	wave M_WaveStats
	numDelta = M_WaveStats[3]
	//if X-Wave is not equally spaced, set the half minimum delta at all points.
	// controll by calculating statistical error 2*sigma/rms
	if ((2*M_WaveStats[4]/M_WaveStats[5]*100)>5)
		print "SetWaveScale: Wave is not equally spaced. Setting new Delta."
		print "SetWaveScale: Report this if it happens. Maybe numDelta is not Correct."
		// avg - 2 * sdev
		if (M_WaveStats[3] > 0)
			numDelta = M_WaveStats[3] - 2 * M_WaveStats[4]
		else
			numDelta = M_WaveStats[3] + 2 * M_WaveStats[4]
		endif
	endif
	numSize = ceil(abs((numEnd - numOffset)/numDelta)+1)
	KillWaves/Z  M_WaveStats
	
	// interpolate to new Wave.
	
	// alternative solution:
	//	interpolate can also take /N=(numSize) flag without the l=3 
	//	specify Y=newWave as the new wavename without the need to create the wave prior to call
	//	interpolate2/N=(numSize)/Y=wavScaledWave wavX,wavY
	strScaledWave = nameofwave(wavY) + "_L"	
	Make/O/N=(numSize) $strScaledWave	
	wave wavScaledWave = $strScaledWave	
	//alternative solution: SetScale/P x, numOffset, numDelta, strXUnit, wavScaledWave
	SetScale/I x, numOffset, numEnd, strXUnit, wavScaledWave
	SetScale/P y, 1, 1, strYUnit, wavScaledWave	
	interpolate2/I=3/T=1/Y=wavScaledWave wavX,wavY
	
	return nameofwave(wavScaledWave)
End

Function RemoveWaveScale(wavWave)
	Wave wavWave
	Variable numXOffset, numXDelta, numYOffset, numYDelta
	String strXUnit, strYUnit
	
	strXUnit = ""
	strYUnit = ""
	numYOffset = DimOffset(wavWave,1)
	numXOffset = DimOffset(wavWave,0)
	numYDelta = DimDelta(wavWave,1)
	numXDelta = DimDelta(wavWave,0)
	SetScale/P x, numXOffset, numXDelta, strXUnit, wavWave
	SetScale/P y, numYOffset, numYDelta, strYUnit, wavWave
End

// See WM's CheckDisplayed
Function AbsorptionIsWaveInGraph(search)
	Wave search
	
	String currentTraces
	Variable countTraces, i
	Variable isPresent = 0
		
	currentTraces = TraceNameList("",";",1)
	countTraces = ItemsInList(currentTraces)

	for (i=0;i<countTraces;i+=1)
		Wave wv = TraceNameToWaveRef("", StringFromList(i,currentTraces) )
			if (cmpstr(NameOfWave(wv),NameOfWave(search)) == 0)
				isPresent = 1
			endif
		WaveClear wv
	endfor

	return isPresent
End


Function/S PathActionGetFileList(strFolder, strExtension)
	String strFolder, strExtension

	String strFile = ""
	String listFiles = ";"
	
	Variable i

	NewPath/Q/O path strFolder
	listFiles = IndexedFile(path, -1, strExtension)
	listFiles = SortList(listFiles,";",16) //Case-insensitive alphanumeric sort that sorts wave0 and wave9 before wave10.
	for (i=0;i<ItemsInList(listFiles); i+=1)
		strFile = StringFromList(i,listFiles)
		// print strFile
		// show sorting
	endfor

	return listFiles
End

