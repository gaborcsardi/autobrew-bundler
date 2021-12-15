#!/bin/sh
source lib/functions.sh
export package=imagemagick
deplist="libheif libde265 x265 jasper libtool librsvg libpng freetype fontconfig pixman cairo gettext libffi pcre jpeg libtiff fribidi pango libffi little-cms2 openjpeg webp"
deps="libraw glib harfbuzz gdk-pixbuf $deplist" deploy_old_bundles "imagemagick@6"
deps="aom libraw-lite glib-lite harfbuzz-lite gdk-pixbuf-static $deplist" deploy_new_bundles "imagemagick-static"
