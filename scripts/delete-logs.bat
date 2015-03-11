call aws logs delete-log-stream --log-group-name cfn-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name application-perf-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name event-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name iis-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name lansaweb-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name msi-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name win-update-logs  --log-stream-name %1
call aws logs delete-log-stream --log-group-name win-update-logs  --log-stream-name %1