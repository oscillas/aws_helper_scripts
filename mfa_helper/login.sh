#!/usr/bin/env bash
#
# Person to blame when this doesn't work giovanni@oscillas.com
#
# Description: One step Docker login for use with AWS and Multi Factor Authentication
#
# Dependencies: ./jq
# https://stedolan.github.io/jq/

set -e

trap 'echo -e "\nAborted due to error" && exit 1' ERR
trap 'echo -e "\nAborted by user" && exit 1' SIGINT

readonly _CONFIG_FILE="$HOME/.aws/custom_config_options"

main() {
    parse_opts
    detect_os
    load_config

    update_credentials

    if [ "$DOCKER_FLAG" = true ]; then
        docker_login
    fi
}

print_usage() {
    echo "don't ever speak to me or my son again"
}

parse_opts() {
    while getopts 'DP:' flag; do
        case "${flag}" in
            D) DOCKER_FLAG=true ;;
            P) AWS_PROFILE="${OPTARG}" ;;
            *) print_usage
               exit 1 ;;
        esac
    done

    if [ $DOCKER_FLAG = true ] && [[ -z $AWS_PROFILE ]]; then
        print_usage
        exit 1
    fi
}

detect_os() {
    local os
    os="$(uname -s)"

    case "${os}" in
        Linux*)
            sedCmd='sed'
            grepCmd='grep'
            ;;
        Darwin*)
            sedCmd='gsed'
            grepCmd='ggrep'
            ;;
        *)
            echo "Unsupported environment: ${os}"
            exit 1
            ;;
    esac
}

load_config() {
    MFA_DEVICE_ARN=$($grepCmd -Po "(?<=^MFA_DEVICE_ARN=).*$" "${_CONFIG_FILE}")

    if [[ -n "$MFA_DEVICE_ARN" ]]; then
        echo "Successfully read MFA Device ARN read from ${_CONFIG_FILE}."
        return
    fi

    echo "Please input your MFA device ARN. This will be saved to ${_CONFIG_FILE} for future use..."
    read -rp "MFA Device ARN: " MFA_DEVICE_ARN

    echo "MFA_DEVICE_ARN=$MFA_DEVICE_ARN" >> "${_CONFIG_FILE}"
}

update_credentials() {
    local json token

    authenticate_device

    set_credential "secret_access_key" "$(echo "${json}" | jq '.Credentials.SecretAccessKey')"
    set_credential "session_token" "$(echo "${json}" | jq '.Credentials.SessionToken')"
    set_credential "access_key_id" "$(echo "${json}" | jq '.Credentials.AccessKeyId')"
    strip_quotes

    echo Credentials successfully updated.
}

authenticate_device() {
    echo "Authenticating for MFA Device: $MFA_DEVICE_ARN"
    echo Please enter your AWS Multi Factor Token Code

    read -rp 'MFA Token: ' token

    json=$(aws sts get-session-token --serial-number "${MFA_DEVICE_ARN}" --token-code "${token}")
}

set_credential() {
    local option="aws_${1}" value="${2}"

    ${sedCmd} -i -r "/\[mfa\]/,/\[/ s|(.*${option}.*)=.*$|\1= ${value}|" ~/.aws/credentials
}

strip_quotes() {
    ${sedCmd} -i 's/\"//g' ~/.aws/credentials
}

docker_login() {
    eval "$(aws ecr get-login --no-include-email --profile "${AWS_PROFILE}")"
}

main
