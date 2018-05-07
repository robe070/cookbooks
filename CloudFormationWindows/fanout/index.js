'use strict';

console.log('Loading function');
var http = require('http');
var AWS = require('aws-sdk');

// The code outside of the handler is executed just the once. Make sure it doesn't need to be dynamic.

exports.handler = (event, context, callback) => {
    context.callbackWaitsForEmptyEventLoop = false; // Errors need to be returned ASAP

    let name = "you";
    let city = 'World';
    let time = 'day';
    let day = '';
    let responseCode = 200;
    //console.log("request: " + JSON.stringify(event));
    
    // This is a simple illustration of app-specific logic to return the response. 
    // Although only 'event.queryStringParameters' are used here, other request data, 
    // such as 'event.headers', 'event.pathParameters', 'event.body', 'event.stageVariables', 
    // and 'event.requestContext' can be used to determine what response to return. 
    //
    console.log("event.queryStringParameters" + JSON.stringify(event.queryStringParameters));
    if (event.queryStringParameters !== null && event.queryStringParameters !== undefined) {
        if (event.queryStringParameters.name !== undefined && 
            event.queryStringParameters.name !== null && 
            event.queryStringParameters.name !== "") {
            console.log("Received name: " + event.queryStringParameters.name);
            name = event.queryStringParameters.name;
        }
    }

    if (event.pathParameters !== null && event.pathParameters !== undefined) {
        if (event.pathParameters.proxy !== undefined && 
            event.pathParameters.proxy !== null && 
            event.pathParameters.proxy !== "") {
            console.log("Received proxy: " + event.pathParameters.proxy);
            city = event.pathParameters.proxy;
        }
    }
    
    if (event.headers !== null && event.headers !== undefined) {
        if (event.headers['day'] !== undefined && event.headers['day'] !== null && event.headers['day'] !== "") {
            console.log("Received day: " + event.headers.day);
            day = event.headers.day;
        }
    }
    
    if (event.body !== null && event.body !== undefined) {
        let body = JSON.parse(event.body)
        if (body.time) 
            time = body.time;
    }
 
    let greeting = 'Good ' + time + ', ' + name + ' of ' + city + '. ';
    if (day) greeting += 'Happy ' + day + '!';

    var responseBody = {
        message: greeting,
        input: event
    };
    
    // The output from a Lambda proxy integration must be 
    // of the following JSON object. The 'headers' property 
    // is for custom response headers in addition to standard 
    // ones. The 'body' property  must be a JSON string. For 
    // base64-encoded payload, you must also set the 'isBase64Encoded'
    // property to 'true'.
    var response = {
        statusCode: responseCode,
        headers: {
            "x-custom-header" : "my custom header value"
        },
        body: JSON.stringify(responseBody)
    };
    console.log("response: " + JSON.stringify(response))
    callback(null, response);

    return;

    // Any variables which need to be updated by multiple callbacks need to be declared before the first callback
    // otherwise each callback gets its own copy of the global.
    
    let instanceCount = 0;
    let successCodes = 0;
    
    let region = process.env.AWS_DEFAULT_REGION;

    //console.log('Received event:', JSON.stringify(event).substring(0,400));
    //console.log('context:', context);
    const message = event.Records[0].Sns.Message;
    const type = event.Records[0].Sns.Type;
    console.log('SNS Type:', type);
    //console.log('Message:', message.substring(0,100));
    
    let payload = JSON.parse(message); // converts it to a JS native object.
    // console.log('GitHub Payload:', JSON.stringify(message));
    console.log('GitHub Compare', JSON.stringify( payload.compare) );

    let route53 = new AWS.Route53();
    
    let paramsListRRS = {
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
            let error = new Error('Searched for Alias is not the one located');
            callback(error);                                         
        }
        
        console.log('ELB DNS Name: ', data.ResourceRecordSets[0].AliasTarget.DNSName);
        let DNSName = data.ResourceRecordSets[0].AliasTarget.DNSName;
        // e.g. paas-livb-webserve-ztessziszyzz-1633164328.us-east-1.elb.amazonaws.com.

        let DNSsplit = DNSName.split("."); 
        let ELBNameFull = '';
        let ELBsplit = '';
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
        let i;
        let ELBLowerCase = '';
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
        
        let elb = new AWS.ELB();
        let ec2 = new AWS.EC2();        
        
        // List all Load Balancers
        let params = {
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
            
            let i;
            let ELBNum = -1;
            let ELBCurrent = '';
            for (i = 0; i < data.LoadBalancerDescriptions.length; i++) {
                ELBCurrent =  data.LoadBalancerDescriptions[i].LoadBalancerName.toLowerCase();
                console.log( 'ELBCurrent: ', ELBCurrent );
                if ( ELBLowerCase === ELBCurrent) {
                    ELBNum = i;
                    break;
                }
            }            
            
            if ( ELBNum == -1 ) {
                let error = new Error('ELB Name not found');
                callback(error);                                         
                return;
            }
            let instances = data.LoadBalancerDescriptions[ELBNum].Instances;
            console.log('Instances: ', JSON.stringify(instances).substring(0,400));   

            // forEach is a Sync call
            Object.keys(instances).forEach(function(key) {
                console.log("InstanceId[" + key + "] " + JSON.stringify( instances[key].InstanceId ) );
                
                instanceCount++;
                
                let params = {
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
                    let PublicIpAddress = data.Reservations[0].Instances[0].PublicIpAddress;
                    // console.log("Host: ", JSON.stringify( PublicIpAddress ) );

                    // post the payload from GitHub
                    let post_data = JSON.stringify(message);

                    // console.log("post_data length: ", JSON.stringify( post_data.length ) );
                    
                    // An object of options to indicate where to post to
                    let post_options = {
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
                    let post_request = http.request(post_options, function(res) {
                        let body = '';
            
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
                            let error = new Error('Error ' + res.statusCode + ' posting to ' + post_options.host);
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
