#!/usr/bin/env bash
# Parse the cluster's Slurm configuration with a real slurmctld (no munge/slurmdbd needed):
# the controller must load nodes, partitions and the switch topology and reach "Running as primary".
set -euo pipefail
SRC=$(cd "$(dirname "$0")/../slurm/etc" && pwd)
T=$(mktemp -d)
cp "$SRC"/* "$T/"
mkdir -p "$T/state" "$T/log"
# Test-only overrides: local hostname, writable paths, no external daemons.
sed -i \
  -e "s#^SlurmctldHost=.*#SlurmctldHost=$(hostname -s)#" \
  -e "s#/var/spool/slurmctld#$T/state#; s#/var/spool/slurmd#$T/state#; s#/var/log/slurm#$T/log#" \
  -e "s#^AuthType=.*#AuthType=auth/none#" \
  -e "s#^AccountingStorageType=.*#AccountingStorageType=accounting_storage/none#" \
  -e "/^AccountingStorageTRES=/d; /^PlugStackConfig=/d" \
  "$T/slurm.conf"
printf 'CredType=cred/none\nMailProg=/bin/true\n' >> "$T/slurm.conf"
SLURM_CONF="$T/slurm.conf" timeout 10 slurmctld -D -i -vvv > "$T/ctl.out" 2>&1 || true
grep -q "Running as primary controller" "$T/ctl.out" || { cat "$T/ctl.out"; exit 1; }
grep -q "preparing for 2 partitions" "$T/ctl.out"
grep -q "name:spine nodes:gpu\[01-04\]" "$T/ctl.out"
echo "slurm.conf, gres.conf, cgroup.conf and topology.conf accepted by $(slurmctld -V)"
