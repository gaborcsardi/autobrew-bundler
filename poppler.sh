#!/bin/sh
source lib/functions.sh

# Avoid glib dependency (from cairo)
export deps="cairo fontconfig freetype libpng lzo pixman gettext jpeg openjpeg little-cms2 libtiff"
export poppler_extra_files="**/share/poppler"
export poppler_lite_extra_files="**/share/poppler"
export package="poppler"
deploy_oldold_bundles poppler
deploy_old_bundles poppler
deploy_new_bundles poppler-lite
