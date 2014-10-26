#!/bin/bash
set -e

BASE_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../" && pwd )"
CMD_PATH="${BASH_SOURCE[0]}"
source $BASE_PATH/lstack.sh
source $BASE_PATH/install/creds.sh

needs_root

cexe "lstack" "nova --os-username $OS_USERNAME \
                    --os-password=$OS_PASSWORD \
                    --os-tenant-name $OS_TENANT_NAME \
                    --os-auth-url $OS_AUTH_URL $@"
