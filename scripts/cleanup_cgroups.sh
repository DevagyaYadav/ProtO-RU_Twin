#!/bin/bash
# Clean up stale srs cgroups left over from Docker or previous runs
for cg in srs_housekeeping srs_isolated; do
    if [ -d "/sys/fs/cgroup/$cg" ]; then
        echo "Cleaning /sys/fs/cgroup/$cg"
        while read -r pid; do
            [ -n "$pid" ] && echo "$pid" | sudo tee /sys/fs/cgroup/cgroup.procs > /dev/null 2>&1
        done < /sys/fs/cgroup/$cg/cgroup.procs 2>/dev/null
        sudo rmdir "/sys/fs/cgroup/$cg" 2>/dev/null
    fi
done
echo $$ | sudo tee /sys/fs/cgroup/cgroup.procs > /dev/null 2>&1
echo "Cleanup done. Current cgroup: $(cat /proc/self/cgroup)"
