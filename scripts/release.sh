#!/usr/bin/env bash

BUILD_VERSION="0.1.0-alpha.7"

go get github.com/tcnksm/ghr

ROOT_DIR="/tmp"

BUILD_DIR="$ROOT_DIR/builds"
VERSION_BUILD_DIR="$BUILD_DIR/$BUILD_VERSION"
VERSION_BUILD_ARTIFACTS_DIR="$VERSION_BUILD_DIR/artifacts"

oses=("darwin")
archs=("amd64")

mkdir -p $VERSION_BUILD_DIR
mkdir -p $VERSION_BUILD_ARTIFACTS_DIR

cd $VERSION_BUILD_DIR

for os in ${oses[@]}; do
    for arch in ${archs[@]}; do
        dir="warden-${os}_${arch}"
        binary="warden"
        tar="$VERSION_BUILD_ARTIFACTS_DIR/$dir.tar.gz"
        md5="$tar.md5"
        echo "Building $dir..."
        if [[ ! -d $dir ]]; then
            mkdir $dir
        fi
        cd $dir
        GOOS=${os} GOARCH=${arch} CGO_ENABLED=1 go build -o $binary github.com/warden-pub/warden/tools/warden/
        if [[ $? -ne 0 ]]; then
            cd ..
            continue
        fi
        tar czvf $tar $binary
        if [[ $? -ne 0 ]]; then
            cd ..
            continue
        fi
        md5 -r $tar > $md5
        cd ..
    done
done

cd $BUILD_DIR

release_repo_dir="warden-releases"

git clone --depth=1 git@github.com:warden-pub/warden-releases.git $release_repo_dir
cd $release_repo_dir
git commit --allow-empty -m $BUILD_VERSION
git tag $BUILD_VERSION
git push origin
git push origin $BUILD_VERSION

ghr -u warden-pub --replace $BUILD_VERSION $VERSION_BUILD_ARTIFACTS_DIR
