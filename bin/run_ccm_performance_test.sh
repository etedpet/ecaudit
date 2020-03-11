#!/bin/bash
#
# Copyright 2019 Telefonaktiebolaget LM Ericsson
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

shopt -s extglob

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
CCM_CONFIG=${CCM_CONFIG_DIR:=~/.ccm}
JAR_FILE="${SCRIPT_PATH}/../ecaudit/target/ecaudit*.jar"

if [[ $# -ne 1 ]]; then
 echo "Missing argument - specify version of ccm cluster to create"
 exit 2
fi

CLUSTER_VERSION=$1

which ccm > /dev/null
if [[ $? -ne 0 ]]; then
 echo "ccm must be installed"
 exit 3
fi

ccm status | grep -qs UP
if [[ $? -eq 0 ]]; then
 echo "ccm cluster already running"
 exit 3
fi

if [[ ! -e ${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress ]]; then
 echo "ccm must have cassandra-stress version 3.11.4 in repository"
 exit 3
fi

ccm create -n 1 -v ${CLUSTER_VERSION} ecaudit
if [[ $? -ne 0 ]]; then
 echo "Failed to create ccm cluster 'ecaudit'"
 exit 3
fi

if [ ! -f ${JAR_FILE} ]; then
 echo "No jar file found. Build project and try again."
 exit 3
fi

create_dummy_tables() {
  tmpfile=$(mktemp /tmp/perf_test_data_XXXX.cql)
  echo "CREATE KEYSPACE aperfks WITH replication = {'class': 'SimpleStrategy', 'replication_factor': 1};" >> $tmpfile
  for i in {1..100}
  do
    echo "CREATE TABLE aperfks.tb${i} (key text PRIMARY KEY, value text);" >> $tmpfile
  done
  ccm node1 cqlsh -u cassandra -p cassandra -f $tmpfile
  rm $tmpfile
}

create_dummy_whitelists() {
  tmpfile=$(mktemp /tmp/perf_test_data_XXXX.cql)
  for i in {1..50}
  do
    echo "ALTER ROLE cassandra WITH OPTIONS = { 'GRANT AUDIT WHITELIST FOR ALL': 'data/aperfks/tb${i}' };" >> $tmpfile
  done
  for i in {51..100}
  do
    echo "ALTER ROLE cassandra WITH OPTIONS = { 'GRANT AUDIT WHITELIST FOR ALL': 'grants/data/aperfks/tb${i}' };" >> $tmpfile
  done
  ccm node1 cqlsh -u cassandra -p cassandra -f $tmpfile
  rm $tmpfile
}

set_yaml_based_filter() {
  CCM_CLUSTER_NAME=`cat ${CCM_CONFIG}/CURRENT`
  CLUSTER_PATH=${CCM_CONFIG}/${CCM_CLUSTER_NAME}
  echo "JVM_EXTRA_OPTS=\"\$JVM_EXTRA_OPTS -Decaudit.filter_type=YAML\"" >> ${CLUSTER_PATH}/cassandra.in.sh
  for NODE_PATH in ${CLUSTER_PATH}/node*;
  do
    echo "whitelist:" >> ${NODE_PATH}/conf/audit.yaml
    echo "  - cassandra" >> ${NODE_PATH}/conf/audit.yaml
  done
}

start_cassandra() {
  ccm start
  sleep 30
  ccm node1 nodetool disableautocompaction
  create_dummy_tables
}

stop_cassandra() {
  ccm clear
  sleep 5
}

echo "Generating performance report into ecaudit-performance.html"

start_cassandra
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=vanilla
stop_cassandra

${SCRIPT_PATH}/configure_ccm_cassandra_auth.sh
start_cassandra
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization
stop_cassandra

${SCRIPT_PATH}/configure_ccm_audit_chronicle.sh
set_yaml_based_filter
start_cassandra
create_dummy_whitelists
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization-audit-YAML-whitelist
stop_cassandra

${SCRIPT_PATH}/configure_ccm_audit_chronicle.sh
start_cassandra
create_dummy_whitelists
ccm node1 cqlsh -u cassandra -p cassandra -x "ALTER ROLE cassandra WITH OPTIONS = { 'GRANT AUDIT WHITELIST FOR ALL': 'data' };"
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization-audit-role-whitelist
stop_cassandra

${SCRIPT_PATH}/configure_ccm_audit_chronicle.sh
start_cassandra
create_dummy_whitelists
ccm node1 cqlsh -u cassandra -p cassandra -x "ALTER ROLE cassandra WITH OPTIONS = { 'GRANT AUDIT WHITELIST FOR ALL': 'grants/data' };"
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization-audit-role-whitelist-permission-derived
stop_cassandra

${SCRIPT_PATH}/configure_ccm_audit_chronicle.sh
start_cassandra
create_dummy_whitelists
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization-audit-chronicle
stop_cassandra

${SCRIPT_PATH}/configure_ccm_audit_slf4j.sh
start_cassandra
create_dummy_whitelists
${CCM_CONFIG}/repository/3.11.4/tools/bin/cassandra-stress write n=3000000 -node 127.0.0.1 -port jmx=7100 -mode native cql3 user=cassandra password=cassandra -rate threads=10 -graph file=ecaudit-performance.html title=ecAudit-Performance revision=authentication-authorization-audit-slf4j
stop_cassandra
