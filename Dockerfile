FROM centos:7.2.1511
MAINTAINER Harmony OsCore <harmony-oscore@cisco.com>

RUN yum -y install \
python-devel \
git \
gcc \
libffi-devel \
crudini \
jq \
sshpass \
bzip2 \
openssl-devel \
wget \
unzip

ENV TEMPDIR="/root"

WORKDIR ${TEMPDIR}

RUN wget https://bootstrap.pypa.io/get-pip.py
RUN python get-pip.py

RUN curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh && \
    chmod +x get_helm.sh
RUN ./get_helm.sh

RUN git clone https://github.com/openstack/kolla-kubernetes.git

WORKDIR kolla-kubernetes

RUN git clone https://github.com/openstack/kolla-ansible.git

RUN ln -rs kolla-ansible/etc/kolla /etc/kolla
RUN ln -rs kolla-ansible /usr/share/kolla
RUN ln -rs etc/kolla-kubernetes /etc/kolla-kubernetes

WORKDIR ${TEMPDIR}
RUN pip install --upgrade pip && \
    pip install "ansible<2.1" && \
    pip install python-openstackclient && \
    pip install python-neutronclient && \
    pip install python-cinderclient && \
    pip install pyyaml && \
    pip install python-ironicclient

RUN pip install -r kolla-kubernetes/kolla-ansible/requirements.txt
RUN pip install -r kolla-kubernetes/requirements.txt && \
    pip install kolla-kubernetes/. && \
    pip install kolla

RUN mkdir -p /etc/kolla/config/nova
RUN echo "[DEFAULT]\n\
use_neutron = true" > /etc/kolla/config/nova/nova.conf

RUN IP=172.18.0.1 && \
    echo "kolla_base_distro: centos" >> kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    cat kolla-kubernetes/tests/conf/iscsi-all-in-one/kolla_config >> kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    sed -i "s/^\(kolla_external_vip_address:\).*/\1 '$IP'/" kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    sed -i "s/^\(kolla_kubernetes_external_vip:\).*/\1 '$IP'/" kolla-kubernetes/etc/kolla-kubernetes/kolla-kubernetes.yml && \
    echo "fluentd_tag: master" >> kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    echo "cron_tag: master" >> kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    sed -i '/^enable_cinder:/c\enable_cinder: no' kolla-kubernetes/kolla-ansible/etc/kolla/globals.yml && \
    cat kolla-kubernetes/tests/conf/iscsi-all-in-one/kolla_kubernetes_config >> kolla-kubernetes/etc/kolla-kubernetes/kolla-kubernetes.yml && \
    sed -i "s/initial_mon:.*/initial_mon: $NODES/" kolla-kubernetes/etc/kolla-kubernetes/kolla-kubernetes.yml && \
    sed -i.old "s/kube-dns/kubedns/" kolla-kubernetes/tools/setup-resolv-conf.sh

WORKDIR kolla-kubernetes
RUN kolla-ansible/tools/generate_passwords.py
RUN kolla-ansible/tools/kolla-ansible genconfig
WORKDIR $TEMPDIR

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

RUN mv kubectl /usr/bin
RUN chmod 755 /usr/bin/kubectl

COPY scripts/kolla-entrypoint.bash /usr/local/bin/
COPY scripts/deploy_oscore_kit.bash /usr/local/bin/
COPY helm /usr/local/helm
ENTRYPOINT ["kolla-entrypoint.bash"]
