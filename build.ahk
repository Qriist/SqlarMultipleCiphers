#Requires AutoHotkey v2.1-alpha.14
#include <Aris/Qriist/LibQurl>
#include <Aris/g33kdude/cjson> ; g33kdude/cjson@2.0.0
#include <Aris/Chunjee/adash> ; Chunjee/adash@v0.6.0
SetWorkingDir(A_ScriptDir)
curl := LibQurl()

;determine the latest SQLite3MultipleCiphers source code
;this is done before creating the first cmd window to prevent flashes if there's nothing to do
useragent := "Mozilla/5.0 (platform; rv:gecko-version) Gecko/gecko-trail Firefox/firefox-version"
curl.SetOpt("USERAGENT",useragent)  ;github freaks out if you lack useragent
url := "https://api.github.com/repos/utelle/SQLite3MultipleCiphers/releases/latest"
curl.SetOpt("URL",url)
curl.Sync()
mcObj := JSON.Load(curl.GetLastBody())
currentMcVersion := mcObj["tag_name"]
currentMcName := mcObj["name"]
buildIni := A_ScriptDir "\build.ini"
savedMcVersion := IniRead(buildIni,"build","savedMcVersion",0)
savedSqlarVersion := IniRead(buildIni,"build","savedSqlarVersion",0)

If (currentMcVersion = savedMcVersion)
&& (currentMcVersion = savedSqlarVersion)
    ExitApp


;locks all RunWaits to one console window
DllCall("AllocConsole")
hConsoleOut := DllCall("GetStdHandle", "uint", -11)

;update the submodule to latest release, if needed
if (currentMcVersion != savedMcVersion){
    MCpath := A_ScriptDir "\SQLite3MultipleCiphers\"
    MCpathToBuild := A_ScriptDir "\SQLite3MultipleCiphers\build\"

    ;todo: migrate to api
    RunWait("git checkout tags/v" currentMcVersion,MCpath)
    RunWait("git add SQLite3MultipleCiphers")
    RunWait('git commit -m "Updated SQLite3MultipleCiphers to ' currentMcVersion '"')
    RunWait("git push origin master")
    IniWrite(currentMcVersion,buildIni,"build","savedMcVersion")
    savedMcVersion := currentMcVersion
}

;update the SQLite3MultipleCiphers submodule
MCpath := A_ScriptDir "\SQLite3MultipleCiphers\"
MCpathToBuild := A_ScriptDir "\SQLite3MultipleCiphers\build\"
/*  old mode, waiting until next release to test
RunWait("git submodule update --remote --force --merge")
RunWait("git add SQLite3MultipleCiphers")
RunWait('git commit -m "Force update all submodules to latest commits"')
RunWait("git push origin master")
; RunWait("git submodule update --remote")
*/


;update the ICU DLLs before building MC DLLs
url := "https://api.github.com/repos/unicode-org/icu/releases/latest"
curl.SetOpt("URL",url)
curl.Sync()

jsonObj := JSON.load(curl.GetLastBody())
for k,v in jsonObj["assets"] {
    If !RegExMatch(v["name"],"(.+Win64.+\.zip)$")
        continue
    zipName := v["name"]
    browser_download_url := v["browser_download_url"]
    break
}

zipPath := A_ScriptDir "\bin\icu-precompiled"
If !FileExist(zipPath "\" zipName) {
    FileDelete(zipPath "\*")
    try DirDelete(zipPath "\current",1)
    DirCreate(zipPath "\current")

    curl.SetOpt("URL",browser_download_url)
    curl.WriteToFile(zipPath "\" zipName)
    curl.Sync()
    curl.GetLastBody("File").Close()    ;7z demands exclusive access
    
    _7zcmd := A_ScriptDir "\tools\7za.exe x " '"' zipPath "\" zipName '"' " -o" zipPath "\current\"
    RunWait(_7zcmd)
}

icuDir := A_ScriptDir "\bin\icu-precompiled\current"
EnvSet("LIBICU_PATH", icuDir) ;temporarily set the ICU dll path
; MsgBox "LIBICU_PATH set to: " EnvGet("LIBICU_PATH")





;clean and build the MC DLLs
targetsolution := "sqlite3mc_vc17.sln"
releaseConfig := "/p:Configuration=Release /p:Platform=Win64"

sqlarConsts := [
    "SQLITE3MC_USE_MINIZ=1",
    "SQLITE_ENABLE_COMPRESS=1",
    "SQLITE_ENABLE_SQLAR=1",
    "SQLITE_ENABLE_ZIPFILE=1"
]
SqlarPreprocessor := '/p:DefineConstants="' adash.join(sqlarConsts,";") '"'

cleanCmd := "msbuild " targetsolution " /t:Clean "  releaseConfig " " SqlarPreprocessor
buildCmd := "msbuild " targetsolution " "           releaseConfig " " SqlarPreprocessor

RunWait(cleanCmd,MCpathToBuild)
RunWait(buildCmd,MCpathToBuild)

;sort the dlls into the correct locations
MCreleaseDir := A_ScriptDir "\SQLite3MultipleCiphers\bin\vc17\dll\release"
sqnICU := [MCreleaseDir "\sqlite3mc_x64.dll"]
sqyICU := [MCreleaseDir "\sqlite3mc_icu_x64.dll"]
loop files icuDir "\bin64\icu*.dll"
    sqnICU.Push(A_LoopFileFullPath),sqyICU.Push(A_LoopFileFullPath)

upxexe := A_ScriptDir "\tools\upx.exe"
upxcmd := upxexe " --brute "
_7zexe := A_ScriptDir "\tools\7za.exe"
_7zcmd := _7zexe " a -mx=9 -sdel "
built := A_ScriptDir "\built\"
loop files built "*" , "D"
    DirDelete(A_LoopFileFullPath,1)
FileDelete(A_ScriptDir "\built\*.7z")
editions := []
for k,v in [""," ICU"] {
    ICU := v
    for k,v in [""," UPX"]{
        UPX := v
        targetDir := built "SqlarMultipleCiphers" ICU UPX
        DirCreate(targetDir)
        for k,v in (ICU=""?sqnICU:sqyICU){
            SplitPath(v,&FileName)
            If (FileName = "sqlite3mc" (ICU=""?"":"_icu") "_x64.dll")
                FileName := "sqlite3.dll"
            If (InStr(FileName,"icu") && (ICU=""))
                continue
            targetFile := targetDir "\" FileName
            FileCopy(v,targetFile)
            If (UPX!="") 
                RunWait(upxcmd Chr(34) targetFile Chr(34))
        }
        ; msgbox A_Clipboard :=_7zcmd " " Chr(34) "SqlarMultipleCiphers" ICU UPX ".7z" chr(34) " " chr(34) targetDir Chr(34)
        ; try FileDelete(built "SqlarMultipleCiphers" ICU UPX ".7z")
        edition := "SqlarMultipleCiphers " savedMcVersion ((ICU UPX)=""?"":" (" Trim(ICU UPX) ")")
        editions.Push('"' edition ".7z" '"')        
        RunWait(_7zcmd " " Chr(34) edition ".7z" chr(34) " " chr(34) targetDir Chr(34),built)
    }
}

If (savedMcVersion != savedSqlarVersion){
    ;todo: migrate to api
    gh := "gh release create " '"' savedMcVersion '"' A_Space
        .   adash.join(editions,A_Space) A_Space
        .   ' --title "SqlarMultipleCiphers ' savedMcVersion ' "' A_Space
        .   ' --notes "Built from: ' currentMcName '"'
    If !RunWait(gh,A_ScriptDir "\built")
        IniWrite(savedMcVersion, A_ScriptDir "\build.ini","build","savedSqlarVersion")
}