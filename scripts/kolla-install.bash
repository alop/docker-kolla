#!/usr/bin/env bash
set -x

if [[ ! -d ./kolla-kubernetes ]]; then
  git clone https://github.com/openstack/kolla-kubernetes.git
fi
pushd kolla-kubernetes

#Install kolla-ansible and configs

if [[ ! -d ./kolla-ansible ]]; then
  git clone https://github.com/openstack/kolla-ansible.git
fi
if [[ ! -d /etc/kolla ]]; then
sudo ln -s `pwd`/kolla-ansible/etc/kolla /etc/kolla
fi
if [[ ! -d /etc/kolla-kubernetes ]]; then
sudo ln -s `pwd`/etc/kolla-kubernetes /etc/kolla-kubernetes
fi

#Install python prereqs

if [[ ! -d ./.venv ]]; then
  virtualenv .venv
fi
source .venv/bin/activate
pushd kolla-ansible;
pip install pip --upgrade
pip install "ansible<2.1"
pip install "python-openstackclient"
pip install "python-neutronclient"
pip install "python-cinderclient"
pip install -r requirements.txt
pip install pyyaml
pip install python-ironicclient
popd
pip install -r requirements.txt
pip install .
pip install kolla #Workaround for https://review.openstack.org/#/c/439740/

# Work around for Newton images and Ocata genconfig
mkdir -p /etc/kolla/config/
echo "[DEFAULT]
use_neutron = true" > /etc/kolla/config/nova.conf

# Generate kolla-ansible config

echo "kolla_base_distro: centos" >> kolla-ansible/etc/kolla/globals.yml
cat tests/conf/iscsi-all-in-one/kolla_config >> kolla-ansible/etc/kolla/globals.yml
IP=172.18.0.1
sed -i.old "s/^\(kolla_external_vip_address:\).*/\1 '$IP'/" \
kolla-ansible/etc/kolla/globals.yml
sed -i.old "s/^\(kolla_kubernetes_external_vip:\).*/\1 '$IP'/" \
etc/kolla-kubernetes/kolla-kubernetes.yml
echo "fluentd_tag: master" >> kolla-ansible/etc/kolla/globals.yml
echo "cron_tag: master" >> kolla-ansible/etc/kolla/globals.yml
sed -i.old '/^enable_cinder:/c\enable_cinder: no' kolla-ansible/etc/kolla/globals.yml

cat tests/conf/iscsi-all-in-one/kolla_kubernetes_config \
>> etc/kolla-kubernetes/kolla-kubernetes.yml

pushd kolla-ansible
./tools/generate_passwords.py  # (Optional: will overwrite)
./tools/kolla-ansible genconfig
popd

#Label Nodes

NODES=`kubectl get nodes | awk '!/NAME/{print $1}'`
for i in $NODES;do
    kubectl label node $i kolla_compute=true kolla_controller=true
done
kubectl create namespace kolla
tools/secret-generator.py create

#Configure Helm and Build Charts
popd
helm init
./zen/scripts/helm_build.bash ./kolla-kubernetes/helm/microservice ./kolla-kubernetes/helm/service\
    ./kolla-kubernetes/helm/compute-kits ./zen/helm/compute-kits


#Deploy kolla-kubernetes

sed -i.old "s/kube-dns/kubedns/" tools/setup-resolv-conf.sh
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

