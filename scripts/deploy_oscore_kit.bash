#!/usr/bin/env bash
set -xe

#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../../kolla-kubernetes" && pwd )"
DIR="/root/kolla-kubernetes" && pwd )"

. "$DIR/tests/bin/common_workflow_config.sh"
. "$DIR/tests/bin/common_iscsi_config.sh"

VERSION=0.6.0-1
IP=172.18.0.1
tunnel_interface=docker0
base_distro="$2"

function general_config {
    common_workflow_config $IP $base_distro $tunnel_interface
}

function iscsi_config {
    common_iscsi_config
}

general_config > /tmp/general_config.yaml
iscsi_config > /tmp/iscsi_config.yaml

helm install ~/.helm/repository/kolla/oscore-kit* --version $VERSION \
    --namespace kolla --name oscore-kit \
    --values /tmp/general_config.yaml --values /tmp/iscsi_config.yaml

$DIR/tools/wait_for_pods.sh kolla 900

kollakube res create bootstrap openvswitch-set-external-ip
$DIR/tools/wait_for_pods.sh kolla

$DIR/tools/build_local_admin_keystonerc.sh
