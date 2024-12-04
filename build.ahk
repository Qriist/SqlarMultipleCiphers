#Requires AutoHotkey v2.1-alpha.14
#include <Aris/Qriist/LibQurl>
#include <Aris/g33kdude/cjson> ; g33kdude/cjson@2.0.0

;update the ICU DLLs
curl := LibQurl()
curl.register(0)
;NOTE: auto-update skipped for now, will write this later

;clean the ICU DLLs
;todo - make conditional based on if ICU was updated
try
    DirDelete(A_ScriptDir "\bin\icu-precompiled\current",1)

;determine the latest ICU directory
loop files A_ScriptDir "\bin\icu-precompiled\*" , "D"
    If (A_LoopFileName = "current")
        continue
    else
        latestDir := A_LoopFileFullPath
icuDir := A_ScriptDir "\bin\icu-precompiled\current"

DirCopy(latestDir,icuDir,1)



EnvSet("LIBICU_PATH", icuDir) ;temporarily set the ICU dll path
; MsgBox "LIBICU_PATH set to: " EnvGet("LIBICU_PATH")

;update the SQLite3MultipleCiphers submodule
MCpath := A_ScriptDir "\MC\build"
;todo - git stuff

;clean and build the MC DLLs
targetsolution := "sqlite3mc_vc17.sln"
releaseConfig := "/p:Configuration=Release /p:Platform=Win64"
SqlarPreprocessor := '/p:DefineConstants="SQLITE3MC_USE_MINIZ=1;SQLITE_ENABLE_COMPRESS=1;SQLITE_ENABLE_SQLAR=1;SQLITE_ENABLE_ZIPFILE=1"'

cleanCmd := "msbuild " targetsolution " /t:Clean " releaseConfig " " SqlarPreprocessor
buildCmd := "msbuild " targetsolution " " releaseConfig " " SqlarPreprocessor

;comspec was giving me grief, this was easier
FileOpen(A_ScriptDir "\build.bat","w").Write(cleanCmd "`n" buildCmd)
Run(A_ScriptDir "\build.bat",MCpath)


