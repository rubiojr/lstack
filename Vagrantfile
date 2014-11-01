# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|

  config.vm.box = "ubuntu/trusty64"

  config.vm.provider "vmware_fusion" do |v|
    v.vmx['memsize']   = '1024'
    v.vmx['numvcpus']  = '2'
    v.vmx['vhv.allow'] = 'TRUE'
  end

  config.vm.provision "shell", path: "script/vagrant_provision.sh"
end