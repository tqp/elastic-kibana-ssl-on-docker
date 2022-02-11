#!/usr/bin/env bash
before=`wsl -d docker-desktop sysctl vm.max_map_count`
echo "Before: $before"
echo "Setting vm.max_map_count..."
wsl -d docker-desktop sysctl -w vm.max_map_count=262144
after=`wsl -d docker-desktop sysctl vm.max_map_count`
echo "After: $after"
