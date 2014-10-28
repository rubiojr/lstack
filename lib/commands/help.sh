#!/bin/bash
set -e

columnize() {
  echo $@ | awk -F, '{ printf "%-20s %-40s\n", $1, $2}'
}

echo "Usage: lstack [options] [command]"
echo
echo "OPTIONS"
echo
columnize "--help",         "Print help"
columnize "--version",      "Print version"
columnize "--nocolor",      "No colors for the output"
echo
echo "COMMANDS"
echo
columnize "bootstrap",      "Bootstrap the OpenStack container"
columnize "info",           "Print container info (lxc-info)"
columnize "ssh",            "SSH into the container"
columnize "nova",           "Run the nova command inside the container"
columnize "destroy",        "Destroy the container"
columnize "ip",             "Print the IP of the container"
columnize "importimg",      "Import a QCOW2 image to Glance"
columnize "deploy",         "Create an instance from a QCOW2 image"
columnize "forward",        "Forward ports to a running intsance"
echo
