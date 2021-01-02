#!/bin/bash

##
## print-all-cert-expire-date.sh  - OpenShift script to print all TLS cert expire date
##
## - This scrpit is designed to run with root user as it reads files under /etc/origin directory
## - Do not use `openssl x509 -in` command which can only handle first cert in a given input
##
setterm -linewrap off
VERBOSE=false
if [ "$1" == "-v" ]; then
    VERBOSE=true
fi

function show_cert() {
  if [ "$VERBOSE" == "true" ]; then
    openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text | egrep -A9 ^Cert
  else
    openssl crl2pkcs7 -nocrl -certfile /dev/stdin | openssl pkcs7 -print_certs -text | grep Validity -A2 | tr '\n' ' '
  fi
}

## Process API Cert

## Process Wildcard Cert

## Process Registry Cert





## Process all cert files under /etc/origin/node directories --> Each node
### The following sections
### Script execution machine require password-less SSH access to all nodes
echo "------------------------- all master nodes TLS certificate -------------------------"
for node in `oc get nodes -l 'node-role.kubernetes.io/master=true' |awk 'NR>1'|awk '{print $1}'`; do
  for f in `ssh $node "sudo find /etc/origin/{master,node} -type f \( -name '*.crt' -o -name '*pem' \)"`; do
    echo -n "#### $node - $f # "
    ssh $node sudo cat $f | show_cert 
    echo 
  done
done

## Process all cert files under /etc/origin/master directories --> Each master node
### The following sections
### Script execution machine require password-less SSH access to all nodes
echo "------------------------- all master nodes kubeconfig certificate -------------------------"
for node in `oc get nodes -l 'node-role.kubernetes.io/master=true' |awk 'NR>1'|awk '{print $1}'`; do
  for f in `ssh $node "sudo  find /etc/origin/{master,node} -type f -name '*kubeconfig' "`; do
    echo -n "#### $node - $f # "
    ssh $node sudo cat $f |awk '/cert/ {print $2}' | base64 -d | show_cert 
    echo 
  done
done

## Process all service serving cert secrets

oc get service --no-headers --all-namespaces -o custom-columns='NAMESPACE:{metadata.namespace},NAME:{metadata.name},SERVING CERT:{metadata.annotations.service\.alpha\.openshift\.io/serving-cert-secret-name}' |
while IFS= read line; do
   items=( $line )
   NAMESPACE=${items[0]}
   SERVICE=${items[1]}
   SECRET=${items[2]}
   if [ $SECRET == "<none>" ]; then
     continue
   fi
   echo -n "####  secret/$SECRET -n $NAMESPACE # "
   oc get secret/$SECRET -n $NAMESPACE --template='{{index .data "tls.crt"}}'  | base64 -d | show_cert
   echo 
done

## Process other custom TLS secrets, router, docker-registry, logging and metrics components

cat <<EOF |
default router-certs tls.crt
default registry-certificates registry.crt
kube-service-catalog apiserver-ssl tls.crt
openshift-metrics-server metrics-server-certs ca.crt
openshift-metrics-server metrics-server-certs tls.crt
openshift-logging logging-elasticsearch admin-ca
openshift-logging logging-elasticsearch admin-cert
openshift-logging logging-curator ca
openshift-logging logging-curator cert
openshift-logging logging-fluentd ca
openshift-logging logging-fluentd cert
openshift-logging logging-fluentd ops-ca
openshift-logging logging-fluentd ops-cert
openshift-logging logging-kibana ca
openshift-logging logging-kibana cert
openshift-logging logging-kibana-proxy server-cert
openshift-infra hawkular-metrics-certs ca.crt
openshift-infra hawkular-metrics-certs tls.crt
openshift-infra hawkular-metrics-certs tls.truststore.crt
openshift-infra hawkular-cassandra-certs tls.crt
openshift-infra hawkular-cassandra-certs tls.client.truststore.crt
openshift-infra hawkular-cassandra-certs tls.peer.truststore.crt
openshift-infra heapster-certs tls.crt
EOF
while IFS= read line; do
  items=( $line )
  NAMESPACE=${items[0]}
  SECRET=${items[1]}
  FIELD=${items[2]}
  echo -n "####   secret/$SECRET -n $NAMESPACE, field: $FIELD #"
  oc get secret/$SECRET -n $NAMESPACE --template="{{index .data \"$FIELD\"}}"  | base64 -d | show_cert
  echo 
done


## Process all cert files under /etc/origin/node directories --> Each node
### The following sections
### Script execution machine require password-less SSH access to all nodes
echo "------------------------- all nodes' kubelet TLS certificate -------------------------"
for node in `oc get nodes |awk 'NR>1'|awk '{print $1}'`; do
  for f in `ssh $node "sudo find /etc/origin/node -type f \( -name '*.crt' -o -name '*pem' \)"`; do
    echo -n "####  $node - $f  #"
    ssh $node sudo cat $f | show_cert
    echo 
  done
done

setterm -linewrap on
