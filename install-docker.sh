#!/bin/sh

if [ "root" != "$(whoami)" ]; then
    echo "Must run as root, you are $(whoami)"
    exit 1
fi

PROXY_PROTOCOL=http #or https
PROXY_HOST= #test.example.com
PROXY_PORT= #443

CUSTOM_IMAGE_PREFIX=My #set to whatever you need
CUSTOM_TAG=latest #set to whatever you need
REGISTRY_PORT=5000 #set to whatever you need
CERTS_DIR=/root/certs #set to whatever you need

if [ ! -z "$PROXY_HOST" ]; then
    export http_proxy=$PROXY_PROTOCOL://$PROXY_HOST:$PROXY_PORT
    export https_proxy=$PROXY_PROTOCOL://$PROXY_HOST:$PROXY_PORT
fi

TMP_RESP=$(curl -Is https://www.google.com | awk 'NR==1 {print $2;}')

if [ "200" != "$TMP_RESP" ]; then
    echo "Error!! got response $TMP_RESP"
    exit 1
fi

echo "Can connect to the outside world..."

########
#
#
########
installDockerEngine
{
    # https://docs.docker.com/engine/installation/linux/rhel/
    echo "Installing Docker engine..."
    # make sure we're ready to go
    yum update
    # use tee to add docker repo
    #### vvvvvvvvvvvv NOT FORMATTED on purpose!
tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg
EOF
    #### ^^^^^^^^^^^^ NOT FORMATTED on purpose!
    # install engine
    yum install docker-engine
    # enable
    systemctl enable docker.service
    # start
    systemctl start docker
}

########
#
#
########
fixRHEL7EngineIssue
{
    # fix known issue with RHEL 7
    # https://github.com/docker/docker/issues/28406
    semodule -d docker
    yum reinstall docker-engine-selinux.noarch
    # mkdir as needed
    mkdir -p /etc/systemd/system/docker.service.d
}

########
#
#
########
addDockerProxy
{
    # https://docs.docker.com/engine/admin/systemd/#/http-proxy
    # add proxy for docker
    #### vvvvvvvvvvvv NOT FORMATTED on purpose!
tee /etc/systemd/system/docker.service.d/http-proxy.conf <<-'EOF'
[Service]
Environment="HTTP_PROXY=$PROXY_PROTOCOL://$PROXY_HOST:$PROXY_PORT" "NO_PROXY=localhost,127.0.0.1"
EOF
    #### ^^^^^^^^^^^^ NOT FORMATTED on purpose!
    systemctl daemon-reload
    systemctl show --property=Environment docker
    systemctl restart docker
}

########
#
#
########
testDocker
{
    docker run --rm hello-world
}

########
# takes 2 params, first is the image name, second is the tag  if no tag is given, will use 'latest'
# 
########
getCustomImage
{
    TMP_IMG=$1
    TMP_TAG=$2
    if [ -z "$TMP_TAG" ]; then
        TMP_TAG=latest
    fi
    # pull registry image
    docker pull $TMP_IMG:$TMP_TAG
    # mark with a tag
    docker tag $TMP_IMG:$TMP_TAG $CUSTOM_IMAGE_PREFIX-$TMP_IMG:$CUSTOM_TAG
}

########
# 
# 
########
setupRegistryCerts
{
    mkdir -p $CERTS_DIR
    openssl req -newkey rsa:4096 -nodes -sha256 -keyout $CERTS_DIR/domain.key -x509 -days 365 -out $CERTS_DIR/domain.crt

}

########
# Assumes that you have run "getCustomImage 'registry' '2'"
# 
########
startRegistry
{
    docker run -d -p $REGISTRY_PORT:$REGISTRY_PORT --restart=always --name $CUSTOM_IMAGE_PREFIX-registry -v $CERTS_DIR:/certs -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key$CUSTOM_IMAGE_PREFIX-registry:$CUSTOM_TAG
    # push the registry image to the registry
    docker push $CUSTOM_IMAGE_PREFIX-registry:$CUSTOM_TAG
}

########
# Assumes that you have run "getCustomImage 'registry' '2'"
# 
########
installGitLabs
{
    # see https://about.gitlab.com/downloads/#centos7
    # most of prerequisites are good, just need to config firewall
    firewall-cmd --permanent --add-service=http
    systemctl reload firewalld
    curl -LJ0 https://packages.gitlab.com/gitlab/gitlab-ce/packages/el/7/gitlab-ce-8.15.4-ce.1.el7.x86_64.rpm/download > gitlab-ce-8.15.4-ce.1.el7.x86_64.rpm
    rpm -i gitlab-ce-8.15.4-ce.1.el7.x86_64.rpm
    gitlab-ctl reconfigure
}

installDockerEngine
fixRHEL7EngineIssue
if [ ! -z "$PROXY_HOST" ]; then
    addDockerProxy
fi
testDocker
getCustomImage 'registry' '2'
setupRegistryCerts
startRegistry

installGitLabs

exit 0

