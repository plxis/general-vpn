#!/bin/bash
set -e

instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

# Configure timezone
rm /etc/localtime && ln -s /usr/share/zoneinfo/GMT /etc/localtime

# Install dependent software packages; only jq and awslogs are mandatory for all hosts.
yum update -y
result=1
attempt=0
while [[ $attempt -lt 25 && $result -ne 0 ]]; do
  yum install -y jq awslogs nfs-utils strongswan --enablerepo=epel
  result=$?
  [ $result -ne 0 ] && sleep 5
  attempt=$((attempt+1))
done

# Mount EFS targets
mkdir -p "${users_local_mount}"
echo "Mounting ${users_efs_target} at ${users_local_mount}"
mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 ${users_efs_target}: ${users_local_mount}

# Configure shared users, cloudwatch logs, etc
if [[ -x /users/bootstrap/runOnNewHost.sh ]]; then
  /users/bootstrap/runOnNewHost.sh "vpn" "${context}"
else
  echo "ERROR: User bootstrap script is not available. Expected to be mounted at /users/bootstrap/runOnNewHost.sh"
fi

### Setup main strongswan ipsec.conf configuration file
### Setup IPSEC and Secrets file for VPN
vpnhost_publicip=$(curl -s http://icanhazip.com)
vpnhost_privateip=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
cat << EOF > /etc/strongswan/ipsec.conf
config setup
        # plutodebug=all
        # plutostderrlog=/var/log/pluto.log

## connection definition ##
conn vpn-tunnel-01
        authby=secret
        auto=start
        keyexchange=ikev2
        mobike=no
        ikelifetime=8h
        ike=aes256-sha1-modp1536
        keylife=1h
        esp=aes256-sha1-modp1536
        compress=no
        type=tunnel
        left=$vpnhost_privateip
        leftid=$vpnhost_publicip
        leftsubnet=$vpnhost_privateip/32
        right=${vpn_dest_ip}
        rightid=${vpn_dest_ip}
        rightsubnet=${vpn_dest_subnet}
EOF
### Secret File
cat << EOF > /etc/strongswan/ipsec.secrets
## VPN PSK for vpn-tunnel-01
${vpn_dest_ip} $vpnhost_publicip : PSK "${vpn_dest_secret}"
EOF

chkconfig --level 3 strongswan on
service strongswan start
