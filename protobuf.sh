#!/bin/sh
source lib/functions.sh
export deps=""
export package=protobuf
export protobuf_extra_files="*/*/bin"
export protobuf_static_extra_files="*/*/bin"
deploy_old_bundles protobuf
deploy_new_bundles protobuf-static
