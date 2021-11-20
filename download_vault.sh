#!/bin/bash
VAULT_VERSION=1.3.0
cd /tmp/
curl -sLo vault.zip https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip vault.zip
mkdir -p /usr/local/bin
mv vault /usr/local/bin
echo 'Now run: export PATH="/usr/local/bin:$PATH"'