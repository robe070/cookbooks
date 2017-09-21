@ECHO OFF
time /t
@REM -uq0 => Delete files from archive when they have been deleted from disk.
@REM redirect standard messages and errors to the log file but leave progress messages on the screen

7z u d:\symMS_backup.zip  -w  -uq0 -bso2 -bse2 c:\symMS\
time /t

7z u d:\symstore_framework_backup.zip -w -uq0 -bso2 -bse2 c:\symstore\framework\
time /t

7z u d:\pdbs_backup.zip   -w  -uq0 -bso2 -bse2 c:\pdbs\
time /t

7z u d:\symstore_sym_backup.zip -w -uq0 -bso2 -bse2 c:\symstore\sym
time /t

7z u d:\symstore_source_backup.zip -w -uq0 -bso2 -bse2 c:\symstore\source\
time /t


