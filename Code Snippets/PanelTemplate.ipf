#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <WaveSelectorWidget> //These two includes contain the wave selecter widget and allow the construction
#include <PopupWaveSelector>//of wave list boxes

//Insert the name and title of your panel here. RENAMING IS NECESSARY.
Static StrConstant PanelName = "MyPanelName" 
Static StrConstant PanelTitle =  "MyPanelTitle"


//Insert in which Menu you would like your PanelMacro to show up
Menu "AKH"
	SubMenu "NewPanels"
		"MyPanelTitle", PanelFunction()	
	End
End

//Structure to hold relevant information
Structure WaveListInfo
	DFREF path_wave
	String str_ListOfWaves
	String str_WaveName
	Variable var_NumItems
	WAVE wave_WaveName
EndStructure

//Gets Information from the WaveSelector in the PanelName Panel
Static Function GetWaveListInfo(s)
	STRUCT WaveListInfo &s
	s.str_ListOfWaves = WS_SelectedObjectsList(PanelName,"WaveSelectionList")
	s.var_NumItems = ItemsInList(s.str_ListOfWaves)
End

//Isolates singular files from the List
Static Function GetSingleWaveInfo(s,[c])
	STRUCT WaveListInfo &s
	Variable c
	
	if (ParamIsDefault(c)) //If no input is given the first element in the list string is taken
		c = 0		
	endif
	
	s.str_WaveName = stringfromlist(c,s.str_ListOfWaves)
	WAVE s.wave_WaveName = $s.str_WaveName
	s.path_Wave = GetWavesDataFolderDFR(s.wave_WaveName)

End


//Panel with Wave Selector Template
//MUST BE RENAMED WHEN ADAPTED TO YOUR PANEL
Function PanelFunction()
	
	//Brings the Panel to the foreground if it already exists
	if(WinType(PanelName) == 7)
		DoWindow/F $PanelName
	else
		//if it doesn't exist yet creates Panel and draws GUI elements
		NewPanel/N=$PanelName/W=(118,106,744,508) as PanelTitle
		SetDrawLayer UserBack
		
		//Generates a ListBox with all waves
		TitleBox WSPopupTitle2,pos={23.00,11.00},size={138.00,15.00},title="Select waves: "
		TitleBox WSPopupTitle2,labelBack=(61166,61166,61166),frame=0
		ListBox WaveSelectionList,pos={15.00,30.00},size={250.00,320.00}
		ListBox WaveSelectionList,mode= 10,editStyle= 1,widths={20,500}
		MakeListIntoWaveSelector(PanelName, "WaveSelectionList", content = WMWS_Waves)
		PopupMenu sortKind,pos={15.00,360.00},size={96.00,19.00},proc=WS_SortKindPopMenuProc,title="Sort Waves By"
		MakePopupIntoWaveSelectorSort(PanelName, "ExampleWaveSelectorList", "sortKind")
		
		//creates buttons and checkbox for background correction
		Button PopUpSelectSingleWave,pos={286.00,33.00},size={164.00,21.00},size={164.00,21.00},proc=PopupWaveSelectorButtonProc,title="\\JR(no selection) \\W623"
		MakeButtonIntoWSPopupButton(PanelName, "PopUpSelectSingleWave", "DemoPopupWaveSelectorNotify", options=PopupWS_OptionFloat)

		//Insert Remaining GUI elements here

	endif
End



//Template for a ButtonProc which executes a Function on all selected waves
//MUST BE RENAMED WHEN ADAPTED TO YOUR PANEL; AFTER RENAMING REMOVE STATIC KEYWORD
Static Function ExecuteFunctionOnList(ba) : ButtonControl //STATIC KEYWORD MUST BE REMOVED BEFORE BEING USABLE
	STRUCT WMButtonAction &ba
		
	STRUCT WaveListInfo s
	String str_PopUpSingleWave
	Variable i
	WAVE wave_PopUpSingleWave
	
	switch(ba.eventCode)
	case 2: // Executes when Mouse button is released
		GetWaveListInfo(s)
		
		//OPTIONAL POPUP SINGLE WAVE SELECTOR CODE. 
		//The Single Wave read from the PopUpSelector is being read and referenced here.
		//str_PopUpSingleWave = PopupWS_GetSelectionFullPath(PanelName,"PopUpSelectSingleWave")
		//Checks if a wave has been selected in the popup. Aborts if it isnt.
		//if(stringmatch(str_PopUpSingleWave, "(no selection)") == 1)
		//	Abort "No wave specified"
		//endif
		//WAVE wave_PopUpSingleWave = $str_PopUpSingleWave
		
		for(i = 0; i < s.var_NumItems; i += 1)
			GetSingleWaveInfo(s,c = i) 
			//Here you can insert your own Functions or Cod to be looped through the selected waves from the list for example:
			// MyFunction(s.wave_WaveName)

		endfor	
		
		//Updates the WaveSelector list in case your function altered the data in any way.
		WS_UpdateWaveSelectorWidget(PanelName, "WaveSelectionList")
		break
	case -1: //control being killed
			break
	endswitch

End
