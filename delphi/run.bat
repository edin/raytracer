set outputDir=bin
if not exist %outputDir% (mkdir %outputDir%)
rem -$Q-  -$O+
"C:\Program Files (x86)\Embarcadero\RAD Studio\7.0\bin\dcc32.exe" -Ebin  DelphiRayTracer.dpr
bin\DelphiRayTracer.exe 