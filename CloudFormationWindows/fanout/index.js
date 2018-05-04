'use strict';

console.log('Loading function');
var http = require('http');
var AWS = require('aws-sdk');

// The code outside of the handler is executed just the once. Make sure it doesn't need to be dynamic.

exports.handler = (event, context, callback) => {
    context.callbackWaitsForEmptyEventLoop = false; // Errors need to be returned ASAP

    // Any variables which need to be updated by multiple callbacks need to be declared before the first callback
    // otherwise each callback gets its own copy of the global.
    
    var instanceCount = 0;
    var successCodes = 0;
    
    var region = process.env.AWS_DEFAULT_REGION;

    //console.log('Received event:', JSON.stringify(event).substring(0,400));
    //console.log('context:', context);
    const message = event.Records[0].Sns.Message;
    const type = event.Records[0].Sns.Type;
    console.log('SNS Type:', type);
    //console.log('Message:', message.substring(0,100));
    
    var payload = JSON.parse(message); // converts it to a JS native object.
    // console.log('GitHub Payload:', JSON.stringify(message));
    console.log('GitHub Compare', JSON.stringify( payload.compare) );

    var route53 = new AWS.Route53();
    
    var paramsListRRS = {
      HostedZoneId: 'Z2K4W96HUY1FNC', /* required - paas.lansa.com */
      MaxItems: '1',
      StartRecordName: 'testold.paas.lansa.com.',
      StartRecordType: 'A'
    };

    // Async call
    route53.listResourceRecordSets(paramsListRRS, function(err, data) {
        if (err) {
            console.log(err, err.stack); // an error occurred
            callback( err, err.stack );
            return;
        } 
        
        // successful response
        
        console.log('Searched for Alias: ', paramsListRRS.StartRecordName);
        console.log('Located Alias:      ', data.ResourceRecordSets[0].Name);
        if ( paramsListRRS.StartRecordName !== data.ResourceRecordSets[0].Name) {
            var error = new Error('Searched for Alias is not the one located');
            callback(error);                                         
        }
        
        console.log('ELB DNS Name: ', data.ResourceRecordSets[0].AliasTarget.DNSName);
        var DNSName = data.ResourceRecordSets[0].AliasTarget.DNSName;
        // e.g. paas-livb-webserve-ztessziszyzz-1633164328.us-east-1.elb.amazonaws.com.

        var DNSsplit = DNSName.split("."); 
        var ELBNameFull = '';
        var ELBsplit = '';
        console.log( 'DNSsplit[0]: ', DNSsplit[0]);
        if ( DNSsplit[0] === 'dualstack') {
            ELBNameFull = DNSsplit[1];
            region = DNSsplit[2];
        } else {
            ELBNameFull = DNSsplit[0];
            region = DNSsplit[1];
        }
        ELBsplit = ELBNameFull.split("-");
        ELBsplit.pop(); // remove last element

        // Put ELB Name back together again
        var i;
        var ELBLowerCase = '';
        for (i = 0; i < ELBsplit.length; i++) {
            ELBLowerCase += ELBsplit[i];
            if ( i < ELBsplit.length - 1 ) {
                ELBLowerCase += "-";
            }
        } 
        
        console.log( 'Region: ' + region );
        console.log( 'ELB:    ' + ELBLowerCase );
        
        AWS.config.update({region: region});
        
        // Need the region to be set before creating these variables.
        
        var elb = new AWS.ELB();
        var ec2 = new AWS.EC2();        
        
        // List all Load Balancers
        var params = {
          LoadBalancerNames: []
        };
        
        // Async call
        elb.describeLoadBalancers(function(err, data) {
            if (err) {
                console.log(err, err.stack); // an error occurred
                callback(err, err.stack); 
                return;
            }
            
            // successful response
            console.log('Instances: ', JSON.stringify(data.LoadBalancerDescriptions).substring(0,400));   
            console.log( 'length: ' , data.LoadBalancerDescriptions.length);
            
            // Find the lower case ELB name by listing all the load balancers in the region 
            // and doing a case insensitive compare
            
            var i;
            var ELBNum = -1;
            var ELBCurrent = '';
            for (i = 0; i < data.LoadBalancerDescriptions.length; i++) {
                ELBCurrent =  data.LoadBalancerDescriptions[i].LoadBalancerName.toLowerCase();
                console.log( 'ELBCurrent: ', ELBCurrent );
                if ( ELBLowerCase === ELBCurrent) {
                    ELBNum = i;
                    break;
                }
            }            
            
            if ( ELBNum == -1 ) {
                var error = new Error('ELB Name not found');
                callback(error);                                         
                return;
            }
            var instances = data.LoadBalancerDescriptions[ELBNum].Instances;
            console.log('Instances: ', JSON.stringify(instances).substring(0,400));   

            // forEach is a Sync call
            Object.keys(instances).forEach(function(key) {
                console.log("InstanceId[" + key + "] " + JSON.stringify( instances[key].InstanceId ) );
                
                instanceCount++;
                
                var params = {
                    DryRun: false,
                    InstanceIds: [
                        instances[key].InstanceId
                    ]
                };
                
                // Async call
                ec2.describeInstances(params, function(err, data) {
                    if (err) {
                        console.log(err, err.stack); // an error occurred
                        callback( err, err.stack );
                        return;
                    }
                    
                    // successful response
                    // console.log(data.Reservations[0].Instances[0]);        
                    var PublicIpAddress = data.Reservations[0].Instances[0].PublicIpAddress;
                    // console.log("Host: ", JSON.stringify( PublicIpAddress ) );

                    // post the payload from GitHub
                    var post_data = JSON.stringify(message);

                    // console.log("post_data length: ", JSON.stringify( post_data.length ) );
                    
                    // An object of options to indicate where to post to
                    var post_options = {
                        host: PublicIpAddress,
                        port: '8101',
                        path: '/Deployment/Start/APP2?source=sourceName',
                        method: 'POST',
                        headers: {
                            'Content-Type': 'application/json',
                            'Content-Length': post_data.length
                        }
                    };
                
                    // Async call
                    var post_request = http.request(post_options, function(res) {
                        var body = '';
            
                        if (res.statusCode === 200) {
                            successCodes++;
                            console.log('Application update successfully deployed by Lambda function to ' + post_options.host);
                            // console.log('successCodes: ' + successCodes + ' instanceCount: ' + instanceCount);
                            if ( successCodes >= instanceCount ){
                                console.log('Application update successfully deployed to stack ' + paramsListRRS.StartRecordName);  
                                
                                // Allow final states to be unwound before ending this invocation. E.g. Last 'End' is processed.
                                context.callbackWaitsForEmptyEventLoop = true; 
                                callback(null, 'Application update successfully deployed to stack ' + paramsListRRS.StartRecordName);  
                                context.callbackWaitsForEmptyEventLoop = false; 
                            }
                        } else {
                            var error = new Error('Error ' + res.statusCode + ' posting to ' + post_options.host);
                            callback(error ); 
                        }                        
                        
                        res.on('data', function(chunk)  {
                            body += chunk;
                        });
                
                        res.on('end', function() {
                            console.log( 'end ' + post_options.host );
                            // body is ready to return. Is this needed?
                        });
                
                        res.on('error', function(e) {
                            callback(e, 'error posting to EC2 instance: ' + post_options.host);                                         
                        });
                    });    
                    // post the data
                    console.log( 'Posting to:', post_options.host, post_options.path );
                    post_request.write(post_data);
                    post_request.end();
                });                
            });
        });
    });    
};
