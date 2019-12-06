#!/usr/bin/env bash
#
# Person to blame when this doesn't work giovanni@oscillas.com
#
# Description: One step Docker login for use with AWS and Multi Factor Authentication
#
# Dependencies: ./jq
# https://stedolan.github.io/jq/
#

echo Please enter your AWS Multi Factor Token Code

read -p 'MFA Token: ' token

JSON="$(aws sts get-session-token --serial-number
arn:aws:iam::ACCOUNT_NUMBER:mfa/ACCOUNT_NAME --token-code $token)"

aws_secret_access_key=`echo ${JSON} | jq '.Credentials.SecretAccessKey'`
aws_session_token=`echo ${JSON} | jq '.Credentials.SessionToken'`
aws_access_key_id=`echo ${JSON} | jq '.Credentials.AccessKeyId'`


gsed -i "0,/aws_access_key_id/! s/\(^aws_access_key_id = \).*/\1${aws_access_key_id//\//\/}/" ~/.aws/credentials
gsed -i "0,/aws_secret_access_key/! s/\(^aws_secret_access_key = \).*/\1${aws_secret_access_key//\//\/}/" ~/.aws/credentials
gsed -i "s/\(^aws_session_token = \).*/\1${aws_session_token//\//\/}/" ~/.aws/credentials

echo $aws_secret_access_key
echo $aws_session_token
echo $aws_access_key_id

gsed -i 's/\"//g' ~/.aws/credentials

dockerLogin=$(aws ecr get-login --region us-east-1 --no-include-email --profile podestaadmin)

eval $dockerLogin

echo Credentials successfully updated.
