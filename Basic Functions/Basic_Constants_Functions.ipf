#pragma TextEncoding = "Windows-1252"
#pragma rtGlobals=3		// Use modern global access method and strict wave access.


//Set of physical constants used in hard sciences
Constant h_planck = 6.626070040E-34 // J s
Constant h_quer = 1.0545718E-34 // J s
Constant e_charge = 1.6021766E-19 // C
Constant density_toluene =  0.867 // g L-1
Constant c_0 = 299792458 // m s-1
Constant k_b = 1.38064852E-23 // J K-1 
Constant N_A = 6.022140857E23 // mol-1
Constant m_e = 9.10938356E-31 // kg

//transforms nanometre value into the corresponding energy value in electronvolt
//also works vice-versa transforming electronvolt into nanometre
Function nm2eV(var_nm)
	Variable var_nm
	Return 1239.84/var_nm
End

//transforms nanometre value into the corresponding wavenumber in inverse centimetres
//also works vice-versa transforming electronvolt into nanometre
Function nm2cm(var_nm)
	Variable var_nm
	Return 1E7/var_nm
End

//Converts optical density in a wavelength spectrum into mass concentration g/L using Freddies publication 
//"Molar Extinction Coefficient of Single-Wall Carbon Nanotubes", 
//optional parameters var_fwhm (full widht, half maximum in nm) and var_d (path length in cm) default to 24 nm and 1 cm.
Function OD2Mass(var_OD,[var_fwhm,var_d])
	Variable var_OD
	Variable var_fwhm, var_d // nm ; cm
	Variable var_B = 5.1E-08, var_OscStr = 0.01 // mol L-1 cm nm-1	
	
	if (paramisdefault(var_fwhm) == 1)
		var_fwhm = 24 // nm
	endif
	
	if (paramisdefault(var_d) == 1)
		var_d = 1 // cm
	endif
		
	Return var_B*((var_OD*var_fwhm)/(var_OscStr*var_d))*12 // g/L
End

//Appends a single Value to an existing numerical wave; use in long loops is not recommended since it's a very inefficient way of writing data
Function AppendValue(wave_num, var_value) 
	WAVE wave_num
	Variable var_value
   	Variable var_size = DimSize(wave_num,0)
	Redimension /N=(var_size+1,-1,-1,-1) wave_num
	wave_num [var_size] = var_value
	Return 0
End

//Appends a single string to an existing text wave; use in long loops is not recommended since it's a very inefficient way of writing data
Function AppendTextWave(wave_text, string_value) 
	Wave/T wave_text
	String string_value		
	Variable var_size = Dimsize(wave_text,0)
	Redimension /N=(var_size+1,-1,-1,-1) wave_text
	wave_text [var_size] = string_value
	Return 0
End
