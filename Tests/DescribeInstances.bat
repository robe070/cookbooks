@set region=ap-southeast-2
@echo Sydney %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=us-east-1
@echo Virginia %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=us-west-1
@echo California %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=us-west-2
@echo Oregon %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=eu-central-1
@echo Frankfurt %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=eu-west-1
@echo Ireland %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=ap-southeast-1
@echo Singapore %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=ap-northeast-1
@echo Tokyo %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"

@set region=sa-east-1
@echo Sao Paulo %region%
@call aws --region %region% --output text ec2 describe-instances --filters Name=instance-state-code,Values=16 --query "Reservations[*].Instances[*].[InstanceId]"
