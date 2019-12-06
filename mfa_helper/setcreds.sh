#!/usr/bin/env bash
#
# Person to blame when this doesn't work giovanni@oscillas.com
#
# Description: One step Docker login for use with AWS and Multi Factor Authentication
#
# Dependencies: ./jq
# https://stedolan.github.io/jq/
#
SEDCMD=''
GREPCMD=''
unameOut="$(uname -s)"
case "${unameOut}" in
    Linux*)     machine=Linux
                SEDCMD='sed'
                GREPCMD='grep'
                ;;
    Darwin*)    machine=Mac
                SEDCMD='gsed'
                GREPCMD='ggrep'
                ;;
    *)          echo "UNKNOWN:${unameOut}"
                exit 1
                ;;
esac

MFA_DEVICE_ARN=$($GREPCMD -Po "(?<=^MFA_DEVICE_ARN=).*$" ~/.aws/custom_config_options)
if [[ -n "$MFA_DEVICE_ARN" ]]; then
    echo Read MFA Device ARN from ~/.aws/custom_config_options successfully 
else
    echo "Please input your MFA device ARN, this will be saved to ~/aws/custom_config_options for future use..."
    read -p "MFA Device ARN: " MFA_DEVICE_ARN
    echo "MFA_DEVICE_ARN=$MFA_DEVICE_ARN" > ~/.aws/custom_config_options    
fi

echo "Authenticating for MFA Device: $MFA_DEVICE_ARN"
echo Please enter your AWS Multi Factor Token Code

read -p 'MFA Token: ' token
JSON=$(aws sts get-session-token --serial-number $MFA_DEVICE_ARN --token-code $token)

aws_secret_access_key=`echo ${JSON} | jq '.Credentials.SecretAccessKey'`
aws_session_token=`echo ${JSON} | jq '.Credentials.SessionToken'`
aws_access_key_id=`echo ${JSON} | jq '.Credentials.AccessKeyId'`

$SEDCMD -i -r "/\[mfa\]/,/\[/ s|(.*aws_secret_access_key.*)=.*$|\1= $aws_secret_access_key|" ~/.aws/credentials
$SEDCMD -i -r "/\[mfa\]/,/\[/ s|(.*aws_session_token.*)=.*$|\1= $aws_session_token|" ~/.aws/credentials
$SEDCMD -i -r "/\[mfa\]/,/\[/ s|(.*aws_access_key_id.*)=.*$|\1= $aws_access_key_id|" ~/.aws/credentials
$SEDCMD -i 's/\"//g' ~/.aws/credentials

echo Credentials successfully updated.
