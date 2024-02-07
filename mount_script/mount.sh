#!/bin/bash
#set -x
#trap read debug

################################################
# Usage fn start                               #
################################################


usage () {
        echo -e "\nPlease run the script as follow: "
        echo -e "\n./$(basename $0) -r <Remote host ip> -u <Remote host username> -p <Remote host password>"
        echo " "        
        exit 1
}

################################################
# Usage fn end                                 #
################################################


###############################################
# User and Date Log fn start                  #
###############################################

log_fn () {

LOGFILE="/auto/GLIT/lab-support/scripts/mount_script/logs/log.txt"

echo "username is $(whoami)" >> $LOGFILE
date >> $LOGFILE

}

###############################################
# User and Date Log fn end                    #
###############################################


################################################
# Ping test fn start                           #
################################################

ping_check () {

if ping -c 3 $DES_IP > /dev/null 2>&1; then
 
 echo ""

else

 echo -e  "\nNo ping to $DES_IP if you need help please open a ticket to lab support."
 echo "exiting..."
 exit 1

fi

}

################################################
# Ping test fn end                             #
################################################  


################################################
# ssh test fn start                            #
################################################

ssh_check () {

connect_timeout=5       # Connection timeout
echo -e "\nChecking ssh access to: $DES_IP "

timeout $connect_timeout bash -c "</dev/tcp/$DES_IP/22" >/dev/null 2>&1
if [ $? == 0 ];then
    echo -e "\nMount fix progress has been started please allow ~5 MIN for the progress to be complete!!!"
    sleep 5
else

	echo -e "\nssh failed please make sure ssh service is running on $DES_IP"
	echo "Please verify your user name and password."
	echo "For more help please open a ticket to lab support."
	echo "exiting..."
	exit 1

fi

}

################################################
# ssh test fn end                              #
################################################


################################################
# Get Host site and OS info fn start           #
################################################

host_site_os () {

echo -e "\nChecking your host target version."

DES_OS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 $U_NAME@$DES_IP cat /etc/os-release | grep "ID=" | grep -v VERSION | head -1 | cut -d "=" -f2 | tr -d '"')
 
SITE=$(cat /.autodirect/LIT/SCRIPTS/DHCPD/list |grep -i $DES_IP | awk '{print $8}' | cut -d";" -f1 | head -1) >/dev/null 2>&1

if [ -z "$SITE" ]
then

sleep 10

SITE=$(cat /.autodirect/LIT/SCRIPTS/DHCPD/list |grep -i $DES_IP | awk '{print $8}' | cut -d";" -f1 | head -1) >/dev/null 2>&1

 if [ -z "$SITE" ]
 then
 
 sudo systemctl restart nis ypbind autofs rpcbind >/dev/null 2>&1
 
 sleep 10

 SITE=$(cat /.autodirect/LIT/SCRIPTS/DHCPD/list |grep -i $DES_IP | awk '{print $8}' | cut -d";" -f1 | head -1) >/dev/null 2>&1

  if [ -z "$SITE" ]
  then
  
  SITE=$(sshpass -p 3tango ssh -q -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=30 root@10.209.17.49 cat /.autodirect/LIT/SCRIPTS/DHCPD/list |grep -i $DES_IP | awk '{print $8}' | cut -d";" -f1 | head -1 )
 
  fi
 
 
 fi


fi

}

################################################
# Get Host site and  OS info fn end            #
################################################

################################################
# Fix mount fn start           #
################################################

fix_mnt() {

NIS_DOM=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo nisdomainname")
#echo $NIS_DOM


if [[ "$NIS_DOM" = "lab.mtl.com" ]]; then
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl enable nis.service ypbind.service rpcbind.service autofs.service" >/dev/null 2>&1
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl enable ypbind" >/dev/null 2>&1
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl restart nis ypbind rpcbind autofs nfs-utils nfs-common" >/dev/null 2>&1
    rh_mtl_mnt_link_set >/dev/null 2>&1
    
    echo -e "\n Mount has been fixed, exiting script..."
#    exit 
# Comment else statement by Dvir Gez following request by Shai Venter "error is wrong and confusing" 
#else
#    echo -e "\n Can't ssh to the server please contact from Lab-Support"
    
fi

}

################################################
# Fix mount fn end             #
################################################


################################################
# Set resolv.conf fn start                     #
################################################

chk_resolv () {

echo -e "\nChecking your host target DNS site setting."

    if [[ "$SITE" = "MTL" ]] || [[ "$SITE" = "mtl" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/mtl.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1
                
    elif [[ "$SITE" = "MTR" ]] || [[ "$SITE" = "mtr" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/mtr.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1
		
    elif [[ "$SITE" = "MTVR" ]] || [[ "$SITE" = "mtvr" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/mtvr.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1	

    elif [[ "$SITE" = "MTH" ]] || [[ "$SITE" = "mth" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/mth.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1

    elif [[ "$SITE" = "RDMZ" ]] || [[ "$SITE" = "rdmz" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/rdmz.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1
    
    elif [[ "$SITE" = "MTS" ]] || [[ "$SITE" = "mts" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/mts.resolv $U_NAME@$DES_IP:/etc/resolv.conf >/dev/null 2>&1    
	

    fi

}

################################################
# Set resolv.conf fn end                       #
################################################


################################################
# Debian Ubuntu BF2 check fn start             #
################################################

du_bf2_check () {

echo -e "\nCheckin if host target is BF2."

MLNX_R=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP test -f /etc/mlnx-release && echo "YES" || echo "NO") > /dev/null 2>&1

    if [[ "$MLNX_R" = "NO" ]]; then

        echo " "
        echo -e "\nNot BF2 continue"

    else
       
        ARM_BF2=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP cat /etc/os-release | grep "ID=" | grep -v VERSION | head -1 | cut -d "=" -f2) > /dev/null 2>&1
        echo -e "\nYour remote host OS is BF2, applying setting as needed."
    
        if [[ "$ARM_BF2" = "ubuntu" ]] || [[ "$ARM_BF2" = "debian" ]] && [[ "$SITE" = "MTL" ]]; then

            SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp/mounts_ubu.sh.bk >/dev/null 2>&1
            echo -e "\nCreating mount points and restarting services as needed."
			echo -e "\nPlease allow ~5 min for the process to be complete."
			
       
            SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh.bk" >/dev/null 2>&1
           
            echo -e "\nProgress has been completed successfully."
          #Comment exit by Dvir Gez in order to continue to other functions in the script 
          #  exit

        elif [[ "$ARM_BF2" = "ubuntu" ]] || [[ "$ARM_BF2" = "debian" ]] && [[ "$SITE" = "MTVR" ]]; then

            SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp/mounts_ubu.sh.bk >/dev/null 2>&1
            echo -e "\nCreating mount points and restarting services as needed."
    
            SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh.bk" >/dev/null 2>&1
    
            echo -e "\nProgress has been completed successfully."
			echo -e "\nPlease allow ~5 min for the process to be complete."
            
            #Comment exit by Dvir Gez in order to continue to other functions in the script
            #exit
		
		elif [[ "$ARM_BF2" = "ubuntu" ]] || [[ "$ARM_BF2" = "debian" ]] && [[ "$SITE" = "MTR" ]]; then

            SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp/mounts_ubu.sh.bk >/dev/null 2>&1
            echo -e "\nCreating mount points and restarting services as needed."
    
            SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh.bk" >/dev/null 2>&1
    
            echo -e "\nProgress has been completed successfully."
			echo -e "\nPlease allow ~5 min for the process to be complete."
            
            #Comment exit by Dvir Gez in order to continue to other functions in the script
            #exit 
        
        elif [[ "$ARM_BF2" = "ubuntu" ]] || [[ "$ARM_BF2" = "debian" ]] && [[ "$SITE" = "MTH" ]]; then

            SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp/mounts_ubu.sh.bk >/dev/null 2>&1
            echo -e "\nCreating mount points and restarting services as needed."
			echo -e "\nPlease allow ~5 min for the process to be complete."
    
            SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh.bk" >/dev/null 2>&1
    
            echo -e "\nProgress has been completed successfully."
            
            #Comment exit by Dvir Gez in order to continue to other functions in the script
            #exit
			
	    elif [[ "$ARM_BF2" = "ubuntu" ]] || [[ "$ARM_BF2" = "debian" ]] && [[ "$SITE" = "MTS" ]]; then

            SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp/mounts_ubu.sh.bk >/dev/null 2>&1
            echo -e "\nCreating mount points and restarting services as needed."
			echo -e "\nPlease allow ~5 min for the process to be complete."
    
            SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh.bk" >/dev/null 2>&1
    
            echo -e "\nProgress has been completed successfully."
            
            #Comment exit by Dvir Gez in order to continue to other functions in the script
            #exit

        fi

    fi 

}

################################################
# Debian Ubuntu BF2 check fn end               #
################################################


################################################
# CentOS BF2 check fn start                    #
################################################

c_bf2_chk () {

echo -e "\nCheckin if host target is BF2"

MLNX_R=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP test -f /etc/mlnx-release && echo "YES" || echo "NO")

    if [[ "$MLNX_R" = "NO" ]]; then

        echo -e "\nNot Bluefield, continue.."
        
    else
   
        echo -e "\nYour remote host OS is Bluefield, Applying setting as needed.."
        ARM_BF2=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP cat /etc/os-release | grep "ID=" | grep -v VERSION | head -1 | cut -d "=" -f2) > /dev/null 2>&1
        TMF_IP=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP cat /etc/sysconfig/network-scripts/ifcfg-tmfifo_net0 | grep IPADDR)

    if [[ "$ARM_BF2" = "centOS" ]] || [[ "$ARM_BF2" = "redhat" ]] || [[ "$ARM_BF2" = "rocky" ]] || [[ "$ARM_BF2" = "ol" ]] || [[ "$ARM_BF2" = "openEuler" ]] || [[ "$ARM_BF2" = "anolis" ]] ; then
         
         SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/tmfifo/centos_tmfifo $U_NAME@$DES_IP:/tmp/ifcfg-tmfifo_net0
         SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "echo $TMF_IP >> /tmp/ifcfg-tmfifo_net0"
         SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "cp /tmp/ifcfg-tmfifo_net0 /etc/sysconfig/network-scripts/ifcfg-tmfifo_net0" > /dev/null 2>&1
         echo -e "\nChecking your Bluefield ARM tmfifo ip setting!"
         echo -e "\nYour Bluefield ARM tmfifo_net0 ip is: $TMF_IP"
         
    fi
    doc_repo_remove
fi

#echo $MLNX_R
#echo $ARM_BF2
#echo $TMF_IP

}


################################################
# Set CentOS BF2 network fn end                #
################################################


################################################
# CentOS mount fix fn start                    #
################################################

cen_mnt_chk () {

echo -e "\nPlease wait checking for missing packages."

C_YP=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP rpm -qi ypbind | head -1 | awk '{print $3}') > /dev/null 2>&1
C_AUTOFS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP rpm -qi autofs | head -1 | awk '{print $3}') > /dev/null 2>&1
C_NFS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP rpm -qi nfs-utils | head -1 | awk '{print $3}') > /dev/null 2>&1

RH_Version9=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP  cat /etc/os-release |grep "VERSION_ID" |awk -F "=" '{print $2}' |tr -d "\"")

#    echo This is RH 9 Version: $RH_Version9 


    if [[ "$C_YP" != "ypbind" ]]; then

        SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP yum install -y -q ypbind > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable ypbind.service > /dev/null 2>&1

    else

        echo -e "\n$C_YP is installed skiping."
        SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable ypbind.service > /dev/null 2>&1

    fi    
 
    if [[ "$C_AUTOFS" != "autofs" ]]; then

       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP yum install -y -q autofs > /dev/null 2>&1
       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable autofs > /dev/null 2>&1

    else

       echo -e "\n$C_AUTOFS is installed skipping."
       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable autofs.service > /dev/null 2>&1
           
    fi

    if [[ "$C_NFS" != "nfs-utils" ]]; then 
    
       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP yum install -y -q nfs-utils > /dev/null 2>&1
       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable nfs > /dev/null 2>&1

    else  
 
       echo -e "\n$C_NFS is installed skipping."
       SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP systemctl enable nfs > /dev/null 2>&1

    fi
    

    if [ "$RH_Version9" = "9.0" ] || [ "$RH_Version9" = "9.1" ] || [ "$RH_Version9" = "9.2" ] || [ "$RH_Version9" = "9.3" ]
    then
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "yum remove -y autofs" > /dev/null 2>&1
    #SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "wget https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/36/Everything/x86_64/os/Packages/a/autofs-5.1.8-3.fc36.x86_64.rpm" > /dev/null 2>&1
     SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "https://rpmfind.net/linux/fedora/linux/updates/37/Everything/x86_64/Packages/a/autofs-5.1.8-20.fc37.x86_64.rpm" > /dev/null 2>&1
    #SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "wget https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/36/Everything/x86_64/os/Packages/n/nss_nis-3.1-11.fc36.x86_64.rpm" > /dev/null 2>&1
     SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "https://rpmfind.net/linux/fedora/linux/releases/37/Everything/x86_64/os/Packages/n/nss_nis-3.1-12.fc37.x86_64.rpm" > /dev/null 2>&1
    
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "rpm -ivh /root/autofs-5.1.8-20.fc37.x86_64.rpm" > /dev/null 2>&1
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "rpm -ivh /root/nss_nis-3.1-12.fc37.x86_64.rpm" > /dev/null 2>&1
    #SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "yum install -y https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/36/Everything/x86_64/os/Packages/y/yp-tools-4.2.3-12.fc36.x86_64.rpm https://download-ib01.fedoraproject.org/pub/fedora/linux/releases/36/Everything/x86_64/os/Packages/y/ypbind-2.7.2-8.fc36.x86_64.rpm" > /dev/null 2>&1
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "yum install -y https://ftp.us2.freshrpms.net/linux/fedora/linux/releases/37/Everything/x86_64/os/Packages/y/yp-tools-4.2.3-13.fc37.x86_64.rpm https://ftp.us2.freshrpms.net/linux/fedora/linux/releases/37/Everything/x86_64/os/Packages/y/ypbind-2.7.2-9.fc37.x86_64.rpm" > /dev/null 2>&1
    



    fi
    

rh_scp_mnt_files

}

################################################
# CentOS mount fix fn end                      #
################################################


################################################
# Debian mount fix fn start                    #
################################################

ub_deb_mnt_chk () {

echo -e "\nChecking for missing packages."

UD_SUDO=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "apt -qq list sudo | grep -o installed") > /dev/null 2>&1

if [[ "$UD_DEB_UTILS" != "installed" ]]; then

SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP apt-get install -qq sudo  > /dev/null 2>&1

fi

UD_DEB_UTILS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo apt -qq list debconf-utils | grep -o installed") > /dev/null 2>&1
UD_NIS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo apt -qq list nis | grep -o installed") > /dev/null 2>&1
UD_AUTOFS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo apt -qq list autofs | grep -o installed") > /dev/null 2>&1
UD_NFS=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo apt -qq list nfs-common | grep -o installed") > /dev/null 2>&1


if [[ "$UD_DEB_UTILS" != "installed" ]]; then
        
 echo -e "\nInstalling debconf-utils please wait, this proccess may take about 2 min or more..."        
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo mv /etc/yp.conf /etc/yp.conf.orig" > /dev/null 2>&1
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq debconf-utils < /dev/null > /dev/null"
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo echo 'nis nis/domain string lab.mtl.com' > /tmp/nis" >/dev/null 2>&1
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo debconf-set-selections /tmp/nis" > /dev/null 2>&1

else

 echo -e "\ndebconf-utils is installed skiping."

fi

if [[ "$UD_NIS" != "installed" ]]; then

 echo -e "\nInstalling nis please wait, this proccess may take about 3 min or more..."
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq nis < /dev/null > /dev/null"

else

 echo -e "\nnis is installed skiping."
 echo "I will try to check other setting please wait..."
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo echo lab.mtl.com > /etc/defaultdomain" > /dev/null 2>&1

fi

if [[ "$UD_AUTOFS" != "installed" ]]; then

 echo -e "\nInstalling autofs please wait, this process may take about 1 min or more..."
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq autofs < /dev/null > /dev/null"

else

echo -e "\nautofs is installed skipping."
echo "I will try to check other setting please wait..."

fi
    
if [[ "$UD_NFS" != "installed" ]]; then
 
 echo -e "\nInstalling nfs please wait, this process may take about 1 min or more..."
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo DEBIAN_FRONTEND=noninteractive apt-get install -qq nfs-common < /dev/null > /dev/null"

else

 echo -e "\nfs-common is installed skipping."
 echo "I will try to check other setting please wait..."

fi


}

################################################
# Debian mount fix fn end                      #
################################################


################################################
# Sles mount fix fn start                      #
################################################

sles_mnt_chk () {

echo -e "Checking for missing packages."

S_YP=$(SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP rpm -qi ypbind rpm -qi ypbind | head -1 | awk '{print $3}') > /dev/null 2>&1
S_AUTOFS=$(SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP rpm -qi autofs | head -1 | awk '{print $3}') > /dev/null 2>&1
S_NFS=$(SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP rpm -qi nfs-client | head -1 | awk '{print $3}') > /dev/null 2>&1

if [[ "$S_YP" != "ypbind" ]]; then

        SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP zypper -n install ypbind
        SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable ypbind.service > /dev/null 2>&1

    else

        echo -e "\n$S_YP is installed skiping."
        SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable ypbind.service > /dev/null 2>&1

    fi

    if [[ "$S_AUTOFS" != "autofs" ]]; then

       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP zypper -n install autofs > /dev/null 2>&1
       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable autofs > /dev/null 2>&1

    else

       echo -e "\n$S_AUTOFS is installed skipping."
       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable autofs.service > /dev/null 2>&1

    fi

    if [[ "$S_NFS" != "nfs-client" ]]; then

       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP yum -n nfs-client > /dev/null 2>&1
       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable nfs > /dev/null 2>&1

    else

       echo -e "\n$S_NFS is installed skipping."
       SSHPASS=$PASS sshpass -e ssh -q $U_NAME@$DES_IP systemctl enable nfs > /dev/null 2>&1

    fi

}

################################################
# Sles mount fix fn end                        #
################################################


################################################
# Copy RH mount files per site fn start        #
################################################

rh_scp_mnt_files () {


    if [[ "$SITE" = "MTL" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/rh_mtl_yp.conf $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1
		
    elif [[ "$SITE" = "MTVR" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/rh_mtvr_yp.conf $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1	
		
    elif [[ "$SITE" = "MTR" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/rh_mtr_yp.conf $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1

    elif [[ "$SITE" = "MTH" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/rh_mth_yp.conf $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1

    elif [[ "$SITE" = "RDMZ" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/rdmz.yp $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1    
   
    elif [[ "$SITE" = "MTS" ]]; then
        rh_mtl_mnt_link_set
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/rh_mts_yp.conf $U_NAME@$DES_IP:/etc/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/nsswitch.conf $U_NAME@$DES_IP:/etc/nsswitch.conf > /dev/null 2>&1    
    fi
        
}

################################################
# Copy RH mount files per site fn end          #
################################################


################################################
# Copy DEB_UBU mount files per site fn start   #
################################################

du_scp_mnt_files () {

    
if [[ "$SITE" = "MTL" ]] || [[ "$SITE" = "mtl" ]]; then
       
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/du_mtl_yp.conf $U_NAME@$DES_IP:/tmp/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/du_nsswitch.conf $U_NAME@$DES_IP:/tmp/nsswitch.conf > /dev/null 2>&1
        
elif [[ "$SITE" = "MTVR" ]] || [[ "$SITE" = "mtvr" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/rh_mtvr_yp.conf $U_NAME@$DES_IP:/tmp/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/nsswitch.conf $U_NAME@$DES_IP:/tmp/nsswitch.conf > /dev/null 2>&1
	
elif [[ "$SITE" = "MTR" ]] || [[ "$SITE" = "mtr" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/rh_mtr_yp.conf $U_NAME@$DES_IP:/tmp/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/nsswitch.conf $U_NAME@$DES_IP:/tmp/nsswitch.conf > /dev/null 2>&1

elif [[ "$SITE" = "MTH" ]] || [[ "$SITE" = "mth" ]]; then

        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/rh_mth_yp.conf $U_NAME@$DES_IP:/tmp/yp.conf > /dev/null 2>&1
        SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/nsswitch.conf $U_NAME@$DES_IP:/tmp/nsswitch.conf > /dev/null 2>&1

fi

}


################################################
# Copy DEB_UBU mount files per site fn end     #
################################################


################################################
# CentOS link mount set fn start               #
################################################

rh_mtl_mnt_link_set () {

echo -e "\nCreating Network Mounts Links and Restarting Services.."

MSWG=$(echo "ln -s /.autodirect/mswg /mswg")
MSWG2=$(echo "ln -s /.autodirect/mswg2 /mswg2")
SWGWORK=$(echo "ln -s /.autodirect/swgwork /swgwork")
ADVG=$(echo "ln -s /.autodirect/advg /advg")
SVHOME=$(echo "ln -s /.autodirect/svhome /svhome")
FWGWORK=$(echo "ln -s /.autodirect/fwgwork /fwgwork")
QA=$(echo "ln -s /.autodirect/QA /QA")
MTRSWG=$(echo "ln -s /.autodirect/mtrswgwork /mtrswgwork")

SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "$MSWG; $MSWG2; $SWGWORK; $ADVG; $SVHOME; $FWGWORK; $QA " > /dev/null 2>&1

rh_srv_restart

echo -e "\nProgress has been Completed Successfully."

}

################################################
# CentOS link mount set fn end                 #
################################################


################################################
# US Site CentOS link mount set fn start       #
################################################

rh_us_mnt_link_set () {

echo -e "\nCreating mount points and restarting services as needed."

MSWG=$(echo "ln -s /.autodirect/mswg /mswg")
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "$MSWG" > /dev/null 2>&1

rh_srv_restart

echo -e "\nProgress has been completed successfully."

}

################################################
# US Site CentOS link mount set fn end         #
################################################



################################################
# Deb + Ubu link mount set fn start            #
################################################

du_mtl_mnt_link_set () {

echo -e "\nCreating Mount Points and Restarting Services, Please Wait.."

if [[ "$SITE" = "MTL" ]] || [[ "$SITE" = "mtl" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1


elif [[ "$SITE" = "MTR" ]] || [[ "$SITE" = "mtr" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtr/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

elif [[ "$SITE" = "MTVR" ]] || [[ "$SITE" = "mtvr" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtvr/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1


elif [[ "$SITE" = "MTH" ]] || [[ "$SITE" = "mth" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mth/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

elif [[ "$SITE" = "RDMZ" ]] || [[ "$SITE" = "rdmz" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/rdmz/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

elif [[ "$SITE" = "MTS" ]] || [[ "$SITE" = "mts" ]]; then

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

fi


#SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
#SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

echo -e "\nProgress has been completed successfully."

}

################################################
# Deb + Ubu link mount set fn end              #
################################################


################################################
# Deb + Ubu MTS link mount set fn start        #
################################################

du_mts_mnt_link_set () {

echo -e "\nPlease wait few min creating mount points and restarting services as needed."

SSHPASS=$PASS sshpass -e scp -q -o StrictHostKeyChecking=no /auto/GLIT/lab-support/scripts/mount_script/mts/ubuntu/mounts_ubu.sh $U_NAME@$DES_IP:/tmp >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo bash /tmp/mounts_ubu.sh" >/dev/null 2>&1

echo -e "\nProgress has been completed successfully."

}

################################################
# Deb + Ubu MTS link mount set fn end              #
################################################


################################################
# RH services restart fn start                 #
################################################

rh_srv_restart () {

echo -e "\nRestarting services"
#To cover Ubuntu \ Debian - added NIS service :
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "systemctl restart nis" >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "systemctl restart ypbind autofs rpcbind nfs-utils" >/dev/null 2>&1

}

################################################
# RH services restart fn end                   #
################################################


################################################
# DEB_UBU services restart fn start            #
################################################

du_srv_restart () {

echo -e "\nRestarting services"
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl enable ypbind.service rpcbind.service autofs.service nis.service" >/dev/null 2>&1
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl enable ypbind"
SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo systemctl restart nis.service ypbind.service autofs.service rpcbind.service" >/dev/null 2>&1

#For debian issue with startup of ypbind
ypbindstatus=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "systemctl status ypbind |grep Loaded |awk '{print \$4}' |tr -d ';' ")

 if [ "$ypbindstatus" == "disabled" ]
 then
 
 SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "systemctl enable ypbind"

 ypbindstatus=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "systemctl status ypbind |grep Loaded |awk '{print \$4}' |tr -d ';' ")

 echo "ypbind startup status:" $ypbindstatus
 
 fi


}

################################################
# DEB_UBU services restart fn end              #
################################################

################################################
# BF2 root pass reset fn start                 #
################################################
 
bf2_pass () {

echo -e "\nChecking if $DES_IP is BF2 and resseting root password to company standard as needed!"
MLNX_R=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP ls -l /etc/ | grep -o mlnx-release) > /dev/null 2>&1

    if [[ "$MLNX_R" != "mlnx-release" ]]; then

        echo " "

    else

        SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo echo 'root:3tango' | chpasswd" >/dev/null 2>&1       
        echo -e "\n***Server $DES_IP is BF2 root account password has been reset***"
        echo " "
 
    fi

}

################################################
# BF2 root pass reset fn end                   #
################################################


################################################
# Ssh key remove fn start                      #
################################################


rm_ssh_key () {

ssh-keygen -R "$DES_IP" > /dev/null 2>&1

}

################################################
# Ssh key remove fn end                        #
################################################

################################################
# Reset BF2 ubuntu pass fn start               #
################################################

ubu_pass () {

if [[ "$U_NAME" = "ubuntu" ]]; then

    #echo "ubuntu BFB user is $U_NAME"
    EXP=$(rpm -qi expect | head -1 | awk '{print $3}')

        if [[ "$EXP" != "expect" ]]; then

           sudo yum install -y -q expect
    
        else

           /usr/bin/expect -f /auto/GLIT/lab-support/scripts/mount_script/mtl/ubuntu/upass2.sh ubuntu ubuntu $DES_IP 3tango11! >/dev/null 2>&1
    
        fi

fi

}

################################################
# Reset BF2 ubuntu pass fn end                 #
################################################


#/.autodirect/QA/venters/scripts/smartnic/add-rclocal-rpyc-arm

################################################
# Remove Docker repo for CentOS BFB fn start   #
################################################

doc_repo_remove () {

DOCK_REPO=$(SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP ls -l /etc/yum.repos.d/ | grep docker | awk '{print $9}' | cut -d "-" -f1)
#echo $DOCK_REPO

  if [[ "$DOCK_REPO" = "docker" ]]; then
    
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo mkdir /etc/yum.repos.d/old"
    SSHPASS=$PASS sshpass -e ssh -q -o StrictHostKeyChecking=no $U_NAME@$DES_IP "sudo mv /etc/yum.repos.d/docker* /etc/yum.repos.d/old"
    
  fi  

}


################################################
# Remove Docker repo for CentOS BFB fn end     #
################################################

################################################
#  SGH Site server list check fn start         #
################################################



sgh_site_server_check () {


SGH_SRV_IP=$(cat /auto/GLIT/lab-support/scripts/mount_script/sgh/dhcpd_list_sh |grep -i "${DES_IP};" | awk '{print $1}' | cut -d";" -f1 | head -1) >/dev/null 2>&1

if [ $SGH_SRV_IP ]; then
  
  echo -e "\n$SGH_SRV_IP found in servers list, Running mount_sh.sh Script"
  bash /auto/GLIT/lab-support/scripts/mount_script/sgh/mount_sh.sh -r $DES_IP -u $U_NAME -p $PASS
  exit

fi

}

################################################
# SGH Site server list check fn end            #
################################################



################################################
# Script start here                            #
################################################


# if no input argument found, exit the script with usage
if [[ ${#} -lt 6 ]]; then
   usage
fi


while getopts r:u:p:h arg; do
  case "${arg}" in
    h) usage ;;
    r) DES_IP=$OPTARG ;;
    u) U_NAME=$OPTARG ;;
    p) PASS=$OPTARG ;;

    *)
    
      usage
      exit 2
      ;;
  esac
done

[ -z "$DES_IP" ] && { echo -e "-E- No target hostname given.\n" >&2; usage >&2; exit 3; }
[ -z "$U_NAME" ] && { echo -e "-E- No User name is given.\n" >&2; usage >&2; exit 3; }
[ -z "$PASS" ] && { echo -e "-E- No Password given.\n" >&2; usage >&2; exit 3; }

log_fn

# sgh site servers check - calling for mount_sh.sh if server found in servers list file
sgh_site_server_check
#


### Checking if user is ubuntu and resseting password as needed" ###

if [[ "$U_NAME" = "ubuntu" ]] && [[ "$PASS" = "ubuntu" ]] ; then
	echo "Mandatory change of default Ubuntu user is required in this run"
	ubu_pass
	PASS="3tango11!"
        #added by dvir in order to fix copy resolve.conf issue while running the script chk_resolv func using wrong password for bf2
        host_site_os
        chk_resolv

fi

ping_check
ssh_check
fix_mnt

### Check os version ###

rm_ssh_key
host_site_os
chk_resolv


if [[ -z "$DES_OS" ]]; then

    echo "Can't get OS info, please first ssh to the server and then try again"
    echo -e "\n If you need extra support please contact from Lab-Support"
	
elif [[ "$SITE" = "MTS" ]] && [[ "$DES_OS" = "centos" ]] || [[ "$SITE" = "MTS" ]] && [[ "$DES_OS" = "rhel" ]]; then
    
    c_bf2_chk
    cen_mnt_chk
    rh_scp_mnt_files
    rh_us_mnt_link_set
    bf2_pass

elif [[ "$SITE" = "MTS" ]] && [[ "$DES_OS" = "debian" ]] && [[ "$DES_OS" = "cumulus-linux" ]]; then

    du_bf2_check
    ub_deb_mnt_chk
    du_mts_mnt_link_set
    bf2_pass

elif [[ "$DES_OS" = "centos" ]] || [[ "$DES_OS" = "rhel" ]] || [[ "$DES_OS" = "rocky" ]] || [[ "$DES_OS" = "openEuler" ]] || [[ "$DES_OS" = "anolis" ]] || [[ "$DES_OS" = "alinux" ]]; then
    
    c_bf2_chk
    cen_mnt_chk
    rh_scp_mnt_files
    rh_mtl_mnt_link_set
    bf2_pass

elif [[ "$DES_OS" = "fedora" ]] || [[ "$DES_OS" = "ol" ]]; then

    c_bf2_chk
    cen_mnt_chk
    #rh_scp_mnt_files - function is called from above fn -> cen_mnt_chk
    rh_mtl_mnt_link_set       
    bf2_pass

elif [[ "$DES_OS" = "debian" ]] || [[ "$DES_OS" = "cumulus-linux" ]]; then
   
    du_bf2_check
    ub_deb_mnt_chk
    #du_scp_mnt_files
    du_mtl_mnt_link_set
    du_srv_restart
    bf2_pass

elif [[ "$DES_OS" = "ubuntu" ]]; then
    
    du_bf2_check
    ub_deb_mnt_chk
    #du_scp_mnt_files
    du_mtl_mnt_link_set
    du_srv_restart
    bf2_pass
    
elif [[ "$DES_OS" = "sles" ]]; then 

    sles_mnt_chk
    rh_mtl_mnt_link_set
    bf2_pass 

fi

################################################
# fn used in the middle of the code as needed  #
################################################
#
#
#
# rh_scp_mnt_files
# rh_srv_restart
# deb_lock_release
# tmfifo_fix
#
#
#
################################################
# Script end here                              #
################################################
