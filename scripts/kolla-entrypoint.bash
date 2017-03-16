#!/usr/bin/env bash
set -x

#Label Nodes

NODES=`kubectl get nodes | awk '!/NAME/{print $1}'`
for i in $NODES;do
    kubectl label node $i kolla_compute=true kolla_controller=true
done
kubectl create namespace kolla
tools/secret-generator.py create

#Configure Helm and Build Charts
helm init
./zen/scripts/helm_build.bash ./kolla-kubernetes/helm/microservice ./kolla-kubernetes/helm/service\
    ./kolla-kubernetes/helm/compute-kits ./zen/helm/compute-kits


#Deploy kolla-kubernetes

kolla-kubernetes/tools/setup-resolv-conf.sh kolla
kollakube res create configmap \
mariadb keystone horizon rabbitmq memcached nova-api nova-conductor \
nova-scheduler glance-api-haproxy glance-registry-haproxy glance-api \
glance-registry neutron-server neutron-dhcp-agent neutron-l3-agent \
neutron-metadata-agent neutron-openvswitch-agent openvswitch-db-server \
openvswitch-vswitchd nova-libvirt nova-consoleauth \
nova-novncproxy nova-novncproxy-haproxy neutron-server-haproxy \
nova-compute nova-compute-ironic nova-api-haproxy keepalived  \
ironic-api ironic-api-haproxy ironic-conductor ironic-dnsmasq \
ironic-inspector ironic-inspector-haproxy ironic-pxe;
kollakube res create secret nova-libvirt

./zen/scripts/deploy_oscore_kit.bash iscsi centos

