#!/bin/bash

SCRIPTS_DIR="${BASH_SOURCE%/*}/"

ENVIRONMENT_DIR=$1
USERNAME=$2
ENCRYPTED_PASSWORD=$3
SERVER=$4
ENCRYPTED_CONTENT_ENCRYPTION_KEY=$5

if [ $# -ne 5 ]; then
	1>&2 echo "Usage: set-plastic-agents-config.sh <environment dir> <username> <encrypted password> <server> <encrypted content encryption key>"
	exit 1
fi

if [ ${ENCRYPTED_PASSWORD::5} != "|SoC|" ]; then
	1>&2 echo "Error: Encrypted password should begin with '|SoC|'"
	exit 1
fi

if [ ${ENCRYPTED_CONTENT_ENCRYPTION_KEY::5} != "|SoC|" ]; then
	1>&2 echo "Error: Encrypted content encryption key should begin with '|SoC|'"
	exit 1
fi

PROJECT_ID=`cat "${ENVIRONMENT_DIR}/gcloud-config.json" | jq -r ".project_id"`

if [ -z "${PROJECT_ID}" ]; then
	1>&2 echo "You must specify project_id in gcloud-config.json"
	exit 1
fi

"${SCRIPTS_DIR}/tools/activate-gcloud-project.sh" "${PROJECT_ID}" || exit 1

# Construct config files for Plastic:
# client.conf <- contains a lot of user settings, and username + encrypted password
# cryptedservers.conf <- references a single server/cloud organization, and an associated key file
# cryptedserver.key <- contains the encrypted content password for that server/cloud organization

SECURITY_CONFIG="::0:${USERNAME}:${ENCRYPTED_PASSWORD:5}:" # The string in client.conf should not include the '|SoC|' prefix

SERVER=${SERVER} SECURITY_CONFIG=${SECURITY_CONFIG} envsubst < "${SCRIPTS_DIR}/../application/plastic/client.conf.template" > "${SCRIPTS_DIR}/client.conf"
SERVER=${SERVER} envsubst < "${SCRIPTS_DIR}/../application/plastic/cryptedservers.conf.template" > "${SCRIPTS_DIR}/cryptedservers.conf"
ENCRYPTED_CONTENT_ENCRYPTION_KEY=${ENCRYPTED_CONTENT_ENCRYPTION_KEY} envsubst < "${SCRIPTS_DIR}/../application/plastic/cryptedserver.key.template" > "${SCRIPTS_DIR}/cryptedserver.key"

# Add .zipped config files to GCP's Secrets Manager
# These will be used by non-Kubernetes build jobs on Windows

(cd "${SCRIPTS_DIR}" && zip plastic-config.zip client.conf cryptedservers.conf cryptedserver.key >/dev/null)

if `gcloud secrets describe plastic-config-zip >/dev/null 2>&1`; then
	gcloud secrets versions add plastic-config-zip "--data-file=${SCRIPTS_DIR}/plastic-config.zip"
else
	gcloud secrets create plastic-config-zip "--data-file=${SCRIPTS_DIR}/plastic-config.zip"
fi
gcloud secrets add-iam-policy-binding plastic-config-zip --member=serviceAccount:ue-jenkins-agent-vm@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor

# Add .tgz'ed config files to GCP's Secrets Manager
# These will be used by non-Kubernetes build jobs on Linux

(cd "${SCRIPTS_DIR}" && tar -czvf plastic-config.tgz client.conf cryptedservers.conf cryptedserver.key >/dev/null)

if `gcloud secrets describe plastic-config-tgz >/dev/null 2>&1`; then
	gcloud secrets versions add plastic-config-tgz "--data-file=${SCRIPTS_DIR}/plastic-config.tgz"
else
	gcloud secrets create plastic-config-tgz "--data-file=${SCRIPTS_DIR}/plastic-config.tgz"
fi
gcloud secrets add-iam-policy-binding plastic-config-tgz --member=serviceAccount:ue-jenkins-agent-vm@${PROJECT_ID}.iam.gserviceaccount.com --role=roles/secretmanager.secretAccessor

# Remove temp files

rm "${SCRIPTS_DIR}/client.conf" "${SCRIPTS_DIR}/cryptedservers.conf" "${SCRIPTS_DIR}/cryptedserver.key" "${SCRIPTS_DIR}/plastic-config.zip" "${SCRIPTS_DIR}/plastic-config.tgz"
