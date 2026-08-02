#!/bin/bash
###
 # @Author: LetMeFly
 # @Date: 2026-08-01 22:40:44
 # @LastEditors: LetMeFly.xyz
 # @LastEditTime: 2026-08-02 14:05:34
### 

set -euo pipefail

PORT=${PORT:-8759}
REPO="LetMeFly666/my_docker_pull"
IMAGE="${1:?Usage: $0 IMAGE}"
GITHUB_TOKEN="${GITHUB_TOKEN:?GITHUB_TOKEN is not set}"
CALLBACK_TOKEN="${CALLBACK_TOKEN:?CALLBACK_TOKEN is not set}"

REQ_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
echo "Request ID: $REQ_ID"

ALIYUN_VPC=false
shift || true
while [[ $# -gt 0 ]]; do
    case "$1" in
        --aliyun-vpc)
            ALIYUN_VPC=true
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

echo "Starting callback server"


coproc CALLBACK_SERVER {
    python3 callback_server.py \
        --port "$PORT" \
        --req-id "$REQ_ID" \
        --token "$CALLBACK_TOKEN"
}

cleanup() {
    if [ -n "${CALLBACK_SERVER_PID:-}" ] && kill -0 "$CALLBACK_SERVER_PID" 2>/dev/null; then
        echo "Stopping callback server..."
        kill "$CALLBACK_SERVER_PID" 2>/dev/null || true
        wait "$CALLBACK_SERVER_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM


# sleep 1


echo "Dispatch workflow..."


curl \
    -X POST \
    -H "Accept: application/vnd.github+json" \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/dispatches" \
    -d "
        {
            \"event_type\": \"docker-pull\",
            \"client_payload\": {
                \"image\": \"$IMAGE\",
                \"req_id\": \"$REQ_ID\"
            }
        }
    "


echo "waiting callback..."

read -r CALLBACK_RESULT <&"${CALLBACK_SERVER[0]}"


echo "$CALLBACK_RESULT"

DOCKER_IMAGE=$(echo "$CALLBACK_RESULT" | jq -r '.DOCKER_ALIYUN_NAME')
if [ "$ALIYUN_VPC" = true ]; then
    DOCKER_IMAGE="${DOCKER_IMAGE/./-vpc.}"
fi
EXPECTED_SHA=$(echo "$CALLBACK_RESULT" | jq -r '.sha')

echo "Pulling $DOCKER_IMAGE..."

docker pull "$DOCKER_IMAGE"

ACTUAL_SHA=$(docker inspect \
    --format='{{.Id}}' \
    "$DOCKER_IMAGE"
)

echo "Expected SHA: $EXPECTED_SHA"
echo "Actual SHA:   $ACTUAL_SHA"

if [ "$ACTUAL_SHA" != "$EXPECTED_SHA" ]; then
    echo "SHA mismatch!" >&2
    docker rmi "$DOCKER_IMAGE" >/dev/null 2>&1 || true
    exit 1
fi

echo "SHA verified."
echo "Tagging as $IMAGE..."
docker tag "$DOCKER_IMAGE" "$IMAGE"
docker rmi "$DOCKER_IMAGE" >/dev/null 2>&1 || true
echo "Done: $IMAGE"
