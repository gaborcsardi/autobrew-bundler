#!/bin/sh
source lib/functions.sh

# Use default cairo, except do not bundle the 'glib' dependency
deps="fontconfig freetype libpng lzo pixman" deploy_new_bundles cairo
deploy_old_bundles cairo
