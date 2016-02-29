set outputDir=bin
if not exist %outputDir% (mkdir %outputDir%)
"C:\Program Files (x86)\Embarcadero\RAD Studio\7.0\bin\dcc32.exe" -Q+  -Ebin  DelphiRayTracer.dpr
bin\DelphiRayTracer.exe 