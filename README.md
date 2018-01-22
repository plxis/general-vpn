# general-vpn

General VPN is a project to automate the creation of a VPN server using [Strong Swan](https://www.strongswan.org) in AWS. It supports load balanced VPNs and is accessible via the Jump host provided by Foundry.

## Deployment

To create a new VPN environment you need to customize the environment.json with settings necessary for the desired VPN connectivity, and deploy via Shipyard.

## User Guide

This VPN was originally built for a single partner, but expanded to be more generic to support other AWS VPN needs.

### Configuration

During the installation, the scripts pull the AWS external IP address from the AWS instance you are installing this project into. This IP will be needed by the remote party so they can build the Site to Site VPN tunnel on their side. This will be noted as the Peer IP address.

Note: this IP is not forwarding traffic from the public internet to the AWS VPN Host server, so this means the remote side will not be able to initiate a tunnel to the General VPN host within AWS, unless a different configuration is created. 

You can only initiate the tunnel from AWS to the remote site.

For the VPN peering you will need to determine some of these before you can deploy the project
#### Site A (Your network - Left Side)

* Peer IP (External AWS IP) - Determined at deployment time, but could be obtained manually if the remote side won't provide their end until you provide yours.
* Host IP (Internal AWS IP) - Should be statically set so when you rebuild it doesn't change.

Current limit from AWS is that you have to use a RFC1918 IP.  Some peers request an external IP to prevent overlap from other partners.  AWS may not be the solution for something like this, more research would need to be done if this request was made by a partner.

* PSK: Each side should agree on a PSK and length
* IKE Version 2 is suggested to help limit NAT issues within AWS.
* Phase 1: aes 256 / sha1 / DH5 / 8h lifetime (This is a good starting point)
* Phase 2: aes 256 / sha1 / DH5 / 1h lifetime (This is a good starting point)
* PFS: enabled

#### Site B (Remote - Right Side)

* Peer IP: Their external IP of their firewall
* Host IP: Their host IP you will be connecting to over the VPN, sometimes called interesting traffic.
* Ports:  This all depends on the partner and what is being accessed.

Note, these ports are not managed within the AWS security group sine they are traveling through the tunnel. 
If there's a local firewall on the AWS host, consider opening these ports and IPs.

### Reservation of VPN Hosts

The list below describes one methodology for maintaining a list of the hosts that have been setup using general VPN, as well as the IPs reserved for them. This is important, so they can be rebuilt and use the same IP, preventing the remote side from having to update their configurations.


| Partner  | Remt Peer | Remt Host | Your Peer   | Your Host   | IKE ESP        | IKE Version |
| -------- |:---------:|:---------:|:-----------:|:-----------:|:--------------:|:-----------:|
| Funco    | 208.1.2.3 | 167.4.5.6 | 34.10.20.30 | 172.30.3.10 | aes256 / sha1 / dh5 aes256 / sha1 / dh5 | IKE v2
| Funco    | 121.1.2.3 | 201.4.5.6 | 34.10.20.30 | 172.30.3.11 | aes256 / sha1 / dh5 aes256 / sha1 / dh5 | IKE v2

## Usage
Ensure connectivity to Jump Host by first SSHing to the Jump host provided by Foundry:
```
ssh myusername@jump.mycompany.invalid
```

Establish an Outer SSH tunnel for SSH traffic from local workstation to VPN host. Ensure the VPNHOST variable is set in your environment (probably 172.30.3.10 if following above sample table).
```
ssh -L10022:$VPNHOST:22 -N myusername@jump.mycompany.invalid
```

Establish an Inner SSH Tunnel for the tunneled traffic from local workstation to remote host by way of the Outer SSH Tunnel. Ensure the LOCALPORT, REMOTEHOST and REMOTEPORT variables are set in your environment.

```
ssh -p 10022 -L$LOCALPORT:$REMOTEHOST:$REMOTEPORT -N myusername@localhost
```

Use the Inner SSH Tunnel's local port to access the partner network:

```
localhost:11157
```

## Troubleshooting

### General Notes

The left side in this configuration is your network and the right side is the remote (partner) side.

Login to the VPN Host server to validate the VPN is up and running and confirm the tunnel is up and traffic is passing by using the following commands.

* Validate the strong swan service is running

  ```
  sudo service strongswan status
  ```

* List currently active IKE_SAs

  ```
  sudo swanctl -l
  ```

* List loaded configurations

  ```
  sudo swanctl -L
  ```

* Trace logging output

  ```
  sudo swanctl -T
  ```

* State monitoring for xfrm objects (helpful to see traffic going to and from local and remote host):

  ```
  sudo ip xfrm monitor
  ```

* Show the statistics of the xfrm state (helpful to see the packet counts of both sides of the VPN tunnel, such as to determine if the packet is leaving your network, but not coming back from the remote side.)

  ```
  sudo ip -s xfrm state
  ```

* List the policy

  ```
  sudo ip xfrm policy list
  ```

* Packet Capturing

  ```
  sudo tcpdump host REMOTE_PEER_IP -i any -vv
  sudo tcpdump -i any -nn esp
  ```

### Routing Table

* StrongSwan injects its ipsec routes into rule 220 of the routing policy database. You can list all the rules by running:

  ```
  sudo ip rule
  ```

* You can list the contents of the specific rule strongSwan created:

  ```
  sudo ip route list table 220
  ```

* Check the AWS security group from the AWS console for this General VPN Host to validate the needed ports and IP addresses are open. Typically you need the following ports open (They are automatically opened via the configuration scripts when building the General VPN Host):

  ```
  IP: Peer address of remote Site
  Port 4500 & 500 UDP
  Port 4500 TCP
  ```

* If needed you can create a custom rule for protocol 50 or protocol 51 from the console for testing.  This normally should not be needed how ever.  If determined it is needed, the scripts should be updated so you can rebuild and recreate it easily.

  ```
  protocol 50 - Encapsulation Security Payload (ESP) IPSec
  protocol 51 - Authentication Header (AH) IPSec
  ```