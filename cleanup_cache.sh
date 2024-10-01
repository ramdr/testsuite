#!/bin/bash

# Variables
REPO="ramdr/testsuite"  # Replace with your repository
GITHUB_TOKEN=$GH_PAT  # Use the token passed as an environment variable

# Retrieve cache list
caches=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/actions/caches")

# Extract the cache ID associated with the restore key
cache_id=$(echo "$caches" | jq -r --arg key "Linux-build-linux/amd64-" '
  .actions_caches[]? | 
  select(.name != null and (.name | startswith($key))) | 
  .id
')
#cache_id=$(echo "$caches" | jq -r --arg key "Linux-build-linux/amd64-" '.actions_caches[] | select(.name | startswith($key)) | .id')

# Delete the cache if it exists
if [ -n "$cache_id" ]; then
  echo "Deleting cache ID: $cache_id"
  curl -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
    "https://api.github.com/repos/$REPO/actions/caches/$cache_id"
else
  echo "No cache found for the restore key."
fi
