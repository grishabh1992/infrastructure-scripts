import * as cdk from '@aws-cdk/core';
import * as s3 from '@aws-cdk/aws-s3';
import * as cloudfront from '@aws-cdk/aws-cloudfront';
import * as route53 from '@aws-cdk/aws-route53';
import * as targets from "@aws-cdk/aws-route53-targets";

export interface WebProps extends cdk.StackProps {
  domainName: string;
  certificateArn: string;
}

export class InfraStack extends cdk.Stack {
  constructor(scope: cdk.Construct, id: string, props: WebProps) {
    super(scope, id, props);

    const zone = route53.HostedZone.fromLookup(this, "Zone", {
      domainName: props.domainName,
    })

    const bucketName = props.domainName;

    // The code that defines your stack goes here
    const bucket = new s3.Bucket(this, `${props.domainName}`, {
      bucketName,
    });
    const accessIdentity = new cloudfront.OriginAccessIdentity(this, 'Identity', {
      comment: `OAI ${props.domainName}`,
    });
    bucket.grantRead(accessIdentity);

    // CloudFront distribution that provides HTTPS
    const distribution = new cloudfront.CloudFrontWebDistribution(this, 'webDistriution', {
      // Incase you want to add already added certificate
      // By Default default Cloudfront Certificate will apply
      aliasConfiguration: {
        acmCertRef: props.certificateArn,
        names: [props.domainName],
        sslMethod: cloudfront.SSLMethod.SNI,
        securityPolicy: cloudfront.SecurityPolicyProtocol.TLS_V1_1_2016,
      },
      originConfigs: [
        {
          originPath: '',
          s3OriginSource: {
            s3BucketSource: bucket,
            originAccessIdentity: accessIdentity,
          },
          behaviors: [
            {
              allowedMethods: cloudfront.CloudFrontAllowedMethods.GET_HEAD,
              cachedMethods: cloudfront.CloudFrontAllowedCachedMethods.GET_HEAD,
              minTtl: cdk.Duration.seconds(0),
              isDefaultBehavior: true,
            }
          ]
        }
      ],
      defaultRootObject: 'index.html',
      errorConfigurations: [
        {
          errorCachingMinTtl: 60,
          errorCode: 404,
          responseCode: 200,
          responsePagePath: '/index.html'
        },
      ]
    });

    new cdk.CfnOutput(this, "DistributionId", {
      value: distribution.distributionId,
    });

    // Route53 alias record for the CloudFront distribution
    new route53.ARecord(this, "SiteAliasRecord", {
      recordName: props.domainName,
      target: route53.RecordTarget.fromAlias(
        new targets.CloudFrontTarget(distribution)
      ),
      zone,
    });
  }
}
