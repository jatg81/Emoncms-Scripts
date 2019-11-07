#!/bin/bash
log="/home/pi/data/emoncms-export.log"
exec 1>>$log
date=$(date +"%Y-%m-%d")
SECONDS=0

echo "========================= Emoncms export start =========================================="
date
echo "This export script has been modified by jatg"
echo ""
if [ -f /home/pi/backup/config.cfg ]
then
    source /home/pi/backup/config.cfg
    echo "-----------------------------------------------------------------------------------------"
    echo "File config.cfg: "
    echo "Location of database:       $mysql_path"
    echo "Location of emonhub.conf:   $emonhub_config_path"
    echo "Location of Emoncms:        $emoncms_location"
    echo "Location of Node Red:       $nodered_path"
    echo "Backup destinations:        $backup_location/export & $backup_location2"
    echo "-----------------------------------------------------------------------------------------"
else
    echo "ERROR: Backup /home/pi/backup/config.cfg file does not exist"
    exit 1
fi

export_file="$backup_location/export"
phpfina="$mysql_path/phpfina"
phptimeseries="$mysql_path/phptimeseries"
emonhub_conf="$emonhub_config_path/emonhub.conf"
emoncms_set="$emoncms_location/settings.php"
bkp_tar="$backup_location/export/emoncms-backup-$date.tar"

rm $export_file/*

#Avoid change files in phpfina and phptimeseries during backup 
echo "- Stopping mqtt_input service"
sudo service mqtt_input stop

#phpfina
echo "- Adding folder phpfina to: emoncms-backup-$date.tar"
echo " "
tar -c -C $backup_location phpfina |\
pv -fptb -s $(du -sb $phpfina | awk '{print $1}') 2> >( while read -N 1 c;  do if [[ $c =~ $'\r' ]]; then sed -i "$ s/.*/  $pv_bar/g" $log; pv_bar=''; else pv_bar+="$c";  fi  done ) > $bkp_tar
sleep 1;
exec 1>>$log

#phptimeseries
echo "- Adding folder phptimeseries to: emoncms-backup-$date.tar"
tar -rf $bkp_tar -C $backup_location phptimeseries 2>&1

if [ $? -ne 0 ]; then
    echo "Error: failed to tar phptimeseries data"
    echo "emoncms export failed"
    sudo rm -r $export_file/*
    exit 1
fi

echo "- Restarting mqtt_input service"
sudo service mqtt_input start > /dev/null

# Get MYSQL authentication details from settings.php
if [ -f /home/pi/backup/get_emoncms_mysql_auth.php ]; then
    auth=$(echo $emoncms_location | php /home/pi/backup/get_emoncms_mysql_auth.php php)
    IFS=":" read username password <<< "$auth"
else
    echo "Error: cannot read MYSQL authentication details from Emoncms settings.php"
    echo "$PWD"
    sudo rm -r $export_file/*
    exit 1
fi

#Create temporal directory to avoid data change on files during backup process
echo "- Creating temporary folder: export/temp"
mkdir $export_file/temp

# MYSQL Dump Emoncms database
if [ -n "$username" ]; then # if username string is not empty
    mysqldump -u$username -p$password emoncms > $export_file/temp/emoncms.sql
    if [ $? -ne 0 ]; then
        echo "Error: failed to export mysql data"
        echo "emoncms export failed"
        exit 1
    fi
else
    echo "Error: Cannot read MYSQL authentication details from Emoncms settings.php"
    rm -r $export_file/*
    exit 1
fi
echo "- Emoncms MYSQL database dump complete"
echo "- Adding Emoncms and Emonhub config files to: emoncms-backup-$date.tar"

# Create backup archive and add config files stripping out the path
tar -Prf $bkp_tar $export_file/temp/emoncms.sql $emonhub_conf $emoncms_set --transform 's?.*/??g' 2>&1
if [ $? -ne 0 ]; then
    echo "Error: failed to tar config data"
    echo "emoncms export failed"
    rm -r $export_file/*
    exit 1
fi

echo "- Adding Nodered files to: emoncms-backup-$date.tar"
mkdir $export_file/temp/nodered
cp $nodered_path/{flows_raspberrypi_cred.json,settings.js,flows_raspberrypi.json,package.json} $export_file/temp/nodered
tar -rf $bkp_tar -C $export_file/temp nodered 2>&1

if [ $? -ne 0 ]; then
    echo "Error: failed to tar nodered data"
    echo "emoncms export failed"
    rm -r $export_file/*
    exit 1
fi

# Compress backup
echo "- Compressing archive to gzip: emoncms-backup-$date.tar.gz"
echo " "
pv -fptb -s $(du -sb $bkp_tar | awk '{print $1}') $bkp_tar 2> >( while read -N 1 c; do if [[ $c =~ $'\r' ]]; then sed -i "$ s/.*/  $pv_bar/g" $log; pv_bar=''; else pv_bar+="$c";  fi  done ) | gzip > $bkp_tar.gz
sleep 1
exec 1>>$log

if [ $? -ne 0 ]; then
    echo "Error: failed to compress tar file"
    echo "emoncms export failed"
    rm -r $backup_location/export/*
    exit 1
fi

echo "- Deleting temporary folder"
rm -r $backup_location/export/temp
rm $bkp_tar
sudo cp $backup_location/export/emoncms-backup-$date.tar.gz $backup_location2

duration=$SECONDS
echo "" 
echo "=========================================================================================" 
echo "    $(date)"  
echo "    Export time: $(($duration / 60)) min $(($duration % 60)) sec"
echo "    Backup saved: $backup_location2/emoncms-backup-$date.tar.gz" 
echo "    Size: $(( $( stat -c '%s' $backup_location2/emoncms-backup-$date.tar.gz ) / 1024 / 1024 )) MB" 
echo "    Export finished...refresh page to view download link" 
echo "============================ Emoncms export complete! ===================================" 
# The last line is identified in the interface to stop ongoing AJAX calls, please ammend in interface if changed here