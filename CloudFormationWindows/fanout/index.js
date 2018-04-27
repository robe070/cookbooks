'use strict';

console.log('Loading function');

var AWS = require('aws-sdk');

//const http = require('http');
//const keepAliveAgent = new http.Agent({ keepAlive: true });
//options.agent = keepAliveAgent;
//http.request(options, onResponseCallback);

function error(e){
  console.log('--Error--', this.type);
  console.log('this: ', this);
  console.log('Event: ', e);
}

// The code outside of the handler is executed just the once. Make sure it doesn't need to be dynamic.

// AWS.config.update({region: 'us-west-2'});
    
exports.handler = (event, context, callback) => {
    
    function success(s){
        console.log( 'Successful');
        callback(null, 'Successfully deployed by lambda');
    }

    var autoscaling = new AWS.AutoScaling();
    var ec2 = new AWS.EC2();
    var http = require('http');

    var region = process.env.AWS_DEFAULT_REGION;
    console.log( 'Region:', region);

    //console.log('Received event:', JSON.stringify(event).substring(0,400));
    //console.log('context:', context);
    const message = event.Records[0].Sns.Message;
    const type = event.Records[0].Sns.Type;
    console.log('Type:', type);
    console.log('Message:', message.substring(0,100));
    
    var payload = JSON.parse(message); // converts it to a JS native object.
    // console.log('GitHub Payload:', JSON.stringify(message));
    console.log('Compare', JSON.stringify( payload.compare) );

    var params = {
      AutoScalingGroupNames: [
        'paas-DBWebServerGroup-VARFKK0N13HZ',
        'paas-WebServerGroup-RX7E70X39OLG'
      ],
      MaxRecords: 50
    };
    autoscaling.describeAutoScalingGroups(params, function(err, data) {
        if (err) {
            console.log(err, err.stack); // an error occurred
            callback(err, err.stack); 
        } else {
            // successful response
            // console.log('Groups: ', data.AutoScalingGroups);
            
            Object.keys(data.AutoScalingGroups).forEach(function(group) {
                console.log('AutoScalingGroupName: ', data.AutoScalingGroups[group].AutoScalingGroupName);           
                var instances = data.AutoScalingGroups[group].Instances;
                Object.keys(instances).forEach(function(key) {
                    console.log("InstanceId[" + key + "] " + JSON.stringify( instances[key].InstanceId ) );
                    
                    var params = {
                        DryRun: false,
                        InstanceIds: [
                            instances[key].InstanceId
                        ]
                    };
                    ec2.describeInstances(params, function(err, data) {
                        if (err) console.log(err, err.stack); // an error occurred
                        else {
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
                        
                            var post_request = http.request(post_options, function(res) {
                                var body = '';
                        
                                if (res.statusCode === 200) {
                                    context.succeed('Application update successfully deployed by Lambda function to ' + post_options.path);
                                } else {
                                    context.fail('status code: ' + res.statusCode);
                                }                        
                                res.on('data', function(chunk)  {
                                    body += chunk;
                                });
                        
                                res.on('end', function() {
                                    context.done(body);
                                });
                        
                                res.on('error', function(e) {
                                    context.fail('error posting to EC2 instance:' + e.message);
                                });
                            });    
                            // post the data
                            console.log( 'Posting to:', post_options.host, post_options.path );
                            post_request.write(post_data);
                            post_request.end();
                        }
                    });                
                });
            });
        }
    });
    
};
