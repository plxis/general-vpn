#!/bin/bash

## VPN Access Through Foundry Tunnels
##
## Establishes an outer tunnel for SSH connectivity to your VPN host through Foundry jump host, 
## then establishes an inner tunnel (by way of the outer tunnel) for remote partner
## traffic to reach host.
##
## For mnemonic, local ports are all 10,000 + <remote-port>
##

## Variables
VPNHOST="ip-172-30-3-10.ec2.internal"
JUMPHOST="jump.mycompany.invalid"
FOUNDRY_USERNAME="first.last"
PARTNERCONNECTHOST="161.1.2.3"
PARTNERCONNECTPORT="41157"

## Tunnels

# Outer tunnel (to expose VPN Host's SSH locally)
echo "Establishing outer tunnel through jump host ($JUMPHOST) to VPN host ($VPNHOST)"
echo ssh -L10022:$VPNHOST:22 -N -f $FOUNDRY_USERNAME@$JUMPHOST
ssh -L10022:$VPNHOST:22 -N -f $FOUNDRY_USERNAME@$JUMPHOST

## Inner tunnel variables
INNERTUNNELS=""

# Inner Tunnel: Remote Partner
INNERTUNNELS="$INNERTUNNELS -L11157:$PARTNERCONNECTHOST:$PARTNERCONNECTPORT"

# Inner Tunnel: HTTPS to Google (for testing)
INNERTUNNELS="$INNERTUNNELS -L10443:www.google.com:443"

# Inner tunnel (to expose partner host, Google, etc. locally) 
echo "Establishing inner tunnel(s) through outer tunnel to partner host ($PARTNERCONNECTHOST)"
echo ssh -p 10022 $INNERTUNNELS -N -f $FOUNDRY_USERNAME@localhost
ssh -p 10022 $INNERTUNNELS -N -f $FOUNDRY_USERNAME@localhost

## Test (Google)
#curl -vv -k https://localhost:10443

