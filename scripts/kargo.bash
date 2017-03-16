#!/usr/bin/env bash

ssh-keygen -t rsa -N '' -f /home/vagrant/.ssh/id_rsa
ssh-copy-id -i /home/vagrant/.ssh/id_rsa -o StrictHostKeyChecking=no vagrant@localhost
echo 'Add Dockerfile'
cat <<'EOF' > /home/vagrant/Dockerfile
FROM centos:centos7

MAINTAINER harmony-oscore <harmony-oscore@cisco.com>

RUN yum install -y deltarpm

# Install gcc and other tools needed for python cffi
RUN yum install -y \
        gcc \
        libffi-devel \
        python-devel \
        openssl-devel \
        git

# EPEL
RUN rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm

# python stuff
RUN yum install -y \
    python-pip \
    python-wheel \
    && yum clean all

RUN git clone https://github.com/kubernetes-incubator/kargo.git
WORKDIR /kargo
RUN git checkout aeec0f9a71a47420c21c4a5bf79e2562120ca62e

RUN pip install -r requirements.txt

ENV ANSIBLE_GATHERING smart
ENV ANSIBLE_HOST_KEY_CHECKING false
ENV ANSIBLE_RETRY_FILES_ENABLED false
ENV ANSIBLE_SSH_PIPELINING True
ENV ANSIBLE_LOG_PATH "/var/log/ansible.log"
ENTRYPOINT ["ansible-playbook", "-i", "inventory/inventory.ini", "cluster.yml", "--become"]
EOF
IP=$(hostname -I | awk '{print $2}')
cat <<EOF > /home/vagrant/inventory.ini
k8s-01 ansible_ssh_host=127.0.0.1 ansible_ssh_user='vagrant' ip=$IP flannel_interface=$IP flannel_backend_type=host-gw local_release_dir=/var/vagrant/temp download_run_once=False kube_network_plugin=flannel

[etcd]
k8s-0[1:1]

[kube-master]
k8s-0[1:1]

[kube-node]
k8s-0[1:1]

[k8s-cluster:children]
kube-master
kube-node
EOF
sudo /sbin/ifup enp0s8
echo 'Build container'
sudo docker build -t kargo .
echo 'Running container. Playbook will restart docker daemon couple of times but playbook will keep running. To monitor progress see /var/log/ansible.log'
sudo docker run --rm --network=host -v /home/vagrant/.ssh/id_rsa:/root/.ssh/id_rsa:ro,z \
-v /home/vagrant/inventory.ini:/kargo/inventory/inventory.ini:ro,z -v /var/log:/var/log:rw,z kargo

