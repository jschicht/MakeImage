#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=C:\Program Files (x86)\AutoIt3\Icons\au3.ico
#AutoIt3Wrapper_Change2CUI=y
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <GDIPlus.au3>
#include <WinApi.au3>

;Thanks to trancexx
;Slightly modified sources from;
;https://www.autoitscript.com/forum/topic/148636-alternative-data-compression/

;https://msdn.microsoft.com/en-us/library/windows/desktop/ms534171(v=vs.85).aspx
Global Const $RotateNoneFlipX = 4
Global Const $RotateFlipType = $RotateNoneFlipX
Global Const $PixFormat = $GDIP_PXF32ARGB
Global Const $BytesPerPixel = 4

Global $Width = InputBox("Set image width (X) in pixels", "The height will be automatically set", "128")
If @error Or $Width="" Then Exit
If Not StringIsDigit($Width) Then
	MsgBox(0,"Error", "Incorrect X. Expected integer.")
	Exit
EndIf
$Width *= $BytesPerPixel

; Will save this particular script
$File = FileOpenDialog("Select input file to convert to image",@ScriptDir,"All (*.*)")
If @error Then Exit
ConsoleWrite("File: " & $File & @CRLF)
$hFile = FileOpen($File,16)
$sData = FileRead($hFile)
FileClose($hFile)

; Picture file to save the image to
$sPic = $File&".bmp"
If FileExists($sPic) Then
	MsgBox(0, "Error", "The output bmp file already exist: " & $sPic & @CRLF _
		& "Please move/remove the file or it will be overwritten.")
EndIf

; And here it is:
$Test = SaveAsPic($sData, $sPic)
If $Test = "" Or @error Then
	ConsoleWrite("Error occurred" & @crlf)
EndIf

Func SaveAsPic($vData, $sFile, $sFormat = "bmp")
	; Initialize GDIPlus
	If _GDIPlus_Startup() Then
		Local $bImage, $hImage = MakeImage($vData)
		If $hImage Then
			; Convert to specific format
			$bImage = GdipImageSaveToVariable($hImage, $sFormat)
			If @error Then ConsoleWrite("Error in GdipImageSaveToVariable(): " & @error & @crlf)
			; Release $hImage object
			_GDIPlus_ImageDispose($hImage)
		EndIf
		; Kill GDIPlus
		_GDIPlus_Shutdown()
		; Write binary to file
		If $bImage Then
			Local $hFile = FileOpen($sFile, 26)
			If $hFile <> -1 Then
				FileWrite($hFile, $bImage)
				FileClose($hFile)
				Return True
			EndIf
		EndIf
	EndIf
	; If here something went wrong
	Return SetError(1, 0, False)
EndFunc

; Reurns Bitmap object pointer or 0
Func MakeImage($bBinary)
	Local $iLenOr = BinaryLen($bBinary)
	; The idea is to make bitmap image out of raw data.
	; Because BMPs have data aligned, some padding will be often required.
	; In order not to read padded data later, info about the data size should be preserved.
	; I will append dword value to the original data holding the size of it,
	; therefore I must make space for that dword (4 bytes)
	Local $iLen = $iLenOr + 4
	; 24-bit Bitmap will be created. That means every pixel will have 24 bits - that's 3 bytes (RGB).
	; According to BMP specification one line of picture is 4-bytes aligned.
	; For example if 24-bit BMP has 6 pixels and every pixel is of course 3 bytes, that means one line
	; is 20 bytes, 3x6=18 bytes for data plus 2 bytes padding (probably will be filled with 0). That's a wasting space.
	; To use the space as much as possible obviously I should make input 12 bytes aligned.
	;Local $iPadd = Mod($iLen, 12)
	Local $iPadd = Mod($iLen, $Width)
	If $iPadd Then $iLen += $Width - $iPadd
	; There. $iLen is the number of bytes I must allocate
	Local $tBinary = DllStructCreate("byte[" & $iLen & "]")
	; Filling buffer with passed data
	DllStructSetData($tBinary, 1, $bBinary)
	;... And the last 4 bytes are dword value of tha size info
	DllStructSetData(DllStructCreate("dword", DllStructGetPtr($tBinary) + DllStructGetSize($tBinary) - 4), 1, $iLenOr)
	; Calculate optimal size of the pic
	Local $iHeight = $iLen / $Width
	Local $iWidth = $iLen / ($BytesPerPixel * $iHeight)

	; Finally create Bitmap
	Local $hBitmap = 0
	; Initialize GDIPlus
	If _GDIPlus_Startup() Then
		$hBitmap = GdipCreateBitmapFromScan0($iWidth, $iHeight, $iWidth * $BytesPerPixel, $PixFormat, $tBinary)
		If @error Then ConsoleWrite("Error in GdipCreateBitmapFromScan0()" & @crlf)
		; GdipCreateBitmapFromScan0 creates flipped image, get it back by flipping it
		;Because of troubles with RotateNoneFlipNone, we instead use RotateNoneFlipX twice
		If $hBitmap Then GdipImageRotateFlip($hBitmap, $RotateFlipType)
		If @error Then ConsoleWrite("Error in GdipImageRotateFlip()" & @crlf)
		If $hBitmap Then GdipImageRotateFlip($hBitmap, $RotateFlipType)
		If @error Then ConsoleWrite("Error in GdipImageRotateFlip()" & @crlf)
		; Kill GDIPlus
		_GDIPlus_Shutdown()
	EndIf
	; All done. Return the Bitmap or whatever
	Return $hBitmap
EndFunc

Func GdipCreateBitmapFromScan0($iWidth, $iHeight, $iStride = 0, $iPixelFormat = 0, $pScan0 = 0)
	Local $aCall = DllCall($__g_hGDIPDll, "dword", "GdipCreateBitmapFromScan0", "int", $iWidth, "int", $iHeight, "int", $iStride, "dword", $iPixelFormat, "struct*", $pScan0, "handle*", 0)
	If @error Or $aCall[0] Then Return SetError(1, 0, 0)
	Return $aCall[6]
EndFunc

Func GdipImageRotateFlip($hImage, $iType)
	Local $aCall = DllCall($__g_hGDIPDll, "dword", "GdipImageRotateFlip", "handle", $hImage, "dword", $iType)
	If @error Or $aCall[0] Then Return SetError(1, 0, 0)
	Return 1
EndFunc

; Returns binary data of Image in specified format (BMP, PNG,...) or nothing in case of error
; _GDIPlus_Startup() must be called before usage
Func GdipImageSaveToVariable($hImage, $sFormat)
	Local $aCall = DllCall($__g_hGDIPDll, "dword", "GdipGetImageEncodersSize", "dword*", 0, "dword*", 0)
	; Check for errors
	If @error Or $aCall[0] Then Return SetError(1, 0, "")
	; Read data
	Local $iCount = $aCall[1], $iSize = $aCall[2]
	; Allocate space
	Local $tBuffer = DllStructCreate("byte[" & $iSize & "]")
	Local $pBuffer = DllStructGetPtr($tBuffer)
	; Fill allocated space with Encoders data
	$aCall = DllCall($__g_hGDIPDll, "dword", "GdipGetImageEncoders", _
			"int", $iCount, _
			"int", $iSize, _
			"struct*", $tBuffer)
	; Check for errors
	If @error Or $aCall[0] Then Return SetError(2, 0, "")
	; Loop through Codecs until right one is found
	Local $tCodec, $sExtension, $pCLSID
	For $i = 1 To $iCount
		$tCodec = DllStructCreate("byte ClassID[16];" & _
				"byte FormatID[16];" & _
				"ptr CodecName;" & _
				"ptr DllName;" & _
				"ptr FormatDescription;" & _
				"ptr FilenameExtension;" & _
				"ptr MimeType;" & _
				"dword Flags;" & _
				"dword Version;" & _
				"dword SigCount;" & _
				"dword SigSize;" & _
				"ptr SigPattern;" & _
				"ptr SigMask", _
				$pBuffer)
		; Read FilenameExtension field ad see if it's one that's wanted
		If StringInStr(DllStructGetData(DllStructCreate("wchar[32]", DllStructGetData($tCodec, "FilenameExtension")), 1), $sFormat) Then
			$pCLSID = $pBuffer ; DllStructGetPtr($tCodec, "ClassID")
			ExitLoop
		EndIf
		; Go to next struct (by skipping the size of this one)
		$pBuffer += DllStructGetSize($tCodec)
	Next
	; Check for unsupported codec. $pCLSID must have value
	If Not $pCLSID Then Return SetError(3, 0, "")

	; IStream definition
	Local Const $sIID_IStream = "{0000000C-0000-0000-C000-000000000046}"
	; Define IStream methods:
	Local Const $tagIStream = "Read hresult(struct*;dword;dword*);" & _
			"Write hresult(struct*;dword;dword*);" & _ ; ISequentialStream
			"Seek hresult(int64;dword;uint64*);" & _
			"SetSize hresult(uint64);" & _
			"CopyTo hresult(ptr;uint64;uint64*;uint64*);" & _
			"Commit hresult(dword);" & _
			"Revert hresult();" & _
			"LockRegion hresult(uint64;uint64;dword);" & _
			"UnlockRegion hresult(uint64;uint64;dword);" & _
			"Stat hresult(ptr;dword);" & _
			"Clone hresult(ptr*);"
	; Create stream object
	Local $oStream = ObjCreateInterface(CreateStreamOnHGlobal(), $sIID_IStream, $tagIStream)
	; Check for errors
	If @error Then Return SetError(4, 0, "")
	; Save Image to that stream.
	;#cs
	$aCall = DllCall($__g_hGDIPDll, "dword", "GdipSaveImageToStream", _
			"handle", $hImage, _
			"ptr", $oStream(), _
			"ptr", $pCLSID, _
			"ptr", 0)
	;#ce
	; Check for errors
	ConsoleWrite("GdipSaveImageToStream: " & _WinAPI_GetLastErrorMessage() & @crlf)
	If @error Or $aCall[0] Then Return SetError(5, 0, "")

	; Read stream size
	Local Enum $STREAM_SEEK_SET = 0, $STREAM_SEEK_END = 2
	Local $iSize
	$oStream.Seek(0, $STREAM_SEEK_END, $iSize)
	; Set stream position to the start of it
	$oStream.Seek(0, $STREAM_SEEK_SET, 0)
	; Allocate space for binary
	Local $tBinary = DllStructCreate("byte[" & $iSize & "]")
	; Read from stream to struct
	Local $iRead
	$oStream.Read($tBinary, $iSize, $iRead)
	; All done
	Return DllStructGetData($tBinary, 1)
EndFunc

Func CreateStreamOnHGlobal($hGlobal = 0, $iFlag = 1)
	Local $aCall = DllCall("ole32.dll", "long", "CreateStreamOnHGlobal", "handle", $hGlobal, "int", $iFlag, "ptr*", 0)
	If @error Or $aCall[0] Then Return SetError(1, 0, 0)
	Return $aCall[3]
EndFunc