#!/usr/bin/env bash

# A basic Droplet create request.
curl -X POST "https://api.digitalocean.com/v2/droplets" \
     -d'{"name":"'"$1"'","region":"nyc3","size":"512mb","private_networking":true,"image":"coreos-stable","user_data":
"'"$(cat ./tmp/cloud-config.yml)"'",
         "ssh_keys":[ "'$DO_SSH_KEY_FINGERPRINT'" ]}' \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json"