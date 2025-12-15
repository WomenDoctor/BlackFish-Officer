; NsJSON Plugin Header
; This header file is included to indicate the NsJSON plugin is available
; The plugin DLL (nsJSON.dll) must be in the Plugins directory for runtime use
; The installer code will define NsJSON_Available after including this file

; Note: NsJSON plugin doesn't require macros - it's called directly as:
; nsJSON::Set /tree "name" /file "path"
; nsJSON::Get /tree "name" /end
; nsJSON::Serialize /tree "name" /format /file "path"
; etc.

