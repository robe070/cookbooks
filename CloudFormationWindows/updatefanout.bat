REM Run in fanout subdirectory to update the lambda function in AWS
7z a h:\temp\fanout.zip
aws lambda update-function-code --function-name GitHubWebHookReplication --region us-east-1 --zip-file fileb://h:/temp/fanout.zip