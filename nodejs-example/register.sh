#!/bin/bash

PWD=$(pwd)

cd ../chef-repo

knife delete node example1 2> /dev/null
knife delete client example1 2> /dev/null
knife bootstrap 192.168.50.10 --sudo -x vagrant -P vagrant -N "example1"

cd $PWD
