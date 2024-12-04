#Requires AutoHotkey v2.1-alpha.14
#include <Aris/Qriist/LibQurl>
#include <Aris/g33kdude/cjson> ; g33kdude/cjson@2.0.0

;update the ICU DLLs
curl := LibQurl()
curl.register(0)
;NOTE: auto-update skipped for now, will write this later


;determine the latest ICU directory
loop files A_ScriptDir "\bin\icu-precompiled\*" , "D"
    icuDir := A_LoopFileFullPath

EnvSet("LIBICU_PATH", icuDir) ; Replace with the actual path
; MsgBox "LIBICU_PATH set to: " EnvGet("LIBICU_PATH")
