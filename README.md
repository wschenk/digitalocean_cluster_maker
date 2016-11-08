# digitalocean_cluster_maker
Ruby script to spin up and down test clusters

This script automates the process outlines in the tutorial below for spinning up a 3 machine core-os cluster on digitalocean.  (Easily extended to more)

https://www.digitalocean.com/community/tutorials/how-to-secure-your-coreos-cluster-with-tls-ssl-and-firewall-rules

# WARNING

This script assumes that digitialocean is a playground, and specifically `shutdown` will destroy all droplets with `coreos` in it's name so be careful!!

## Usage

1. Get an account on digital ocean
2. Get an DO api token here: https://cloud.digitalocean.com/settings/api/tokens
3. `export TOKEN=thattokenyoujustgot`
4. Install your SSH key on DO
5. `export DO_SSH_KEY_FINGERPRINT=thatfingerprint`
6. `ruby cluster.rb start`
7. wait for the machines to spin up.
8. double check that you can connect using `ruby cluster.rb ssh`.  if so, exit.
9. `ruby cluster.rb start` again to copy over config files
10. `ruby cluster.rb info`
11. if that hangs, wait or try `ruby cluster.rb restart`
12. `ruby cluster.rb ssh1`
13. `ruby cluster.rb ssh2`
14. `ruby cluster.rb ssh3`
15. `ruby cluster.rb shutdown`

## Adding machines to a cluster

1. `export CLUSTER_SIZE=5`
2. `ruby cluster.rb start`
3. wait again for things to spin up
4. `ruby cluster.rb start` to copy over all the necessary files
5. Possibly restart


## What does it do

Let me describe the methods on `Cluster`, and then it should be clear:

`droplets` - pulls down a list of machines with coreos in it's name, will cache the results for 5 minutes.  This will pull out name, public and private ip.

`info` - lists out all machines in the coreos cluster, and will run `fleetctl list-machines` on the first node to see if everything is wired up correctly.

`ensure_droplets` - this will make sure that `@count` droplets have been started up.  (Defaults to 3) It will pull down a new etcd discover url if needed for your new cluster.  If it needs to start up everthing, then it will wait for 20 seconds before moving on.  Uses the `makecoreos.sh` script to spin up the droplets, which are 512M on NYC3 by default.

`get_binaries` - downloads the OSX version of cfssl

`copy_iptable_rules` - creates a file that opens up communication only on the private_ips for each of the coreos boxes and installs that on each of the boxes.  If you create a new machine, running `cluster.rb start` again will make sure that the ips are added and distributed to all the machines

`copy_pem` - creates and distributes the self-signed certificates for all of the machines.

`shutdown` - destroys each of the instances, deletes all local work files

## What commands the cli accepts

`start` - calls `ensure_droplets`, `copy_iptable_rules`, `copy_pem` -- this brings things up, you may need to wait for things to settle a bit or you may need to cycle the machines after the iptables get installed.

`restart` - restarts all of the machines

`ssh` - connects to the first machine

`ssh1`, `ssh2`, `ssh3` - connects to the respective machine

`shutdown` - removes everything

## Author

@wschenk, will@happyfuncorp.com