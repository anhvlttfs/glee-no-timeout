#!/bin/bash

set -euo pipefail
trap 'echo "Error occurred at line ${LINENO} of ${BASH_SOURCE[0]}. Exiting..."; exit 1' ERR

#####################################
# Required binary (You should not change this)
OPENSSL_BIN=$(which openssl)
JQ_BIN=$(which jq)
XXD_BIN=$(which xxd)

# Get current date (You should not change this)
CURR_DATE=$(date +%F)

# License Branding Information (You can change this, note that empty value means no change for all)
NEW_USER_NAME="GitLab Support"
NEW_USER_EMAIL="support@gitlab.com"
NEW_USER_COMPANY="GitLab Inc."

# Active instance year (You can change this)
ACTIVE_INSTANCE_YEAR=25
EXPIRY_DAY=$(date -d "+$ACTIVE_INSTANCE_YEAR years" +%F)

# Your trial license file and key files (You must change this!)
LICENSE_ENCRYPTION_KEY_FILE="gitlab.pem"

# Encryption/Decryption paths (You should not change this)
DEFAULT_LICENSE_PATH="."
DEFAULT_DECRYTION_PATH="lic_decrypted"
DEFAULT_ENCRYPTION_PATH="lic_encrypted"
DEFAULT_INPUT_PATH="input"
DEFAULT_OUTPUT_PATH="output"

# Check if still keep the branding info from trial license
KEEP_TRIAL_BRANDING_INFO=false

# Input license file name (You can change this)
INPUT_LICENSE_FILE="old.gitlab-license"

# Output license file name (You can change this)
OUTPUT_JSON_LICENSE_FILE="gitlab-license.json"
OUTPUT_ENCRYPTED_LICENSE_FILE="new.gitlab-license"

# User limit
USER_LIMIT=2500

# GitLab Plan (either 'starter', 'premium' or 'ultimate') (You can change this)
GITLAB_PLAN="ultimate"

# End default values
#####################################
# Value validation (You should not change this)

if [ ! -f "$LICENSE_ENCRYPTION_KEY_FILE" ]; then
    echo "Public key file not found!"
    exit 1
fi

if [[ $NEW_USER_COMPANY == "" || $NEW_USER_EMAIL == ""  || $NEW_USER_NAME == "" ]]; then
    echo "An empty branding value detected. All branding info will be kept from trial license."
    KEEP_TRIAL_BRANDING_INFO=true
fi

if [[ $ACTIVE_INSTANCE_YEAR -le 0 ]]; then
    echo "Active instance year must be greater than 0."
    exit 1
fi

if [[ $OPENSSL_BIN == "" || $JQ_BIN == "" || $XXD_BIN == "" ]]; then
    echo "Required binary not found."
    exit 1
fi

if [ ! -f "$DEFAULT_INPUT_PATH/$INPUT_LICENSE_FILE" ]; then
    echo "Input license file not found!"
    exit 1
fi
#####################################
# Read user input for License File
TRIAL_LICENSE=""
for line in $(cat "$DEFAULT_INPUT_PATH/$INPUT_LICENSE_FILE"); do
    TRIAL_LICENSE="$TRIAL_LICENSE$line"
done

#####################################
# Prepare environment
if [ -f .gitignore ]; then
    rm .gitignore
    touch .gitignore
fi

echo $DEFAULT_DECRYTION_PATH >> .gitignore
echo $DEFAULT_ENCRYPTION_PATH >> .gitignore
echo $OUTPUT_JSON_LICENSE_FILE >> .gitignore
echo $OUTPUT_ENCRYPTED_LICENSE_FILE >> .gitignore

rm -rf $DEFAULT_DECRYTION_PATH $DEFAULT_ENCRYPTION_PATH $DEFAULT_OUTPUT_PATH || true;

mkdir -p $DEFAULT_DECRYTION_PATH
mkdir -p $DEFAULT_ENCRYPTION_PATH
mkdir -p $DEFAULT_OUTPUT_PATH
#####################################
# Decrypt the trial license file

echo $TRIAL_LICENSE | base64 -d > $DEFAULT_DECRYTION_PATH/license_encrypted.json

jq -r '.key' $DEFAULT_DECRYTION_PATH/license_encrypted.json > $DEFAULT_DECRYTION_PATH/license_encrypted.key
jq -r '.data' $DEFAULT_DECRYTION_PATH/license_encrypted.json > $DEFAULT_DECRYTION_PATH/license_encrypted.data
jq -r '.iv' $DEFAULT_DECRYTION_PATH/license_encrypted.json > $DEFAULT_DECRYTION_PATH/license_encrypted.iv

base64 -d $DEFAULT_DECRYTION_PATH/license_encrypted.key > $DEFAULT_DECRYTION_PATH/license_encrypted_key.bin
base64 -d $DEFAULT_DECRYTION_PATH/license_encrypted.data > $DEFAULT_DECRYTION_PATH/license_encrypted_data.bin
base64 -d $DEFAULT_DECRYTION_PATH/license_encrypted.iv > $DEFAULT_DECRYTION_PATH/license_encrypted_iv.bin

$OPENSSL_BIN rsautl -verify \
    -inkey "$LICENSE_ENCRYPTION_KEY_FILE" \
    -pubin -in $DEFAULT_DECRYTION_PATH/license_encrypted_key.bin \
    -out $DEFAULT_DECRYTION_PATH/aes.key

$XXD_BIN -p $DEFAULT_DECRYTION_PATH/aes.key | tr -d '\n' > $DEFAULT_DECRYTION_PATH/aes.hex
$XXD_BIN -p $DEFAULT_DECRYTION_PATH/license_encrypted_iv.bin  | tr -d '\n' > $DEFAULT_DECRYTION_PATH/iv.hex

$OPENSSL_BIN enc -aes-128-cbc -d \
    -in $DEFAULT_DECRYTION_PATH/license_encrypted_data.bin \
    -K "$(cat $DEFAULT_DECRYTION_PATH/aes.hex)" \
    -iv "$(cat $DEFAULT_DECRYTION_PATH/iv.hex)" \
    -out $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

#####################################
# Modify values

# Try change braning info
if [ "$KEEP_TRIAL_BRANDING_INFO" = false ] ; then
    $JQ_BIN \
        --arg name "$NEW_USER_NAME" \
        --arg email "$NEW_USER_EMAIL" \
        --arg company "$NEW_USER_COMPANY" \
        '.licensee.Name = $name | .licensee.Email = $email | .licensee.Company = $company' \
        $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE
fi

# Try change expiration date
$JQ_BIN \
    --arg issued_at "$CURR_DATE" \
    --arg expiry_date "$EXPIRY_DAY" \
    '.issued_at = $issued_at | .expires_at = $expiry_date | .notify_admins_at = $expiry_date | .notify_users_at = $expiry_date' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Try enable services
$JQ_BIN \
    '.cloud_licensing_enabled = true | .offline_cloud_licensing_enabled = true | .auto_renew_enabled = true | .seat_reconciliation_enabled = true | .operational_metrics_enabled = true' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Try change user limit
$JQ_BIN \
    --argjson user_limit $USER_LIMIT \
    '.restrictions.active_user_count = $user_limit' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Try change GitLab plan
$JQ_BIN \
    --arg plan "$GITLAB_PLAN" \
    '.restrictions.plan = $plan' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Try disable trial flag
$JQ_BIN \
    '.restrictions.trial = false | .restrictions.reconciliation_completed = true' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Beat up the limit
$JQ_BIN \
    --argjson user_limit $USER_LIMIT \
    '.restrictions.trueup_quantity = $user_limit | .restrictions.code_suggestions_seat_count = $user_limit' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

# Remove license ID signature (to avoid conflicts)
$JQ_BIN \
    'del(.restrictions.id)' \
    $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE > $DEFAULT_LICENSE_PATH/tmp.$$.json && mv $DEFAULT_LICENSE_PATH/tmp.$$.json $DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE

######################################
# Encrypt the new license file

cp $DEFAULT_DECRYTION_PATH/iv.hex $DEFAULT_ENCRYPTION_PATH/iv.hex
cp $DEFAULT_DECRYTION_PATH/aes.hex $DEFAULT_ENCRYPTION_PATH/aes.hex

$OPENSSL_BIN enc -aes-128-cbc -e \
    -in "$DEFAULT_OUTPUT_PATH/$OUTPUT_JSON_LICENSE_FILE" \
    -K "$(cat $DEFAULT_ENCRYPTION_PATH/aes.hex)" \
    -iv "$(cat $DEFAULT_ENCRYPTION_PATH/iv.hex)" \
    -out "$DEFAULT_ENCRYPTION_PATH/license_encrypted_data.bin"

cp $DEFAULT_DECRYTION_PATH/aes.hex $DEFAULT_ENCRYPTION_PATH/aes.hex
cp $DEFAULT_DECRYTION_PATH/iv.hex $DEFAULT_ENCRYPTION_PATH/iv.hex

tr -d '\n' < "$DEFAULT_ENCRYPTION_PATH/aes.hex" | $XXD_BIN -r -p > "$DEFAULT_ENCRYPTION_PATH/aes.key"
tr -d '\n' < "$DEFAULT_ENCRYPTION_PATH/iv.hex"  | $XXD_BIN -r -p > "$DEFAULT_ENCRYPTION_PATH/license_encrypted_iv.bin"

$OPENSSL_BIN rsautl -encrypt \
    -inkey "$LICENSE_ENCRYPTION_KEY_FILE" \
    -pubin -in "$DEFAULT_ENCRYPTION_PATH/aes.key" \
    -out "$DEFAULT_ENCRYPTION_PATH/license_encrypted_key.bin"

cp "$DEFAULT_DECRYTION_PATH/license_encrypted_key.bin" "$DEFAULT_ENCRYPTION_PATH/license_encrypted_key.bin"
cp "$DEFAULT_DECRYTION_PATH/license_encrypted_iv.bin" "$DEFAULT_ENCRYPTION_PATH/license_encrypted_iv.bin"

base64 "$DEFAULT_DECRYTION_PATH/license_encrypted_key.bin" > "$DEFAULT_DECRYTION_PATH/license_encrypted.key"
base64 "$DEFAULT_ENCRYPTION_PATH/license_encrypted_data.bin" > "$DEFAULT_DECRYTION_PATH/license_encrypted.data"
base64 "$DEFAULT_DECRYTION_PATH/license_encrypted_iv.bin" > "$DEFAULT_DECRYTION_PATH/license_encrypted.iv"

$JQ_BIN -n \
    --arg key "$(tr -d '\n' < "$DEFAULT_DECRYTION_PATH/license_encrypted.key")" \
    --arg data "$(tr -d '\n' < "$DEFAULT_DECRYTION_PATH/license_encrypted.data")" \
    --arg iv "$(tr -d '\n' < "$DEFAULT_DECRYTION_PATH/license_encrypted.iv")" \
    '{key: $key, data: $data, iv: $iv}' > "$DEFAULT_ENCRYPTION_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE".json

cat "$DEFAULT_ENCRYPTION_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE".json | base64 -w0 > "$DEFAULT_DECRYTION_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE"

GITLAB_KEY=$(cat "$DEFAULT_DECRYTION_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE")
for (( i=0; i<${#GITLAB_KEY}; i+=60 )); do
    echo -e -n "${GITLAB_KEY:i:60}\n" >> "$DEFAULT_OUTPUT_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE"
done

#####################################
# Cleanup and Notify user
rm -rf $DEFAULT_DECRYTION_PATH $DEFAULT_ENCRYPTION_PATH || true;

echo -e -n "\nGenerated successfully new license file:\n"
cat "$DEFAULT_OUTPUT_PATH/$OUTPUT_ENCRYPTED_LICENSE_FILE"

echo -e -n "\nNote: You may need to replace /opt/gitlab/embedded/service/gitlab-rails/.license_encryption_key.pub with this public key content:\n" 
cat "$LICENSE_ENCRYPTION_KEY_FILE"
echo -e -n "\n"
