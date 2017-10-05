#!/usr/bin/env bash

go get github.com/tcnksm/ghr

build_version="0.1.0-alpha.4"

oses=("darwin")
archs=("amd64")

for os in ${oses[@]}; do
    for arch in ${archs[@]}; do
        dir="warden-${os}_${arch}"
        binary="warden"
        tar="$dir.tar.gz"
        md5=$tar.md5
        echo "Building $dir..."
        if [[ ! -d $dir ]]; then
            mkdir $dir
        fi
        cd $dir
        GOOS=${os} GOARCH=${arch} go build -o $binary github.com/warden-pub/warden/tools/warden/
        tar czvf $tar $binary
        md5 -r $tar > $md5
        cd ..
    done
done

# ghr -t $GITHUB_TOKEN -u $CIRCLE_PROJECT_USERNAME -r 