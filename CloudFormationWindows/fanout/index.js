'use strict';

console.log('Loading function');
var http = require('http');
var AWS = require('aws-sdk');
var ipRangeCheck = require('ip-range-check');


// The code outside of the handler is executed just the once. Make sure it doesn't need to be dynamic.

// Errors are formatted for processing by the API Gateway so that a caller gets useful diagnostics.
// So notice that it doesn't call callback( err ) as the caller would end up with a 502 error and no message or stack trace.
// Thus all calls to this Lambda function are 'successful'. It requires the API Gateway to interpret the statusCode
// and return that to the caller as the HTTP response.
function returnAPIError( statusCode, message, callback, context) {
    // Construct an error object so that we can omit returnAPIError from the stack trace
    const myObject = {};
    Error.captureStackTrace(myObject, returnAPIError);

    let responseBody = {
        errorMessage: message + ' (using ' + context.invokedFunctionArn + ')',
        stackTrace: (myObject.stack)
    };
    console.log( "responseBody: ", responseBody);
    let response = {
        statusCode: statusCode,
        body: JSON.stringify(responseBody)
    };    
    if (callback) {
        callback( null, response);
    }
    
    return response;
}

exports.handler = (event, context, callback) => {
    context.callbackWaitsForEmptyEventLoop = false; // Errors need to be returned ASAP

    let hostedzoneid = '';
    let alias = '';
    let port = 8101;
    let appl = '';
    let accountwide='n';
    let repo = '';

    console.log('event.requestContext.identity: ', event.requestContext.identity );
    console.log('context: ', context );

    // Check that sender is a GitHub server
    // 192.168.196.186 is the ip address of the test server
    // 103.231.169.65/32 is the ip address of LPC
    if ( !ipRangeCheck( event.requestContext.identity.sourceIp, ['185.199.108.0/22', '192.30.252.0/22','103.231.169.65/32','192.168.196.186']) ) {
        returnAPIError( 403, "Source ip " + event.requestContext.identity.sourceIp + ' is not from a github server', callback, context);
        return;
    }
    
    // *******************************************************************************************************
    // Parameter setup
    // *******************************************************************************************************
    
    // The body is not proper JSON. It looks like its not in the expected code page
    // performing for(var key in bodyobj)( console.log(bodyobj[key])}
    // outputs a single line character for every character in the body!
    
    // So, this code cleans the string up and then searches for whats is needed - the git repo name
    
    let bodyoriginal = JSON.stringify(event.body);
    
    let bodyclean = bodyoriginal.replace(/(^\s+|\s+$|\\r?\\n|\\r|\t| |\\)/g, "");
    console.log( "bodyclean: ", bodyclean.substring(0,200));
    
    let repository_pos = bodyclean.indexOf('repository');
    console.log( "repository_pos: ", repository_pos );
    let name_pos = bodyclean.indexOf('"name":', repository_pos);
    
    if ( name_pos !== -1) {
        console.log("name_pos: ", bodyclean.substring(name_pos, name_pos + 20 ));
        let start_pos = bodyclean.indexOf(':"', name_pos);
        if ( start_pos !== -1) {
            console.log( "start_pos: ", start_pos );
            let end_pos = bodyclean.indexOf('",', start_pos);
            repo = bodyclean.substring(start_pos + 2, end_pos);
            console.log("git repo:: ", repo);
        }
    }

    if (repo === '') {
        console.log( "Warning: Repository name not found");
    }
    
    //*************************
    // Don't use secret as can't get secret to match up because of the issues with the payload not being of the expected format.
    
    // var crypto    = require('crypto');

    // var secret    = 'abcdeg'; //make this your secret!!
    // var algorithm = 'sha1';   //consider using sha256
    // var hash, hmac;
    
    // let signature = event.headers['X-Hub-Signature'];
    // console.log( 'signature: ', signature );
    
    // // Method 1 - Writing to a stream
    // hmac = crypto.createHmac(algorithm, secret);    
    // hmac.write(bodyclean); // write in to the stream
    // hmac.end();       // can't read from the stream until you call end()
    // hash = hmac.read().toString('hex');    // read out hmac digest
    // console.log("Method 1 clean: ", hash);
    
    // let hmac2 = crypto.createHmac(algorithm, secret);    
    // hmac2.write(JSON.stringify(event.body)); // write in to the stream
    // hmac2.end();       // can't read from the stream until you call end()
    // hash = hmac2.read().toString('hex');    // read out hmac digest
    // console.log("Method 1 event.body: ", hash);
    //*****************************************************
    
    console.log("event.queryStringParameters" + JSON.stringify(event.queryStringParameters));

    if (event.queryStringParameters !== null && event.queryStringParameters !== undefined) {
        if (event.queryStringParameters.hostedzoneid !== undefined && 
            event.queryStringParameters.hostedzoneid !== null && 
            event.queryStringParameters.hostedzoneid !== "") {
            hostedzoneid = event.queryStringParameters.hostedzoneid;
            console.log("Received hostedzoneid: " + hostedzoneid);
        }

        
        if (event.queryStringParameters.alias !== undefined && 
            event.queryStringParameters.alias !== null && 
            event.queryStringParameters.alias !== "") {
            alias = event.queryStringParameters.alias;
            console.log("Received alias: " + alias);
        }
        
        if (event.queryStringParameters.port !== undefined && 
            event.queryStringParameters.port !== null && 
            event.queryStringParameters.port !== "") {
            port = event.queryStringParameters.port;
            console.log("Received port: " + port);
        }

        if (event.queryStringParameters.appl !== undefined && 
            event.queryStringParameters.appl !== null && 
            event.queryStringParameters.appl !== "") {
            appl = event.queryStringParameters.appl;
            console.log("Received appl: " + appl);
        }
        
        if (event.queryStringParameters.accountwide !== undefined && 
            event.queryStringParameters.accountwide !== null && 
            event.queryStringParameters.accountwide !== "") {
            accountwide = event.queryStringParameters.accountwide;
            console.log("Received accountwide: " + accountwide);
        }
    }

    if ( repo === '' && accountwide === 'y') {
        returnAPIError( 400, "Error 400 accountwide parameter is set to 'y' but the git repo name cannot be located. Use repo-specific webhook and explicitly specify alias and appl instead", callback, context);
        return;
    }
    
    if ( accountwide !== 'n' && accountwide !== 'y') {
        returnAPIError( 400, "Error 400 accountwide parameter must be 'y' or 'n'. Defaults to 'n'", callback, context);
        return;
    }
    
    // Mandatory parameters
    if ( hostedzoneid === "" ) {
        returnAPIError( 400, 'Error 400 hostedzoneid is a mandatory parameter', callback, context);
        return;
    }
    if ( accountwide === 'n' && (alias === "" || appl === "") ) {
        returnAPIError( 400, "Error 400 when accountwide = 'n', alias and appl are mandatory parameters", callback, context);
        return;
    }
    
    if ( accountwide === 'y' && (alias !== "" || appl !== "") ) {
        returnAPIError( 400, "Error 400 when accountwide = 'y', alias and appl must not be specified", callback, context);
        return;
    }
    
    // If accountwide webhook then derive alias and appl from the repo name
    if ( accountwide === 'y') {
        // The repo number indicates the stack and appl to use
        // lansaeval1 - lansaeval10 use stack 1 and appl 1 - 10
        // lansaeval11 - lansaeval20 use stack 2 and appl 1 - 10
        // etc
        let lansarepo = repo.indexOf('lansaeval');
        if ( lansarepo !== 0) {
            returnAPIError( 400, "Error 400 only lansaevalxxx repo names are supported. All other repo names require explicit alias and appl parameters", callback, context);
            return;            
        }
        
        let repoNumber = repo.match( /\d+/g );  
        console.log( "repoNumber: ", repoNumber.toString() );

        let stack = Math.ceil(repoNumber / 10);
        console.log( "stack: ", stack.toString() );
        
        if ( stack < 1 || stack > 10 ){
            returnAPIError( 400, "Error 400 Repository name " + repo + " invalid. Resolves to stack " + stack + " which is less than 1 or greater than 10", callback, context);
            return;               
        }
        
        let applnum = repoNumber % 10;
        if ( applnum === 0) {
            applnum = 10;
        }
        console.log( "applnum: ", applnum.toString() );

        if ( applnum < 1 || applnum > 10 ){
            returnAPIError( 400, "Error 400 Repository name " + repo + " invalid. Resolves to application " + applnum + " which is less than 1 or greater than 10", callback, context);
            return;               
        }
        
        alias = 'eval' + stack.toString() + '.paas.lansa.com.';
        appl = 'app' + applnum.toString();
        
        console.log( "Using alias: %s, appl: %s", alias, appl);
    }
    
    // *******************************************************************************************************
    // Resolving EC2 ip addresses and posting github webhook to each one
    // *******************************************************************************************************
    
    // Any variables which need to be updated by multiple callbacks need to be declared before the first callback
    // otherwise each callback gets its own copy of the global.
    
    let instanceCount = 0;
    let successCodes = 0;
    
    let region = process.env.AWS_DEFAULT_REGION;

    let route53 = new AWS.Route53();
    
    let paramsListRRS = {
      HostedZoneId: hostedzoneid, /* required - paas.lansa.com */
      MaxItems: '1',
      StartRecordName: alias,
      StartRecordType: 'A'
    };

    // Async call
    route53.listResourceRecordSets(paramsListRRS, function(err, data) {
        if (err) {
            console.log(err, err.stack); // an error occurred
            returnAPIError( 500, err.message, callback, context);
            return;
        } 
        
        // successful response
        
        console.log('Searched for Alias: ', paramsListRRS.StartRecordName);
        if (data.ResourceRecordSets[0] === undefined || 
            data.ResourceRecordSets[0] === null || 
            data.ResourceRecordSets[0] === "") {
            
            console.log('Alias not found');
            returnAPIError( 500, 'Alias ' + paramsListRRS.StartRecordName + ' not found', callback, context);
            return;
        }
 
        console.log('Located Alias:      ', data.ResourceRecordSets[0].Name);
        if ( paramsListRRS.StartRecordName !== data.ResourceRecordSets[0].Name) {
            returnAPIError( 500, 'Searched for Alias is not the one located', callback, context);
            return;
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
        
        // Async call
        elb.describeLoadBalancers(function(err, data) {
            if (err) {
                console.log(err, err.stack); // an error occurred
                returnAPIError( 500, err.message, callback, context);
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
                returnAPIError( 500, 'ELB Name not found', callback, context);
                return;
            }

            let instances = data.LoadBalancerDescriptions[ELBNum].Instances;
            if (instances.length === 0) {
                returnAPIError( 500, 'No instances running in ELB ' + ELBCurrent, callback, context);
                return;               
            }
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
                        returnAPIError( 500, err.message, callback, context);
                        return;
                    }
                    
                    // successful response
                    // console.log(data.Reservations[0].Instances[0]);        
                    let PublicIpAddress = data.Reservations[0].Instances[0].PublicIpAddress;
                    // console.log("Host: ", JSON.stringify( PublicIpAddress ) );

                    // post the payload from GitHub
                    let post_data = '';

                    // console.log("post_data length: ", JSON.stringify( post_data.length ) );
                    
                    // An object of options to indicate where to post to
                    let post_options = {
                        host: PublicIpAddress,
                        port: port,
                        path: '/Deployment/Start/' + appl + '?source=GitHubWebHookReplication',
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
                                let message = 'Application update successfully deployed to stack ' + paramsListRRS.StartRecordName + ' application ' + appl + ' repo ' + repo + ' using ' + context.invokedFunctionArn;
                                console.log(message);  
                                
                                let responseBody = {
                                    message: message,
                                    input: event.queryStringParameters
                                };
                                
                                // The output from a Lambda proxy integration must be 
                                // of the following JSON object. The 'headers' property 
                                // is for custom response headers in addition to standard 
                                // ones. The 'body' property  must be a JSON string. For 
                                // base64-encoded payload, you must also set the 'isBase64Encoded'
                                // property to 'true'.
                                let response = {
                                    statusCode: res.statusCode,
                                    headers: {
                                        "x-custom-header" : "my custom header value"
                                    },
                                    body: JSON.stringify(responseBody)
                                };
                                console.log("response: " + JSON.stringify(response));
                                
                                // Allow final states to be unwound before ending this invocation. E.g. Last 'End' is processed.
                                context.callbackWaitsForEmptyEventLoop = true; 
                                callback(null, response);                                
                                context.callbackWaitsForEmptyEventLoop = false; 
                            }
                        } else {
                            returnAPIError( res.statusCode, 'Error ' + res.statusCode + ' posting to ' + post_options.host + ':' + port + post_options.path, callback, context);
                            return;
                        }                        
                        
                        res.on('data', function(chunk)  {
                            body += chunk;
                        });
                
                        res.on('end', function() {
                            console.log( 'end ' + post_options.host );
                            // body is ready to return. Is this needed?
                        });
                
                        res.on('error', function(e) {
                            returnAPIError( e.code, e.message + ' Error ' + res.statusCode + ' posting to ' + post_options.host + ':' + port + post_options.path, callback, context);
                            return;
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
