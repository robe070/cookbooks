set commonCFparms=--disable-rollback --capabilities CAPABILITY_IAM --template-url https://s3-ap-southeast-2.amazonaws.com/lansa/templates/lansa-master-win.cfn.template --parameters ParameterKey=4DBPassword,ParameterValue=Pcxuser122 ParameterKey=6WebPassword,ParameterValue=Pcxuser122 ParameterKey=7KeyName,ParameterValue=RobG_id_rsa ParameterKey=8RemoteAccessLocation,ParameterValue=103.231.159.65/32
call aws --region us-east-1      cloudformation delete-stack --stack-name Virginia
call aws --region us-west-1      cloudformation delete-stack --stack-name California
call aws --region us-west-2      cloudformation delete-stack --stack-name Oregon
call aws --region eu-central-1   cloudformation delete-stack --stack-name Frankfurt
call aws --region eu-west-1      cloudformation delete-stack --stack-name Ireland
call aws --region ap-southeast-1 cloudformation delete-stack --stack-name Singapore
call aws --region ap-southeast-2 cloudformation delete-stack --stack-name Sydney
call aws --region ap-northeast-1 cloudformation delete-stack --stack-name Tokyo
call aws --region sa-east-1      cloudformation delete-stack --stack-name SaoPaulo
