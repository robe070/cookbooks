@echo Copy changed objects to temporary holding area for upload to Cloud
set lansaroot=c:\dev\l4w14000\work
set integratorroot=c:\dev\IntegratorReleases\LIN14000_EPC140005\integrator
set holdingroot=c:\temp
set vldir=VL-latest
set integratordir=Integrator-latest
@REM IDE
copy %lansaroot%\lansa\lansa.exe %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\liis.dll %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\liio.dll %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\liiy.dll %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\x_prim.dll %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\x_rdrvo40.dll %HOLDINGROOT%\VL-LATEST\LANSA
copy %lansaroot%\lansa\x_wpf40.dll %HOLDINGROOT%\VL-LATEST\LANSA

@REM Runtime
copy %lansaroot%\x_win95\x_lansa\execute\x_dll.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_run.exe %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_pdfms.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_comp.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_prim.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_wpf40.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\x_rdrvo40.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\xvdapi01.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\xvfcltdt.dll %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute
copy %lansaroot%\x_win95\x_lansa\execute\lxptbbld.exe %HOLDINGROOT%\VL-LATEST\x_win95\x_lansa\execute

@REM Integrator
copy %integratorroot%\jsf.jsm.windows\jsmmgrsrv\x64\Release\jsmmgrsrv.dll %HOLDINGROOT%\Integrator-LATEST\JSMInstance\system
copy %integratorroot%\jsf.jsm.windows\jsmsupp\x64\Release\jsmsupp.exe %HOLDINGROOT%\Integrator-LATEST\JSMInstance\system

