#!/bin/sh
source lib/functions.sh

# Source API key and publish
brew update
deploy_new_bundles libgit2
deploy_old_bundles libgit2
