#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { InfraStack } from '../lib/infra-stack';

const app = new cdk.App();

const webSite = new InfraStack(app, 'InfraStack', {
  env: {
    account: app.node.tryGetContext("account"),
    region: app.node.tryGetContext("region"),
  },
  domainName: "example.com",
  certificateArn: 'arn'
});


cdk.Tags.of(webSite).add("Project", "Angualr app")

app.synth()