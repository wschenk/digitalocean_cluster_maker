# digitalocean_cluster_maker
Ruby script to spin up and down test clusters

This script automates the process outlines in the tutorial below for spinning up a 3 machine core-os cluster on digitalocean.  (Easily extended to more)

https://www.digitalocean.com/community/tutorials/how-to-secure-your-coreos-cluster-with-tls-ssl-and-firewall-rules

## Usage

1. Get an account on digitial ocean
2. Get an DO api token here: https://cloud.digitalocean.com/settings/api/tokens
3. export TOKEN=thattokenyoujustgot
4. Install your SSH key on DO
5. export DO_SSH_KEY_FINGERPRINT=thatfingerprint
6. ruby cluster.rb start
7. (If that doesn't work, run again)
8. ruby cluster.rb info
9. ruby cluster.rb ssh1
10. ruby cluster.rb ssh2
11. ruby cluster.rb ssh3
12. ruby cluster.rb shutdown

