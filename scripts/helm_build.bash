#!/usr/bin/env bash
#set -x

function build_and_upload {
pushd $SRCDIR
for i in `ls`; do
if [[ -d $i ]];then
pushd $i
helm dep up . && helm package .
mv *.tgz $REPODIR
popd
fi
done
helm repo index $REPODIR
helm repo update
popd
}

REPODIR=~/.helm/repository/kolla

mkdir -p $REPODIR
helm serve --address "127.0.0.1:10191" --repo-path $REPODIR &
helm repo add kolla http://localhost:10191

for SRCDIR in $@;do
build_and_upload
done
