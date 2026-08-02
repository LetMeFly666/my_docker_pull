#!/bin/bash
###
 # @Author: LetMeFly
 # @Date: 2026-08-01 22:40:44
 # @LastEditors: LetMeFly.xyz
 # @LastEditTime: 2026-08-02 09:39:05
### 

set -euo pipefail

PORT=${PORT:-8759}
REPO="LetMeFly666/my_docker_pull"
IMAGE="${1:?Usage: $0 IMAGE}"
GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
CALLBACK_TOKEN="${CALLBACK_TOKEN:?CALLBACK_TOKEN is not set}"

REQ_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "Request ID: $REQ_ID"




echo "Dispatch workflow..."
curl \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/dispatches" \
    -d "
        {
            \"event_type\": \"update-docker\",
            \"client_payload\": {
                \"image\": \"$IMAGE\",
                \"req_id\": \"$REQ_ID\"
            }
        }
    "


# TODO: receiver must be ready before sender starts
nc -l 8759