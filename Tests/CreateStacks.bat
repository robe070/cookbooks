set commonCFparms=--disable-rollback --capabilities CAPABILITY_IAM --template-url https://s3-ap-southeast-2.amazonaws.com/lansa/templates/lansa-master-win.cfn.template --parameters ParameterKey=4DBPassword,ParameterValue=Pcxuser122 ParameterKey=6WebPassword,ParameterValue=Pcxuser122 ParameterKey=7KeyName,ParameterValue=RobG_id_rsa ParameterKey=8RemoteAccessLocation,ParameterValue=103.231.159.65/32
call aws --region us-east-1      cloudformation create-stack --stack-name Virginia %commonCFparms%
call aws --region us-west-1      cloudformation create-stack --stack-name California %commonCFparms%
call aws --region us-west-2      cloudformation create-stack --stack-name Oregon %commonCFparms%
call aws --region eu-central-1   cloudformation create-stack --stack-name Frankfurt %commonCFparms%
call aws --region eu-west-1      cloudformation create-stack --stack-name Ireland %commonCFparms%
call aws --region ap-southeast-1 cloudformation create-stack --stack-name Singapore %commonCFparms%
call aws --region ap-southeast-2 cloudformation create-stack --stack-name Sydney %commonCFparms%
call aws --region ap-northeast-1 cloudformation create-stack --stack-name Tokyo %commonCFparms%
call aws --region sa-east-1      cloudformation create-stack --stack-name SaoPaulo %commonCFparms%
