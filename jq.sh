#!/bin/sh
source lib/functions.sh
source ~/.Renviron

# Source API key and publish
brew update
deploy_new_bundles jq
deploy_old_bundles jq
