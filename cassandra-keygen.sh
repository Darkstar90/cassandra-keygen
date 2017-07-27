###############################################
## NAME: Cassandra SSL Cert Generator
## AUTHOR: Andrew Lescher
## CREATED: 7/18/2017
## DESCRIPTION: Use this script to generate public and private keys, import them into a java keystore, and create
## a truststore file for Cassandra nodes to communicate via ssl encryption.
###############################################

usage() 
{
   USAGE=$(
cat << EOF

**Cassandra SSL Cert Generator**

HOW TO USE THIS SCRIPT:

Decide whether you would like to generate node certificates, import node certfificates into the keystore, or generate a truststore.
Add all necessary arguments in the command line
when running the script, depending on the choice you made above. The script will first prompt you to choose the run mode. 
Enter your choice and press <Enter>. The script will complete your request and output any created files to
the destination directory you specified in the <-d> argument.

MODES:

Generate Node Certificates)
   Required arguments: <-n, -d, -c, -p, -s, -k>

Import Node Certificates)
   Required arguments: <-n, -d, -p>

Generate Truststore)
   Required arguments: <-d, -t>

OPTIONS:

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

EOF
)

   echo "$USAGE" >&2
   echo "">&2

   exit 1;
}

while [[ $# -gt 0 ]]
do option="$1"
  case "${option}" in
     -h|--help)
        usage
        shift
        ;;

     -n|--nodes)
        nodes="$2"
        shift
        ;;

     -d|--directory)
        keystore_dir="$2"
        shift
        ;;

     -c|--cluster)
        cluster_name="$2"
        shift
        ;;

     -p|--password)
        password="$2"
        shift
        ;;

     -t|--truststore)
        truststore_pass="$2"
        shift
        ;;
    
     -s|--sslconfig)
        sslconfig="$2"
        shift
        ;;

     -k|--keysize)
        keysize="$2"
        shift
        ;;

     --)
        break
        shift
        ;;

     *)
        echo -e "Invalid argument: \"${option}\"\n"
        usage
        ;;

  esac
  shift
done

# Select program mode
echo -e "\n**Cassandra SSL Cert Generator**\nPlease select one of the following options:\n"
echo -e "(g) Generate Node Certificates\n(i) Import certificates into keystore\n(t) Generate a truststore file\n(a) Do all actions\n"
read input

if [[ ! "$input" =~ ^(g|i|t|a)$ ]]; then
   echo -e "\n("$input") is not a valid option."
   exit 1;
fi

gen_cert()
{
echo -e "\n"
# Remove public and private key files if they exist
cd ${keystore_dir} && rm -vf {ca-cert.cert,ca-cert.key}

# Create public and private key files
cd ${keystore_dir} && openssl req -config ${sslconfig} -new -x509 -nodes -keyout ca-cert.key -out ca-cert.cert -days 365
cd ${keystore_dir} && openssl x509 -in ca-cert.cert -text -noout

for ((i=0; i < nodes; i++))
do
   node_id="node${i}"
   
   echo -e "\n"
   echo -e "=========================================="
   echo -e "Generating certificates for ${node_id}"
   echo -e "=========================================="
   echo -e "\n"

   # Remove certificate and keystore files if they exist
   cd ${keystore_dir} && rm -vf {${node_id}-keystore.jks,${node_id}.cert,${node_id}-cert.csr,${node_id}-signed.crt} 

   # Generate keystore
   cd ${keystore_dir} && keytool -genkeypair -v -keyalg RSA -alias ${node_id} -keystore ${node_id}-keystore.jks -storepass ${password} -keypass ${password} -validity 365 -keysize ${keysize} -dname "CN=${node_id}, OU=${cluster_name}"

   # Verify key
   cd ${keystore_dir} && keytool -list -v -keystore ${node_id}-keystore.jks -storepass ${password}

   # Generate signing request file
   cd ${keystore_dir} && keytool -certreq -v -keystore ${node_id}-keystore.jks -alias ${node_id} -file ${node_id}-cert.csr -keypass ${password} -storepass ${password} -dname "CN=${node_id}, OU=${cluster_name}"

   # Sign each node's certificate
   cd ${keystore_dir} && openssl x509 -req -CA ca-cert.cert -CAkey ca-cert.key -in ${node_id}-cert.csr -out ${node_id}-signed.cert -days 365 -CAcreateserial -passin pass:${password}

   # Verify each signed certificate
   cd ${keystore_dir} && openssl verify -CAfile ca-cert.cert ${node_id}-signed.cert 

   echo -e "\n"
   echo -e "========================================="
   echo -e "Certificates for ${node_id} completed!"
   echo -e "========================================="
   echo -e "\n"
done
}

import_keystore()
{
for ((i=0; i < nodes; i++))
do 

   node_id="node${i}"

   echo -e "\n"
   echo -e "=========================================="
   echo -e "Importing certificates for ${node_id}"
   echo -e "=========================================="
   echo -e "\n"

   # Import the certificate authority into the keystore
   cd ${keystore_dir} && keytool -v -importcert -keystore ${node_id}-keystore.jks -alias ca-cert -file ca-cert.cert -noprompt -keypass ${password} -storepass ${password}
   
   # Import the signed certificate into the keystore
   cd ${keystore_dir} && keytool -v -importcert -keystore ${node_id}-keystore.jks -alias ${node_id} -file ${node_id}-signed.cert -noprompt -keypass ${password} -storepass ${password}


   echo -e "\n"
   echo -e "========================================="
   echo -e "Certificates for ${node_id} imported!"
   echo -e "========================================="
   echo -e "\n"

done
}

create_truststore()
{
   # Remove truststore file if exists
   cd ${keystore_dir} && rm -fv cassandra-truststore.jks

   echo -e "\n"
   echo -e "=========================================="
   echo -e "Generating truststore"
   echo -e "=========================================="
   echo -e "\n"

   # Generate truststore file
   cd ${keystore_dir} && keytool -v -importcert -keystore cassandra-truststore.jks -alias truststore -file ca-cert.cert -noprompt -keypass ${truststore_pass}  -storepass ${truststore_pass}

   # Verify key
   cd ${keystore_dir} && keytool -list -v -keystore cassandra-truststore.jks -storepass ${truststore_pass}

   echo -e "\n"
   echo -e "=========================================="
   echo -e "Truststore created!"
   echo -e "=========================================="
   echo -e "\n"
}


if [ "$input" == "g" ]; then
   gen_cert

   # Display input values
   echo -e "\n*****************************************\n"
   printf "NUMBER OF NODES = ${nodes}\n"
   printf "KEYSTORE DIRECTORY = ${keystore_dir}\n"
   printf "CLUSTER NAME = ${cluster_name}\n"
   printf "STOREPASS/KEYPASS PASSWORD = ${password}\n"
   printf "TRUSTSTORE PASSWORD = ${truststore_pass}\n"
   printf "OPENSSL CONFIG DIRECTORY = ${sslconfig}\n"
   printf "KEYSIZE = ${keysize}\n"
   echo -e "\n*****************************************\n"

   exit 1
fi

if [ "$input" == "i" ]; then
   import_keystore

   # Display input values
   echo -e "\n*****************************************\n"
   printf "NUMBER OF NODES = ${nodes}\n"
   printf "KEYSTORE DIRECTORY = ${keystore_dir}\n"
   printf "CLUSTER NAME = ${cluster_name}\n"
   printf "STOREPASS/KEYPASS PASSWORD = ${password}\n"
   printf "TRUSTSTORE PASSWORD = ${truststore_pass}\n"
   printf "OPENSSL CONFIG DIRECTORY = ${sslconfig}\n"
   printf "KEYSIZE = ${keysize}\n"
   echo -e "\n*****************************************\n"

   exit 1
fi

if [ "$input" == "t" ]; then
   create_truststore

   # Display input values
   echo -e "\n*****************************************\n"
   printf "NUMBER OF NODES = ${nodes}\n"
   printf "KEYSTORE DIRECTORY = ${keystore_dir}\n"
   printf "CLUSTER NAME = ${cluster_name}\n"
   printf "STOREPASS/KEYPASS PASSWORD = ${password}\n"
   printf "TRUSTSTORE PASSWORD = ${truststore_pass}\n"
   printf "OPENSSL CONFIG DIRECTORY = ${sslconfig}\n"
   printf "KEYSIZE = ${keysize}\n"
   echo -e "\n*****************************************\n"

   exit 1
fi

if [ "$input" == "a" ]; then
   gen_cert
   import_keystore
   create_truststore

   # Display input values
   echo -e "\n*****************************************\n"
   printf "NUMBER OF NODES = ${nodes}\n"
   printf "KEYSTORE DIRECTORY = ${keystore_dir}\n"
   printf "CLUSTER NAME = ${cluster_name}\n"
   printf "STOREPASS/KEYPASS PASSWORD = ${password}\n"
   printf "TRUSTSTORE PASSWORD = ${truststore_pass}\n"
   printf "OPENSSL CONFIG DIRECTORY = ${sslconfig}\n"
   printf "KEYSIZE = ${keysize}\n"
   echo -e "\n*****************************************\n"

   exit 1
fi

