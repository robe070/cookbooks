@set commonparams=--output table rds describe-db-instances --query "DBInstances[*].[AvailabilityZone,DBInstanceIdentifier,DBInstanceStatus,Engine]"
@call aws --region us-east-1      %commonparams%
@call aws --region us-west-1      %commonparams%
@call aws --region us-west-2      %commonparams%
@call aws --region eu-central-1   %commonparams%
@call aws --region eu-west-1      %commonparams%
@call aws --region ap-southeast-1 %commonparams%
@call aws --region ap-southeast-2 %commonparams%
@call aws --region ap-northeast-1 %commonparams%
@call aws --region sa-east-1      %commonparams%
