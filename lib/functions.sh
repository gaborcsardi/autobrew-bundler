#!/bin/sh
set -e

deploy_bundle() {
  local target=$1
  local formula=$2
  if [ -z "$formula" ]; then
  echo "Please specify a formula, e.g: $0 apache-arrow-static"
  exit 1
  fi

  if [ -z ${deps+set} ]; then
  local deps="$(brew deps $formula)"
  fi

  # Print debug
  echo "Bundling $formula for $target with deps: $deps"

  # Lookup the bottles
  local deptree=$(brew deps --tree $formula)
  local version=$(brew info $formula --json=v1 | jq -r '.[0].versions.stable')
  local revision=$(brew info $formula --json=v1 | jq -r '.[0].revision')
  if [ "$revision" != "0" ]; then
  version="${version}_$revision"
  fi
  if [ "$package" == "cranbundle" ]; then
  version="$(date +'%Y%m%d')"
  fi

  # Find bottle URLs
  local bottles=$(brew info --json=v1 $deps $formula | jq -r ".[] | .name + \";\" + .bottle.stable.files.$target.url")
  echo "Found bottles:\n$bottles"

  # Homebrew openssl@1.1 becomes just "openssl" in bintay
  if [ -z "$package" ]; then
  local package=$(echo $formula | cut -d'@' -f1)
  fi

  local bundle="$package-$version-$target"
  echo "Creating bundle $bundle"

  # Download and extract bottles
  set -f
  rm -Rf "$bundle" "$bundle.tar.xz"
  mkdir -p "$bundle"
  for bottle in $bottles
  do
    local current=$(echo "$bottle" | cut -d';' -f1)
    if [ "$current" = "ca-certificates" ] || [ "$current" = "m4" ]; then
      # Upstream dependencies of openssl and libtool
      continue
    fi
    local url=$(echo "$bottle" | cut -d';' -f2)
    if [[ $url == *"ghcr.io"* ]]; then
      local file="${current}_${target}.tar.gz"
    else
      local file=$(basename $url)
    fi
    local filesvar="${current//-/_}_files"
    local sharevar="${current//-/_}_extra_files"
    local addfiles='**/include **/*.a'
    if [ ${!filesvar} ]; then
      local addfiles=${!filesvar}
    fi

    #local includevar="${current//-/_}_include_files"
    curl -fsSL --header "Authorization: Bearer QQ==" $url -o $file
    if tar -tf $file '*/*/.brew' >/dev/null; then
      local brewvar='*/*/.brew'
    else
      unset brewvar && echo "NOTE: missing .brew in $file"
    fi
    # Shipping all pc files may overrule autobrew...
    #if [ "$package" == "cranbundle" ] && tar -tf $file '**/*.pc' 2>/dev/null; then
    #  brewvar='**/*.pc'
    #fi
    if [[ $current == "gnupg"* ]]; then
      tar xzf $file -C $bundle --strip 2 ${brewvar} '**/bin/gpg1'
    else
      tar xzf $file -C $bundle --strip 2 ${addfiles} ${brewvar} ${!sharevar} || (echo "Failure extracting $file" && exit 1)
    fi
    rm -f $file
    echo "OK! $file"
  done
  set +f

  # Copy custom files if any
  if [ -d "${package}-files" ]; then
    cp -Rf ${package}-files/* $bundle/
  fi

  # Replaces homebrew paths with /usr/local
  if [ "$package" == "cranbundle" ]; then
    sed -i '' 's|@@HOMEBREW_.[A-Z]*@@/[^/"]*/[^/"]*|/usr/local|g' ${bundle}/bin/{gsl,h5,nc}*
  fi

  # Run tests if running on appropriate machine
  if [ -f "$bundle/test" ]; then
    if [[ "$target" == "arm64"* ]] && [[ ${OSTYPE:6} -lt 20 ]]; then
      echo "Skipping tests (testing arm64 requires MacOS 11)"
    else
      echo "Running test script for $package on $target"
      "$bundle/test" "$target"
    fi
  fi

  # Create archive
  mv "$bundle/.brew" "$bundle/brew" || true
  echo "$deptree" > $bundle/tree.txt
  echo "$bottles" > $bundle/bottles.txt
  mkdir -p "archive/$target"
  tar cfJ "archive/$target/$bundle.tar.xz" $bundle
  rm -Rf $bundle
}

deploy_new_bundles(){
  brew update
  brew tap autobrew/cran
  jq --version || brew install jq
  local targets="arm64_big_sur big_sur catalina"
  for target in $targets
  do
    deploy_bundle $target "${@:1}"
  done
}

deploy_old_bundles(){
  local BREWDIR="$PWD/autobrew"
  local PATH="$BREWDIR/bin:$PATH"
  if [ ! -f "$BREWDIR/bin/brew" ]; then
    mkdir -p $BREWDIR
    curl -fsSL https://github.com/autobrew/brew/tarball/master | tar xz --strip 1 -C $BREWDIR
    brew install --force-bottle pkg-config
  fi
  deploy_bundle "high_sierra" "${@:1}"
}

deploy_oldold_bundles(){
  local BREWDIR="$PWD/capitanbrew"
  local PATH="$BREWDIR/bin:$PATH"
  if [ ! -f "$BREWDIR/bin/brew" ]; then
    mkdir -p $BREWDIR
    curl -fsSL https://github.com/autobrew/brew/tarball/master | tar xz --strip 1 -C $BREWDIR
    brew install --force-bottle pkg-config
    (cd $(brew --repo homebrew/core); git fetch origin el-capitan:refs/remotes/origin/el-capitan; git reset --hard origin/el-capitan; git log -n1)
  fi
  deploy_bundle "el_capitan" "${@:1}"
}

merge_fat_bundles(){
  local formula=$1
  local target="big_sur"
  local file1=$(echo archive/$target/$formula*)
  local file2="${file1//$target/arm64_$target}"
  local file3="${file1//$target/fat_$target}"
  #local bundle="$(basename ${file1%%.*})"
  rm -Rf tmp
  mkdir -p tmp
  tar xzf $file1 -C tmp
  local bundle=$(ls tmp)
  tar xzf $file2 -C tmp
  for input1 in tmp/$bundle/lib/*.a; do
    local input2="${input1/$target/arm64_$target}"
    lipo -create $input1 $input2 -output libfat.a
    mv -fv libfat.a $input1
  done
  cat tmp/${bundle/$target/arm64_$target}/bottles.txt >> tmp/$bundle/bottles.txt
  rm -Rf tmp/*-arm64_big_sur
  local fatbundle=${bundle/$target/fat_$target}
  mv tmp/$bundle tmp/$fatbundle
  mkdir -p $(dirname $file3)
  (cd tmp; tar cfJ ../$file3 $fatbundle)
  rm -Rf tmp
}
