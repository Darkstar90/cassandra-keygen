# Cassandra SSL Cert Generator

---

## Intro To cassandra-keygen

The purpose of this script is to automate the generation of SSL certificates for multiple Cassandra nodes when setting up node-to-node or client-to-node encryption.

## How To Use This script

Decide whether you would like to generate node certificates, import node certfificates into the keystore, or generate a truststore.
Add all necessary arguments in the command line
when running the script, depending on the choice you made above. The script will first prompt you to choose the run mode.
Enter your choice and press `<Enter>`. The script will complete your request and output any created files to
the destination directory you specified in the <-d> argument.

## Script Modes

- Generate Node Certificates)
   Required arguments: <-n, -d, -c, -p, -s, -k>

- Import Node Certificates)
   Required arguments: <-n, -d, -p>

- Generate Truststore)
	 Required arguments: <-d, -t>

## Available Options

   --nodes=<number of nodes> | -n=3
      The number of nodes in your cluster needing certificates.

   --directory=<directory location> | -d=/etc/cassandra/conf/.keystore
      The directory where certificate files will be generated.

   --cluster=<cluster name> | -c=Cassandra_Cluster
      Name of the cluster.

   --password=<storepass/keypass password> | -p=cassandra
      The password to use for the storepass and keypass. Both must be the same in Cassandra.

   --truststore=<truststore password> | -t=cassandra
      The password to use for the truststore.

   --sslconfig=<openssl config file location> | -s=/etc/cassandra/conf/.keystore
      The location of the config file openssl uses for key generation.

   --keysize=<key size> | -k=2048
     Set the size of the encryption key. Common sizes include 1024, 2048, or 4096 bits.

 ## Example Usage

An example usage of each mode is demonstrated below, for a cluster of 6 nodes.

**Generate Node Certificates**

	bash cassandra-keygen.sh  --nodes 6 --directory /etc/cassandra/conf/.keystore --cluster Cassandra_Cluster --password cassandra --sslconfig /etc/cassandra/conf/rootCAcert.conf --keysize 4096

**Import Node Certificates**

	bash cassandra-keygen.sh -n 6 -d /etc/cassandra/conf/.keystore -p cassandra

**Generate Truststore**

	bash cassandra-keygen.sh --directory /etc/cassandra/conf/.keystore --truststore cassandra

**Do All Actions**

	bash cassandra-keygen.sh  --nodes 6 --directory /etc/cassandra/conf/.keystore --cluster Cassandra_Cluster --password cassandra --truststore cassandra --sslconfig /etc/cassandra/conf/rootCAcert.conf --keysize 4096
