#!/bin/bash
set -e

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y ppa:rubiojr/lstack
sudo add-apt-repository -y ppa:ubuntu-lxc/stable
sudo apt-get update
sudo apt-get install -y lstack

sudo lstack --nonyancat bootstrap
