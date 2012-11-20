#!/bin/sh

set -x

INFO_PLIST="${BUILT_PRODUCTS_DIR}/${INFOPLIST_PATH}"

git_build=`git rev-list HEAD| wc -l`
git_version=`git describe --dirty | sed -e 's/^v//' -e 's/g//'`

defaults write "${INFO_PLIST%.*}" CFBundleVersion "${git_build}"
defaults write "${INFO_PLIST%.*}" CFBundleShortVersionString "${git_version}"
