NSIS Plugins Directory
======================

This directory should contain the following plugin DLLs:

1. TextReplace.dll
   - Download from: https://nsis.sourceforge.io/TextReplace_plugin
   - Place TextReplace.dll in this directory
   - Used for: String replacement in files (replaces custom StrReplace function)

2. NsisXML.dll (Joel's version recommended)
   - Download from: https://nsis.sourceforge.io/NsisXML_plug-in_(by_Joel)
   - Place NsisXML.dll in this directory
   - Used for: XML file manipulation and UTF-16 encoding (replaces PowerShell approach)

Alternative: If plugins are not available, the installer will fall back to the previous
implementation. However, using plugins eliminates PowerShell execution and reduces
antivirus false positives.

