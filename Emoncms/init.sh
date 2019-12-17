#!/bin/bash

user=$USER
openenergymonitor_dir=/opt/openenergymonitor
emoncms_dir=/opt/emoncms
emoncms_www=/var/www/emoncms
emoncms_var=/var/opt/emoncms

[ -d "$openenergymonitor_dir" ] && sudo rm -r $openenergymonitor_dir
sudo mkdir $openenergymonitor_dir
sudo chown $user $openenergymonitor_dir

[ -d "$emoncms_dir" ] && sudo rm -r $emoncms_dir
sudo mkdir $emoncms_dir
sudo chown $user $emoncms_dir

[ -d "$emoncms_www" ] && sudo rm -r $emoncms_www
[ -d "$emoncms_var" ] && sudo rm -r $emoncms_var

cd $openenergymonitor_dir

sudo git clone https://github.com/openenergymonitor/EmonScripts.git
cd $openenergymonitor_dir/EmonScripts
sudo git checkout stable

cd $openenergymonitor_dir/EmonScripts/install
./main.sh
cd