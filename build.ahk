#Requires AutoHotkey v2.1-alpha.14
#include <Aris/Qriist/LibQurl>
#include <Aris/g33kdude/cjson> ; g33kdude/cjson@2.0.0
SetWorkingDir(A_ScriptDir)
curl := LibQurl()

;update the ICU DLLs
url := "https://api.github.com/repos/unicode-org/icu/releases/latest"
curl.SetOpt("URL",url)
useragent := "Mozilla/5.0 (platform; rv:gecko-version) Gecko/gecko-trail Firefox/firefox-version"
curl.SetOpt("USERAGENT",useragent)  ;github freaks out if you lack useragent
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
    
    cmd7z := A_ScriptDir "\tools\7za.exe x " '"' zipPath "\" zipName '"' " -o" zipPath "\current\"
    RunCMD(cmd7z)
}

icuDir := A_ScriptDir "\bin\icu-precompiled\current"
EnvSet("LIBICU_PATH", icuDir) ;temporarily set the ICU dll path
; MsgBox "LIBICU_PATH set to: " EnvGet("LIBICU_PATH")


;update the SQLite3MultipleCiphers submodule
MCpath := A_ScriptDir "\SQLite3MultipleCiphers\"
MCpathToBuild := A_ScriptDir "\SQLite3MultipleCiphers\build\"
RunWait("git submodule update --remote --force --merge")
RunWait("git add SQLite3MultipleCiphers")
RunWait('git commit -m "Force update all submodules to latest commits"')
RunWait("git push origin master")
; RunWait("git submodule update --remote")


;todo - git ~things~

;clean and build the MC DLLs
targetsolution := "sqlite3mc_vc17.sln"
releaseConfig := "/p:Configuration=Release /p:Platform=Win64"
SqlarPreprocessor := '/p:DefineConstants="SQLITE3MC_USE_MINIZ=1;SQLITE_ENABLE_COMPRESS=1;SQLITE_ENABLE_SQLAR=1;SQLITE_ENABLE_ZIPFILE=1"'

cleanCmd := "msbuild " targetsolution " /t:Clean " releaseConfig " " SqlarPreprocessor
buildCmd := "msbuild " targetsolution " " releaseConfig " " SqlarPreprocessor

;comspec was giving me grief, this was easier
FileOpen(A_ScriptDir "\build.bat","w").Write(cleanCmd "`n" buildCmd)
RunWait(A_ScriptDir "\build.bat",MCpathToBuild)

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
        try
            FileDelete(built "SqlarMultipleCiphers" ICU UPX ".7z")
        RunWait(_7zcmd " " Chr(34) "SqlarMultipleCiphers" ICU UPX ".7z" chr(34) " " chr(34) targetDir Chr(34),built)
    }
}

;todo - push a release
/*
    follow this template:
    gh release create "v1.9.2" "built\SqlarMultipleCiphers ICU UPX.7z" "built\SqlarMultipleCiphers ICU.7z" "built\SqlarMultipleCiphers UPX.7z" "built\SqlarMultipleCiphers.7z"   --title "SqlarMultipleCiphers v1.9.2" --notes "Built from: SQLite3 Multiple Ciphers 1.9.2 (based on SQLite 3.47.2)"
*/
