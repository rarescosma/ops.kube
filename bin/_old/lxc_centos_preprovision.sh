# CentOS Setup

# Add epel repository
yum -y install epel-release

# Add saltstack repository
yum -y install https://repo.saltstack.com/yum/redhat/salt-repo-latest-1.el7.noarch.rpm

# Install salt-minion (and other packages...)
yum -y install sudo less supervisor net-tools salt-minion

# Configure salt
HOSTNAME=$(hostname)

cat >/etc/salt/minion <<__EOF__
environment: kube
file_client: local
file_roots:
  kube:
    - /srv/salt
pillar_roots:
  kube:
    - /srv/pillar
cache_jobs: True
__EOF__

# Cleanup after ourselves
yum clean all