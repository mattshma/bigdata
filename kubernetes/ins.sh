ROLE=$1
echo  $ROLE
if [ -z $ROLE ];then
  echo "请输入节点角色[m/s]，如：./install_k8s.sh m"
  exit 1
elif [ $ROLE != "m" ] && [ $ROLE != "s" ];then
  echo "请输入m或s！"
  exit 1
fi


echo "====== 1. pre prepare ========"
echo "====== 1.1 set repo ========"
cat <<EOF > /etc/yum.repos.d/CentOS-Base.repo
# CentOS-Base.repo
#
# The mirror system uses the connecting IP address of the client and the
# update status of each mirror to pick mirrors that are updated to and
# geographically close to the client.  You should use this for CentOS updates
# unless you are manually picking other mirrors.
#
# If the mirrorlist= does not work for you, as a fall back you can try the
# remarked out baseurl= line instead.
#
#

[base]
name=CentOS-7.5.1804 - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7.5.1804/os/\$basearch/
        http://mirrors.aliyuncs.com/centos/7.5.1804/os/\$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/7.5.1804/os/\$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#released updates
[updates]
name=CentOS-7.5.1804 - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7.5.1804/updates/\$basearch/
        http://mirrors.aliyuncs.com/centos/7.5.1804/updates/\$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/7.5.1804/updates/\$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that may be useful
[extras]
name=CentOS-7.5.1804 - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7.5.1804/extras/\$basearch/
        http://mirrors.aliyuncs.com/centos/7.5.1804/extras/\$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/7.5.1804/extras/\$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-7.5.1804 - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7.5.1804/centosplus/\$basearch/
        http://mirrors.aliyuncs.com/centos/7.5.1804/centosplus/\$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/7.5.1804/centosplus/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7

#contrib - packages by Centos Users
[contrib]
name=CentOS-7.5.1804 - Contrib - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/7.5.1804/contrib/\$basearch/
        http://mirrors.aliyuncs.com/centos/7.5.1804/contrib/\$basearch/
        http://mirrors.cloud.aliyuncs.com/centos/7.5.1804/contrib/\$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF

echo "==== set aliyun-epel7.repo ====="
cat <<EOF > /etc/yum.repos.d/epel-7.repo
[epel]
name=Extra Packages for Enterprise Linux 7 - \$basearch
baseurl=http://mirrors.aliyun.com/epel/7/\$basearch
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7

[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/7/\$basearch/debug
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=0

[epel-source]
name=Extra Packages for Enterprise Linux 7 - \$basearch - Source
baseurl=http://mirrors.aliyun.com/epel/7/SRPMS
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=0
EOF

echo "==== set kubernetes.repo ====="
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

cp -f /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

swapoff -a

setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

yum -y makecache
yum -y install vim wget mlocate git telnet nc bzip2

modprobe -- ip_vs_rr ip_vs_wrr ip_vs_sh ip_vs

cat << EOF >> /etc/hosts
10.1.254.103    ip-10-1-254-103.nutrainai.local
10.1.254.167    ip-10-1-254-167.nutrainai.local
10.1.254.185    ip-10-1-254-185.nutrainai.local
EOF

echo "=========== 2. install docker ========="
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
yum makecache
yum -y install --setopt=obsoletes=0 docker-ce-selinux-17.03.3.ce-1.el7 docker-ce-17.03.3.ce-1.el7
systemctl enable docker && systemctl start docker
cat<<EOF >/etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "15"
  }
}
EOF

cat<<EOF > /etc/sysconfig/docker
OPTIONS="--insecure-registry 10.1.254.103"
EOF

sed -i '11 i EnvironmentFile=-/etc/sysconfig/docker' /usr/lib/systemd/system/docker.service
sed -i '12s/dockerd/dockerd $OPTIONS/g' /usr/lib/systemd/system/docker.service
sed -i '13 a ExecStartPost=/sbin/iptables -P FORWARD ACCEPT' /usr/lib/systemd/system/docker.service
systemctl daemon-reload
systemctl restart docker

echo "==== 3. install etcd ============="
# if [ $ROLE == "m" ];then
#   echo "master will not install etcd, skip.."
# elif [ $ROLE == "s" ];then
# yum install -y etcd
# ip=`ifconfig |grep inet |grep "255.255.255.0" |awk '{print $2}'`
# cat << EOF > /etc/etcd/etcd.conf
# [member]
# ETCD_NAME=`hostname`
# ETCD_DATA_DIR="/var/lib/etcd/"
# ETCD_LISTEN_CLIENT_URLS="http://0.0.0.0:2379"
# ETCD_ADVERTISE_CLIENT_URLS="http://0.0.0.0:2379"
# ETCD_LISTEN_PEER_URLS="http://0.0.0.0:2380"
# ETCD_INITIAL_ADVERTISE_PEER_URLS="http://${ip}:2380"
# [cluster]
# ETCD_INITIAL_CLUSTER="ip-10-1-254-34.nutrainai.local=http://10.1.254.34:2380"
# ETCD_INITIAL_CLUSTER_STATE="new"
# ETCD_INITIAL_CLUSTER_TOKEN="kubernetes-etcd-cluster"
# EOF
#
# cat > /usr/lib/systemd/system/etcd.service  << EOF
# [Unit]
# Description=Etcd Server
# After=network.target
# After=network-online.target
# Wants=network-online.target
#
# [Service]
# Type=simple
# WorkingDirectory=/var/lib/etcd/
# EnvironmentFile=/etc/etcd/etcd.conf
# ExecStart=/usr/bin/etcd
#
# [Install]
# WantedBy=multi-user.target
# EOF
#
# systemctl enable etcd && systemctl start etcd && systemctl status etcd
# fi
echo "========= 4. install harbor ==========="
if [ $ROLE == "m" ];then
yum install -y docker-compose

mkdir -p /opt/app
wget https://storage.googleapis.com/harbor-releases/release-1.6.0/harbor-online-installer-v1.6.0.tgz -O /opt/app/harbor-online-installer-v1.6.0.tgz
cd /opt/app
tar xzvf harbor-online-installer-v1.6.0.tgz
ip=`ifconfig |grep inet |grep "255.255.255.0" |awk '{print $2}'`
sed -i "s/hostname = .*/hostname = ${ip}/g" /opt/app/harbor/harbor.cfg

cd /opt/app/harbor
/opt/app/harbor/prepare
docker-compose up -d
/opt/app/harbor/install.sh

docker login 10.1.254.103

docker pull mirrorgooglecontainers/kubernetes-dashboard-amd64:v1.10.0
docker pull mirrorgooglecontainers/kube-apiserver-amd64:v1.11.4
docker pull mirrorgooglecontainers/kube-proxy-amd64:v1.11.4
docker pull mirrorgooglecontainers/kube-controller-manager-amd64:v1.11.4
docker pull mirrorgooglecontainers/kube-scheduler-amd64:v1.11.4
docker pull mirrorgooglecontainers/pause-amd64:3.1
docker pull mirrorgooglecontainers/etcd-amd64:3.2.18
docker pull coredns/coredns:1.1.3

echo "==== 请在 harbor ui 中创建 kubernetes 项目 ===="
pausename=`docker images |grep pause-amd64 |awk '{print $3}'`
docker tag ${pausename} 10.1.254.103/library/pause:3.1
etcdname=`docker images |grep etcd-amd64 |awk '{print $3}'`
docker tag ${etcdname} 10.1.254.103/library/etcd-amd64:3.2.18
dnsname=`docker images |grep coredns |awk '{print $3}'`
docker tag ${dnsname} 10.1.254.103/library/coredns:1.1.3
proxyname=`docker images |grep kube-proxy-amd64 |awk '{print $3}'`
docker tag ${proxyname} 10.1.254.103/library/kube-proxy-amd64:v1.11.4
apiservername=`docker images |grep kube-apiserver-amd64 |awk '{print $3}'`
docker tag ${apiservername} 10.1.254.103/library/kube-apiserver-amd64:v1.11.4
schedulername=`docker images |grep kube-scheduler-amd64 |awk '{print $3}'`
docker tag ${schedulername} 10.1.254.103/library/kube-scheduler-amd64:v1.11.4
controllername=`docker images |grep kube-controller-manager |awk '{print $3}'`
docker tag ${controllername} 10.1.254.103/library/kube-controller-manager-amd64:v1.11.4
dashboardname=`docker images |grep kubernetes-dashboard-amd64 |awk '{print $3}'`
docker tag ${dashboardname} 10.1.254.103/library/kubernetes-dashboard-amd64:v1.10.0
docker push 10.1.254.103/library/pause:3.1
docker push 10.1.254.103/library/etcd-amd64:3.2.18
docker push 10.1.254.103/library/coredns:1.1.3
docker push 10.1.254.103/library/kube-proxy-amd64:v1.11.4
docker push 10.1.254.103/library/kube-apiserver-amd64:v1.11.4
docker push 10.1.254.103/library/kube-scheduler-amd64:v1.11.4
docker push 10.1.254.103/library/kube-controller-manager-amd64:v1.11.4
docker push 10.1.254.103/library/kubernetes-dashboard-amd64:v1.10.0

else
  echo "current node is slave, pull images"
  docker pull 10.1.254.103/library/pause:3.1
  docker pull 10.1.254.103/library/etcd-amd64:3.2.18
  docker pull 10.1.254.103/library/coredns:1.1.3
  docker pull 10.1.254.103/library/kube-proxy-amd64:v1.11.4
  docker pull 10.1.254.103/library/kube-apiserver-amd64:v1.11.4
  docker pull 10.1.254.103/library/kube-scheduler-amd64:v1.11.4
  docker pull 10.1.254.103/library/kube-controller-manager-amd64:v1.11.4
  docker pull 10.1.254.103/library/kubernetes-dashboard-amd64:v1.10.0
fi

echo "========== 5. install kubeadm ========="
yum install -y kubelet-1.11.4 kubeadm-1.11.4 kubectl-1.11.4 --disableexcludes=kubernetes

cat <<EOF > /etc/sysconfig/kubelet
KUBELET_EXTRA_ARGS="--pod-infra-container-image=10.1.254.103/library/pause:3.1"
EOF

docker pull quay.io/calico/node:v3.0.8
docker pull quay.io/calico/cni:v2.0.6
docker pull quay.io/calico/kube-controllers:v2.0.5

if [ $ROLE == "m" ];then
cat << EOF > /etc/kubernetes/kubeadm.yml
apiVersion: kubeadm.k8s.io/v1alpha3
kind: MasterConfiguration
kubernetesVersion: v1.11.4
featureGates:
  CoreDNS: true
authorizationModes:
  - RBAC
  - Node
kubeProxy:
  config:
    mode: ipvs
etcd:
  endpoints:
  - http://10.1.254.185:2379
networking:
  podSubnet: 10.244.0.0/16
imageRepository: 10.1.254.103/library
EOF

kubeadm config images pull --config /etc/kubernetes/kubeadm.yml
kubeadm init --config /etc/kubernetes/kubeadm.yml

export KUBECONFIG=/etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> /etc/bashrc

### 如果使用非 root 用户，还需执行如下行：
#  mkdir -p $HOME/.kube
#  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#  sudo chown $(id -u):$(id -g) $HOME/.kube/config

kubectl apply -f kubectl apply -f https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/rbac.yaml
wget https://docs.projectcalico.org/v3.0/getting-started/kubernetes/installation/hosted/calico.yaml
sed -i '16s/127.0.0.1/10.1.254.185/g' calico.yaml
kubectl create -f calico.yaml

wget https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
sed -i '112s/k8s.gcr.io/10.1.254.103\/library/g' kubernetes-dashboard.yaml
kubectl create -f kubernetes-dashboard.yaml

elif [ $ROLE == "s" ];then
# slave:

#Token=`kubeadm token list  |grep "kubeadm:default-node-token" |awk '{print $1}'`
#CertHash=`openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'`
#
#kubeadm join 10.1.254.103:6443 --token $Token --discovery-token-ca-cert-hash sha256:$CertHash
#
kubeadm join 10.1.254.103:6443 --token jzlgy8.zd4i1oklethtei5l --discovery-token-ca-cert-hash sha256:91e1f5a512d7f5da14dc0e8949c0f2241a002e9115d3b3de1927ec0c299f0701
fi
