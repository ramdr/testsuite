 #!/bin/bash

# Variables
REPO="ramdr/testsuite"  # Replace with your repository
GITHUB_TOKEN=$GH_PAT  # Use the token passed as an environment variable
NAME_PATTERN="Linux-build"  
KEEP_LAST=2  

response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
  "https://api.github.com/repos/$REPO/actions/caches")
echo "list of images"
echo "$response"
# # Check if any caches were found
# if echo "$response" | jq -e '.actions_caches | length == 0' > /dev/null; then
#   echo "No caches found."
#   exit 0
# fi

# # Filter caches by name pattern and ensure they are not null
# caches=$(echo "$response" | jq -r --arg pattern "$NAME_PATTERN" \
#   '.actions_caches[] | select(.name | contains($pattern)) | {id: .id, name: .name, created_at: .created_at}')

# echo "$caches"

# # Convert the output to an array and ensure it's not empty
# caches_array=($(echo "$caches" | jq -r '. | length'))

# echo "$caches_array"

# if [[ ${caches_array[0]} -eq 0 ]]; then
#   echo "No caches found matching the pattern."
#   exit 0
# fi

# # Sort caches by creation date (oldest first) and prepare for deletion
# caches_to_delete=$(echo "$caches" | jq -s --argjson keep_last "$KEEP_LAST" 'sort_by(.created_at) | .[:-($keep_last | tonumber)]')

# # Check if there are caches to delete
# if [[ $(echo "$caches_to_delete" | jq 'length') -eq 0 ]]; then
#   echo "No older caches to delete."
#   exit 0
# fi

# # Print the caches that will be deleted
# echo "Caches to delete:"
# echo "$caches_to_delete" | jq .

# # Iterate over the caches and delete each one
# echo "$caches_to_delete" | jq -c '.[]' | while read -r cache; do
#   cache_id=$(echo "$cache" | jq -r '.id')
#   cache_name=$(echo "$cache" | jq -r '.name')

#   # Delete the cache
#   delete_response=$(curl -s -X DELETE -H "Authorization: token $GITHUB_TOKEN" \
#     "https://api.github.com/repos/$REPO/actions/caches/$cache_id")

#   # Print the delete response
#   if [[ $(echo "$delete_response" | jq -r '.message') == "Not Found" ]]; then
#     echo "Cache $cache_name (ID: $cache_id) not found for deletion."
#   else
#     echo "Deleted cache: $cache_name (ID: $cache_id)"
#   fi
# done
