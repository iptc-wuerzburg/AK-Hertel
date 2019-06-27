#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.
#include <WaveSelectorWidget> //Includes are necessary for the wav
#include <PopupWaveSelector>

//Version history:
//V1.00 first release with current build
//V1.01 fwhm: data now stored in two waves. One a namelist, the other the fwhm values
//V1.02 implemented basic linear background removal at defined point
//V1.03 bug fixes in linear background removal Button. Now creates Backup of corrected spectrum
//V1.04 added print commands to protocol what procedures were used on what spectra; code cleanup
//V1.05 added button to display selected waves using the Abs_nm graph macro.
//V1.06 changed background removal function to x2pnt to allow users to perform the background removal via x coordinate; various bug fixes
//V1.07 Added buttons for loading Directories and single files
//V1.08 Original spectra folder now created in active folder instead of root:originalspectra
//v1.09 Implemented the Gauss-Cap Method for determining the peak position; Added automatic annotations for all button operations
//v1.10 Fixed minor spelling mistakes; Removed folder path from background removal note, since the path changes anyway during backup
//      Added normalization faktor to the wave note with the normalization function
//V1.11 Rearranged some Buttons to better reflect the actual workflow; 
//      Added functionality to include custom notes for experimental parameters to all selected Spectra


//to Do-List:
//rework CreateBackUp function to allow automatic renaming in case of multiple backgroundwaves with same name
//include PopUp Menu for various GraphMacros for for displaying the selected waves
//implement automatic layout creation for selected spectra
//implement linear background removal via more sophisticated algorithm


//Note: Relies on the swnt-absorption.ipf, swnt-absorption-display.ipf an swnt-absorption-tools.ipf to work

//******************************************************************************
//Panel functions
//******************************************************************************

//Structure to hold Information about the list of all spectra and the individual spectrum to be worked on in a loop
Structure SpectrumInfo
	DFREF SpectrumPath 
	DFREF BackUpPath
	String spectralist
	String SpectrumName
	String BackUpName
	Variable numitems
	WAVE spectrum
	WAVE BackUpSpectrum
EndStructure

//Creates Panel for the Absorption tools
Function CreateAbsorptionToolPanel()
	String panelName = "AbsorptionPanel"

	if(WinType(panelname) == 7)
		DoWindow/F $panelname
	else
	
	//creates Panel and draws GUI elements
	NewPanel /N=$panelName/W=(118,106,743,544) as "AbsorptionTools"
	SetDrawLayer UserBack
	
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 661,-38,981,42
	SetDrawEnv linefgc= (52428,52428,52428),fillpat= 0
	DrawRect 5,20,275,427
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 290,143,610,188
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 290,198,610,243
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 290,20,610,75
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 290,258,610,303
	SetDrawEnv linethick= 1.1,linefgc= (48059,48059,48059),fillpat= 0,fillfgc= (48059,48059,48059)
	DrawRect 290,86,610,131
	
	//creates wave selector list to allow for a selection of spectras to work on and a pop-up menu to sort waves
	TitleBox WSPopupTitle2,pos={23.00,11.00},size={138.00,15.00},title="Select absorption spectra: "
	TitleBox WSPopupTitle2,labelBack=(61166,61166,61166),frame=0
	ListBox SpectraSelectionList,pos={15.00,30.00},size={251.00,369.00}
	ListBox SpectraSelectionList,mode= 10,editStyle= 1,widths={20,500}
	MakeListIntoWaveSelector(panelName, "SpectraSelectionList", content = WMWS_Waves)
	PopupMenu sortKind,pos={17.00,406.00},size={96.00,19.00},proc=WS_SortKindPopMenuProc,title="Sort Waves By"
	MakePopupIntoWaveSelectorSort(panelName, "ExampleWaveSelectorList", "sortKind")
	
	//creates buttons and checkbox for background correction
	Button PopUpSelectReference,pos={300.00,97.00},size={164.00,21.00},proc=PopupWaveSelectorButtonProc,title="\\JR(no selection) \\W623"
	MakeButtonIntoWSPopupButton(panelName, "PopUpSelectReference", "DemoPopupWaveSelectorNotify", options=PopupWS_OptionFloat)
	Button SubstractReference,pos={486.00,97.00},size={69.00,22.00},proc=ButtonSubstractReference,title="Substract"
	TitleBox WSPopupTitle3,pos={305.00,79.00},size={116.00,15.00},title="Background removal: "
	TitleBox WSPopupTitle3,labelBack=(61166,61166,61166),frame=0
	
	//creates buttons and control variable for linear background removal
	Button ButtonLinBackground,pos={301.00,272.00},size={130.00,20.00},proc=ButtonLinearBackgroundRemoval,title="Substract background"
	TitleBox LabelBackgroundRemoval,pos={302.00,249.00},size={164.00,15.00},title="Linear Background Correction: "
	TitleBox LabelBackgroundRemoval,labelBack=(61166,61166,61166),frame=0
	TitleBox ref_point,pos={474.00,249.00},size={132.00,15.00},title="select point to zero (nm):"
	TitleBox ref_point,labelBack=(61166,61166,61166),frame=0
	SetVariable ControlZeroPoint,pos={488.00,272.00},size={60.00,18.00}
	SetVariable ControlZeroPoint,value= _NUM:1300
	TitleBox ref_point_zeronotice,labelBack=(61166,61166,61166),fSize=10,frame=0
	
	//creates button for FWHM calculation
	Button ButtonPeakData,pos={300.00,155.00},size={130.00,20.00},proc=ButtonGetPeakData,title="Get Peak Data"
	TitleBox WSPopupTitle5,pos={305.00,134.00},size={58.00,15.00},title="Peak Data: "
	TitleBox WSPopupTitle5,labelBack=(61166,61166,61166),frame=0
	TitleBox x1_fwhm,pos={441.00,134.00},size={43.00,15.00},title="x1 (nm):"
	TitleBox x1_fwhm,labelBack=(61166,61166,61166),frame=0
	TitleBox x2_fwhm,pos={525.00,134.00},size={43.00,15.00},title="x2 (nm):"
	TitleBox x2_fwhm,labelBack=(61166,61166,61166),frame=0
	SetVariable ControlPeakPosition1,pos={440.00,156.00},size={74.00,18.00}
	SetVariable ControlPeakPosition1,value= _NUM:950
	SetVariable ControlPeakPosition2,pos={525.00,156.00},size={74.00,18.00}
	SetVariable ControlPeakPosition2,value= _NUM:1300
	
	//creates button for Normalization
	TitleBox WSPopupTitle6,pos={305.00,189.00},size={81.00,15.00},title="Normalization: "
	TitleBox WSPopupTitle6,labelBack=(61166,61166,61166),frame=0
	Button ButtonNorm,pos={300.00,210.00},size={130.00,20.00},proc=ButtonNormSpectrum,title="Normalize"
	TitleBox x1_norm,pos={441.00,189.00},size={43.00,15.00},title="x1 (nm):"
	TitleBox x1_norm,labelBack=(61166,61166,61166),frame=0
	TitleBox x2_norm,pos={525.00,190.00},size={43.00,15.00},title="x2 (nm):"
	TitleBox x2_norm,labelBack=(61166,61166,61166),frame=0
	SetVariable ControlNormPosition1,pos={440.00,211.00},size={74.00,18.00}
	SetVariable ControlNormPosition1,value= _NUM:400
	SetVariable ControlNormPosition2,pos={525.00,211.00},size={74.00,18.00}
	SetVariable ControlNormPosition2,value= _NUM:1800
	
	//Creates Buttons for loading absorption files (single and folder)
	Button ButtonLoadDirectory,pos={436.00,33.00},size={90.00,27.00},proc=ButtonAbsorptionLoadDirectory,title="Load Directory"
	Button ButtonLoadFile,pos={306.00,34.00},size={90.00,27.00},proc=ButtonAbsorptionLoadFile,title="Load File"
	TitleBox Title_Load,pos={305.00,11.00},size={53.00,15.00},title="File Load: "
	TitleBox Title_Load,labelBack=(61166,61166,61166),frame=0
	
	//Creates Notebook to use for annotating the selected waves
	NewNotebook /F=0 /N=WaveNoteField /W=(289,309,611,396) /HOST=# 
	Notebook kwTopWin, defaultTab=20, autoSave= 1
	Notebook kwTopWin font="Lucida Console", fSize=11, fStyle=0, textRGB=(0,0,0)
	Notebook kwTopWin, zdata= "GaqDU%ejN7!Z)tkA:OY,+?$rH>0K5W:]LL22ZoQ"
	Notebook kwTopWin, zdataEnd= 1
	Button ButtonAddWaveNote,pos={290.00,403.00},size={135.00,23.00},title="Add Note",proc=ButtonAnnotateSpectrum
	
	//creates button for displaying selected waves
	Button DisplayWaves,pos={129.00,405.00},size={98.00,20.00},proc=PlotSpectrumGraph,title="Display waves"
	
	
	SetWindow kwTopWin,hook(PopupWS_HostWindowHook)=PopupWSHostHook
	SetWindow kwTopWin,hook(WaveSelectorWidgetHook)=WMWS_WinHook
	endif
	
End


//Subroutine to hold Information about the list of spectra. To be used outside of loop assingments.
Static Function GetSpectralistInfo(s)
	STRUCT SpectrumInfo &s
	s.spectralist = WS_SelectedObjectsList("AbsorptionPanel","SpectraSelectionList")
	s.numitems = Itemsinlist(s.spectralist)
End

//Subroutine to get information about individual spectra. To be used in loop assignements.
Static Function GetSpectrumInfo(s,[c])
	Variable c 
	STRUCT SpectrumInfo &s
	
	if (ParamIsDefault(c)) //If no input is given the first element in the list string is taken
		c = 0		
	endif
	
	s.spectrumname = stringfromlist(c,s.spectralist)
	WAVE s.spectrum = $s.spectrumname
	s.spectrumpath = GetWavesDataFolderDFR(s.spectrum)	
End 


//Function to create a backup wave
//currently holds the backup folder. Probably subject to change(to-Do list)
Function CreateBackup2(spectrum)
	WAVE spectrum
	
	newdatafolder/O :originalspectra
	duplicate/O spectrum, :originalspectra:$nameofwave(spectrum)
End


//Procedure called by the "Substract Reference" Button. Substractes reference spectrum from the list
//of selected waves.
Function ButtonSubstractReference(control) : ButtonControl
	STRUCT WMButtonAction &control
	STRUCT SpectrumInfo s
	String backgroundstring, spectrumnote
	Variable i
	WAVE backgroundwave 
	
	switch( control.eventCode )
	case 2: // mouse up
		GetSpectralistInfo(s)

		backgroundstring = PopupWS_GetSelectionFullPath("AbsorptionPanel","PopUpSelectReference")
		
		//Error message if no wave has been selected
		if(stringmatch(backgroundstring, "(no selection)") == 1)
			Abort "No background wave specified"
		endif
		
		//Error if background wave is chosen as wave to be subtracted from
		if(WhichListItem(backgroundstring,s.spectralist,";") != -1)
			Abort "Background wave was also selected as wave to be subtracted from."
		endif

		WAVE backgroundwave = $backgroundstring
		CreateBackUp2(backgroundwave) 
		spectrumnote = "Wave: " + NameOfWave(backgroundwave) + " was substracted from this wave"
		
		for(i = 0; i < s.numitems; i += 1)
			GetSpectrumInfo(s,c = i) 
			CreateBackUp2(s.spectrum)
			s.spectrum -= backgroundwave
			Note s.spectrum, spectrumnote
			Rename s.spectrum, $(nameofwave(s.spectrum) +"_r")	
		endfor	
		
		Print "Background spectrum: " + backgroundstring + " substracted from the following spectra: " + s.spectralist

		WS_UpdateWaveSelectorWidget("AbsorptionPanel", "SpectraSelectionList")
		break
	case -1: //control being killed
			break
	endswitch
	
End



//Sets the selected waves to zero at the chosen point.
Function ButtonLinearBackgroundRemoval(control) : ButtonControl
	STRUCT WMButtonAction &control
	STRUCT SpectrumInfo s 
	String spectrumnote
	Variable i, ZeroValue, xpoint
	
	switch( control.eventCode)
	case 2: // mouse up
		
		//Gets Information about the list of spectra to be operated on as well as the Value of Controlbox
		GetSpectralistInfo(s)
		controlinfo /W=AbsorptionPanel ControlZeroPoint
		xPoint = V_Value 
		spectrumnote = "Spectrum was zeroed on the x Value: " + num2str(xPoint)
		
		//Substracts y value at xpoint for every wave. if xpoint = 0 defaults to first point of wave
		if(xpoint != 0)
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c = i)
				CreateBackUp2(s.spectrum)
				ZeroValue = s.spectrum(xPoint)
				MinimumBackgroundRemoval(s.spectrum, value = ZeroValue)
				Note s.spectrum, spectrumnote
				Rename s.spectrum, $(nameofwave(s.spectrum) +"_l")
			endfor
			Print "The following spectra have been zeroed the the x coordinate " + num2str(xPoint) + ": " + s.spectralist
		else
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c = i)
				CreateBackUp2(s.spectrum)
				MinimumBackgroundRemoval(s.spectrum)
				Note s.spectrum, spectrumnote
				Rename s.spectrum, $(nameofwave(s.spectrum) +"_l")
			endfor		
			Print "The following spectra have been zeroed the first point of the given spectrum: " + s.spectralist	
		endif	
		
		WS_UpdateWaveSelectorWidget("AbsorptionPanel", "SpectraSelectionList")
		break
	case -1: //control being killed	
		break
	endswitch
	
End


//Procedure called by Normalize button. Normalizes spectrum to the maximum in the specified range.
Function ButtonNormSpectrum(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	STRUCT SpectrumInfo s
	String spectrumnote
	Variable i, normrangestart, normrangeend, normalization_faktor
		
	switch( ba.eventCode )
		case 2: // mouse up
			//loads information about the selected waves and variables.
			GetSpectralistInfo(s)
			controlinfo /W=AbsorptionPanel ControlNormPosition1
			normrangestart = V_Value 
			controlinfo /W=AbsorptionPanel ControlNormPosition2
			normrangeend = V_Value 
			
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c=i)
				CreateBackUp2(s.spectrum)
				normalization_faktor = NormSpectrum(s.spectrum,x1=normrangestart,x2=normrangeend)
				spectrumnote = "Wave has been normalized to its maximum in the range between " + num2str(normrangestart) + " and " + num2str(normrangeend) + "with an normilization faktor of" + num2str(normalization_faktor)
				Note s.spectrum, spectrumnote
				Rename s.spectrum, $(nameofwave(s.spectrum) +"_n")
			endfor
			
			Print "The following spectra have been normalized to their maximum in the range between " + num2str(normrangestart) + " and " + num2str(normrangeend) + ": " + s.spectralist
			KillVariables/Z V_Flag, V_Value, V_disable, V_Height, V_Width, V_top, V_left
			KillStrings/Z S_DataFolder, S_UserData, S_Value, S_recreation, S_title
			WS_UpdateWaveSelectorWidget("AbsorptionPanel", "SpectraSelectionList")
			break
		case -1: // control being killed
			break
	endswitch

End


//Procedure called by "Calculate fwhm" Button. Information is stored in folder root:FWHM_data.
//Uses interpolation at half the maximum in the specified range to determine the fwhm.
Function ButtonGetPeakData(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	STRUCT SpectrumInfo s
	Variable i, fwhm, peakpos, peakmax, peakrangestart, peakrangeend

		
	switch( ba.eventCode )
		case 2: // mouse up
			//loads information about the selected waves and variables.
			GetSpectralistInfo(s)
			controlinfo /W=AbsorptionPanel ControlPeakPosition1
			peakrangestart = V_Value 
			controlinfo /W=AbsorptionPanel ControlPeakPosition2
			peakrangeend = V_Value 
			
			//creates waves to store Information
			newdatafolder/O root:FWHM_data
			make/N=(s.numitems)/O/T root:FWHM_data:peak_wavelist
			make/N=(s.numitems)/O root:FWHM_data:fwhm_values
			make/N=(s.numitems)/O root:FWHM_data:peakpos_values
			make/N=(s.numitems)/O root:FWHM_data:peakmax_values
			WAVE/T peak_twave = root:FWHM_data:peak_wavelist
			WAVE fwhm_vwave = root:FWHM_data:fwhm_values
			WAVE peakpos_vwave = root:FWHM_data:peakpos_values
			WAVE peakmax_vwave = root:FWHM_data:peakmax_values
				
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c=i)
				peak_twave[i] = nameofwave(s.spectrum)
				fwhm_vwave[i] = CalculateFWHM(s.spectrum,x1=peakrangestart,x2=peakrangeend) 
				peakpos_vwave[i] = GaussCapPeakFind(s.spectrum,peakrangestart,peakrangeend) 
				peakmax_vwave[i] = 	wavemax(s.spectrum,peakrangestart,peakrangeend)
			endfor
			
			KillVariables/Z V_Flag, V_Value, V_disable, V_Height, V_Width, V_top, V_left
			KillStrings/Z S_DataFolder, S_UserData, S_Value, S_recreation, S_title
			Print "FWHM values for the following spectra calculated for the peak between " + num2str(peakrangestart) + " and " + num2str(peakrangeend) + ": " + s.spectralist	
			break
		case -1: // control being killed
			break
	endswitch

End


Function PlotSpectrumGraph(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	STRUCT SpectrumInfo s
	Variable i
	
	switch( ba.eventCode )
		case 2: // mouse up
			//loads information about the selected waves and variables.
			GetSpectralistInfo(s)
			display/N=SpectrumGraph
			string SpectrumGraphName = winname(0,1)
			
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c=i)
				AppendtoGraph/W=$SpectrumGraphName	s.spectrum
			endfor

			SetWindow $SpectrumGraphName
			Execute/Q "Abs_nm()"  //Applying Graph Macro for Absorption Spectra to the created Window
			break
		case -1: // control being killed
			break
	endswitch

End


Function ButtonAbsorptionLoadDirectory(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			AbsorptionLoadDirectory()	
			WS_UpdateWaveSelectorWidget("AbsorptionPanel", "SpectraSelectionList")
			break
		case -1: // control being killed
			break
	endswitch

End


Function ButtonAbsorptionLoadFile(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	
	switch( ba.eventCode )
		case 2: // mouse up
			AbsorptionLoadFile()	
			WS_UpdateWaveSelectorWidget("AbsorptionPanel", "SpectraSelectionList")
			break
		case -1: // control being killed
			break
	endswitch

End

Function ButtonAnnotateSpectrum(ba): ButtonControl
	STRUCT WMButtonAction &ba
	STRUCT SpectrumInfo s
	Variable i
	
	switch( ba.eventCode )
		case 2: // mouse up
			GetSpectralistInfo(s)
			Notebook AbsorptionPanel#WaveNoteField selection={startOfFile, endOfFile}
			GetSelection notebook, AbsorptionPanel#WaveNoteField, 2
			
			for(i = 0; i < s.numitems; i += 1)
				GetSpectrumInfo(s,c=i)
				Note s.spectrum, S_Selection
			endfor
			Print "Wave note added to the following spectra: " + s.spectralist
			
			break
		case -1: // control being killed
			break
	endswitch

End



//******************************************************************************
//Spectra functions
//******************************************************************************


//Calculates fwhm using linear interpolation at the half maximum point of the wave between x1=500 and x2=1150.
//Needs to be modified to support multiple peaks and better output format.
Function CalculateFWHM(spectrum,[x1,x2]) 
	WAVE spectrum
	Variable x1, x2
	Variable m, fwhm, peakmax
	
	
	If(Paramisdefault(x1))
		x1 = 950
	Endif
	
	If(Paramisdefault(x2))
		x2 = 1300
	Endif
	
	peakmax = wavemax(spectrum,x1,x2)
	FindLevels/D=FWHMxValues/M=10/Q/R=(x1,x2)spectrum, peakmax/2
	WAVE FWHMxV = FWHMxValues
	fwhm = FWHMxV[1]-FWHMxV[0]
	
	KillVariables/Z V_LevelsFound
	Killwaves/Z FWHMxV
	Return fwhm
End


//Determines Peakposition of maximum. Only uses actual datapoints.
Function PeakPosition(spectrum,[x1,x2]) 
	WAVE spectrum
	Variable x1, x2
	Variable m, fwhm, peakmax, peakpos
	
	If(Paramisdefault(x1))
		x1 = 950
	Endif
	
	If(Paramisdefault(x2))
		x2 = 1300
	Endif
	peakmax = wavemax(spectrum,x1,x2)
	FindLevel/Q/R=(x1,x2) spectrum, peakmax
	peakpos = V_LevelX
	
	Return peakpos	
End



//Normalizes a spectrum using the maximum between x1 = 500 and x2 = 1500 as default values.
Function NormSpectrum(spectrum,[x1,x2])
	Variable x1, x2
	Wave spectrum
	Variable m
	
	If(Paramisdefault(x1))
		x1 = 500
	Endif
	
	If(Paramisdefault(x2))
		x2 = 1500
	Endif
	
	m = wavemax(spectrum,x1,x2)
	spectrum = spectrum/m
	
	Return m
End

//Substractes a value from the wave. Serves as minimalistic linear background removal
Function MinimumBackgroundRemoval(spectrum, [value])
	WAVE spectrum
	Variable value
	
	if(paramisdefault(value)==1)
		value = spectrum[x2pnt(spectrum, value)]
		spectrum -= value
	else	
		spectrum -= value
	endif
	
	Return 0
End

//WIP Gauss-Cap Peak Finding
Function GaussCapPeakFind(spectrum,x_start,x_end)
	Variable x_start,x_end
	WAVE spectrum
	Make/Free/N=4 fit_results	
	
	CurveFit/Q/M=2/W=0 gauss, kwCWave=fit_results, spectrum[x2pnt(spectrum,x_start),x2pnt(spectrum,x_end)]/D
	Return fit_results[2]
End

//Annotates Text to Wave
Function AnnotateTextToSpectrum(spectrum,str_text)
	String str_text
	WAVE spectrum
	Note spectrum,str_text
	Return 0
End