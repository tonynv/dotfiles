#!/bin/bash
aws s3 cp $1 s3://tonynv-aws-cfn-validate/validate.json
aws cloudformation validate-template --template-url https://s3.amazonaws.com/tonynv-aws-cfn-validate/validate.json
