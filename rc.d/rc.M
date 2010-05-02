#!/bin/sh
#
# rc.M		This file is executed by init(8) when the system is being
#		initialized for one of the "multi user" run levels (i.e.
#		levels 1 through 6).  It usually does mounting of file
#		systems et al.
#
# Version:	@(#)/etc/rc.d/rc.M	2.23	Wed Feb 26 19:20:58 PST 2003
#
# Author:	Fred N. van Kempen, <waltje@uwalt.nl.mugnet.org>
#		Heavily modified by Patrick Volkerding <volkerdi@slackware.com>
#
# Modified for Salix by: George Vlahavas <vlahavas~at~gmail~dot~com>

# modified for colorized screen messages and local needs
. /etc/shell-colors

# Tell the viewers what's going to happen.
echo
echo "${BOLDYELLOW}Going to multi user mode.${COLOR_RESET}"

# Screen blanks after 15 minutes idle time, and powers down in one hour
# if the kernel supports APM or ACPI power management:
/bin/setterm -blank 15 -powersave powerdown -powerdown 60

# Set the hostname.
if [ -r /etc/HOSTNAME ]; then
  /bin/hostname $(cat /etc/HOSTNAME | cut -f1 -d .)
else
  # fall back on this old default:
  echo "darkstar.example.net" > /etc/HOSTNAME
  /bin/hostname darkstar
fi

# Save the contents of 'dmesg':
/bin/dmesg -s 65536 > /var/log/dmesg

# Initialize PCMCIA devices:
#
# NOTE: This used to be started near the top of rc.S so that PCMCIA devices
# could be fsck'ed along with the other drives.  This had some unfortunate
# side effects, however, since root isn't yet read-write, and /var might not
# even be mounted the .pid files can't be correctly written in /var/run and
# the pcmcia system can't be correctly shut down.  If you want some PCMCIA
# partition to be mounted at boot (or when the card is inserted) then add
# the appropriate lines to /etc/pcmcia/scsi.opts.
#
# Note that the stuff in /etc/pcmcia/ is only for 2.4.x kernels using
# 16-bit PCMCIA cards (not 32-bit Cardbus cards!).  For example, with a
# wireless card you might need to set options in /etc/pcmcia OR in
# /etc/rc.d/rc.wireless.conf, or even in /etc/rc.d/rc.inet1.conf (with
# extra options if needed for the encryption key, ESSID, etc.)
#
# Hopefully this situation will be unified in the future, but for now
# that's how it is...
#
(
if [ -x /etc/rc.d/rc.pcmcia ]; then
  /bin/dash /etc/rc.d/rc.pcmcia start
  # The cards might need a little extra time here to initialize.
  sleep 5
fi
) &

# Start the system logger.
if [ -x /etc/rc.d/rc.syslog -a -x /usr/sbin/syslogd -a -d /var/log ]; then
  /bin/dash /etc/rc.d/rc.syslog start
fi

# If we are returning from single-user mode we will need to restart
# udevd on systems that use udev:
if grep -wq sysfs /proc/mounts && grep -q tmpfs /proc/filesystems ; then
  if ! grep -wq nohotplug /proc/cmdline ; then
    if [ -x /etc/rc.d/rc.udev ]; then
      /bin/bash /etc/rc.d/rc.udev start
    fi
  fi
fi

# Initialize the networking hardware.
if [ -x /etc/rc.d/rc.inet1 ]; then
  /bin/bash /etc/rc.d/rc.inet1
fi

# Look for additional USB/SCSI/IEEE1394/etc devices on multiple LUNs:
if [ -x /etc/rc.d/rc.scanluns ]; then
  /bin/bash /etc/rc.d/rc.scanluns
fi

# Start networking daemons:
if [ -x /etc/rc.d/rc.inet2 ]; then
  /bin/bash /etc/rc.d/rc.inet2
fi

# Mount any additional filesystem types that haven't already been mounted:
mount -a -v 2> /dev/null | grep -v "already mounted"

# Start the Network Time Protocol daemon:
if [ -x /etc/rc.d/rc.ntpd ]; then
  /bin/dash /etc/rc.d/rc.ntpd start
fi

# Remove stale locks and junk files (must be done after mount -a!)
/bin/rm -f /var/lock/* /var/spool/uucp/LCK..* /tmp/.X*lock /tmp/core /core 2> /dev/null

# Remove stale hunt sockets so the game can start.
if [ -r /tmp/hunt -o -r /tmp/hunt.stats ]; then
  echo "${BOLDWHITE}Removing stale hunt sockets from /tmp.${COLOR_RESET}"
  /bin/rm -f /tmp/hunt*
fi

# Ensure basic filesystem permissions sanity.
chmod 755 / 2> /dev/null
chmod 1777 /tmp /var/tmp

# Start APM or ACPI daemon.
# If APM is enabled in the kernel, start apmd:
if [ -e /proc/apm ]; then
  if [ -x /usr/sbin/apmd ]; then
    echo "${BOLDWHITE}Starting APM daemon:${COLOR_RESET}  /usr/sbin/apmd"
    /usr/sbin/apmd
  fi
elif [ -x /etc/rc.d/rc.acpid ]; then # otherwise, start acpid:
  /bin/dash /etc/rc.d/rc.acpid start
fi

# Start D-Bus:
if [ -x /etc/rc.d/rc.messagebus ]; then
  /bin/bash /etc/rc.d/rc.messagebus start
fi

# Start HAL:
if [ -x /etc/rc.d/rc.hald ]; then
  /bin/dash /etc/rc.d/rc.hald start
fi

# Start Bluetooth:
if [ -x /etc/rc.d/rc.bluetooth ]; then
  /bin/dash /etc/rc.d/rc.bluetooth start
fi

# Start wicd:
if [ -x /etc/rc.d/rc.wicd ]; then
  /bin/dash /etc/rc.d/rc.wicd start
fi

# Start dnsmasq, a simple DHCP/DNS server:
if [ -x /etc/rc.d/rc.dnsmasq ]; then
  /bin/dash /etc/rc.d/rc.dnsmasq start
fi

# Start snmpd:
if [ -x /etc/rc.d/rc.snmpd ]; then
  /bin/dash /etc/rc.d/rc.snmpd start
fi

# Start the print spooling system.  This will usually be LPRng (lpd) or CUPS.
if [ -x /etc/rc.d/rc.cups ]; then
  # Start CUPS:
  /bin/bash /etc/rc.d/rc.cups start
elif [ -x /etc/rc.d/rc.lprng ]; then
  # Start LPRng (lpd):
  /bin/bash /etc/rc.d/rc.lprng start
fi

# Start netatalk. (a file/print server for Macs using Appletalk)
if [ -x /etc/rc.d/rc.atalk ]; then
  /bin/dash /etc/rc.d/rc.atalk
fi

# Start smartd, which monitors the status of S.M.A.R.T. compatible
# hard drives and reports any problems.  Note some devices (which aren't
# smart, I guess ;) will hang if probed by smartd, so it's commented out
# by default.
#if [ -x /usr/sbin/smartd ]; then
#  /usr/sbin/smartd
#fi

# If we're using udev, make /dev/cdrom and any other optical drive symlinks
# if some udev rule hasn't made them already:
if grep -wq sysfs /proc/mounts && grep -q tmpfs /proc/filesystems; then
  if ! grep -wq nohotplug /proc/cmdline ; then
    if [ -x /lib/udev/rc.optical-symlinks -a -x /etc/rc.d/rc.udev ]; then
      /bin/dash /lib/udev/rc.optical-symlinks
    fi
  fi
fi

# Monitor the UPS with genpowerd.
# To use this, uncomment this section and edit your settings in
# /etc/genpowerd.conf (serial device, UPS type, etc).  For more information,
# see "man genpowerd" or the extensive documentation in the
# /usr/doc/genpower-*/ directory.
# You'll also need to configure a similar block in /etc/rc.d/rc.6 if you want
# support for stopping the UPS's inverter after the machine halts.
#if [ -x /sbin/genpowerd ]; then
#  echo "${BOLDWHITE}Starting genpowerd daemon.${COLOR_RESET}"
#  /sbin/genpowerd
#fi

# Turn on process accounting.  To enable process accounting, make sure the
# option for BSD process accounting is enabled in your kernel, and then
# create the file /var/log/pacct (touch /var/log/pacct).  By default, process
# accounting is not enabled (since /var/log/pacct does not exist).  This is
# because the log file can get VERY large.
if [ -x /sbin/accton -a -r /var/log/pacct ]; then
  chmod 640 /var/log/pacct
  /sbin/accton /var/log/pacct
fi

# Start crond (Dillon's crond):
# If you want cron to actually log activity to /var/log/cron, then change
# -l10 to -l8 to increase the logging level.
if [ -x /usr/sbin/crond ]; then
  echo "${BOLDWHITE}Starting the cron scheduling daemon:${COLOR_RESET}"
  /usr/sbin/crond -l10 >>/var/log/cron 2>&1
fi

# Start atd (manages jobs scheduled with 'at'):
if [ -x /usr/sbin/atd ]; then
  echo "${BOLDWHITE}Starting the at scheduling daemon:${COLOR_RESET}"
  /usr/sbin/atd -b 15 -l 1
fi

# Slackware-Mini-Quota-HOWTO:
# To really activate quotas, you'll need to add 'usrquota' and/or 'grpquota' to
# the appropriate partitions as listed in /etc/fstab.  Here's an example:
#
# /dev/hda2      /home      ext3     defaults,usrquota      1   1
#
# You'll then need to setup initial quota files at the top of the partitions
# to support quota, like this:
# touch /home/aquota.user /home/aquota.group
# chmod 600 /home/aquota.user /home/aquota.group
#
# Then, reboot to activate the system.
# To edit user quotas, use 'edquota'.  See 'man edquota'.  Also, the
# official Quota Mini-HOWTO has lots of useful information.  That can be found
# here:  /usr/doc/Linux-HOWTOs/Quota

# Check quotas and then turn quota system on:
if grep -q quota /etc/fstab ; then
  for quotafs in $(awk '/quota/ {print $2}' /etc/fstab) ; do
    /bin/rm -f $quotafs/{a,}quota.{group,user}.new
  done
  if [ -x /sbin/quotacheck ]; then
    echo "${BOLDCYAN}Checking filesystem quotas:${COLOR_RESET}  /sbin/quotacheck -avugm"
    /sbin/quotacheck -avugm
  fi
  if [ -x /sbin/quotaon ]; then
    echo "${BOLDCYAN}Activating filesystem quotas:${COLOR_RESET}  /sbin/quotaon -avug"
    /sbin/quotaon -avug
  fi
fi

# Start the SASL authentication server.  This provides SASL
# authentication services for sendmail:
if [ -x /etc/rc.d/rc.saslauthd ]; then
  /bin/dash /etc/rc.d/rc.saslauthd start
fi

# Start the sendmail daemon:
if [ -x /etc/rc.d/rc.sendmail ]; then
  /bin/dash /etc/rc.d/rc.sendmail start
fi

# Load ALSA (sound) defaults:
if [ -x /etc/rc.d/rc.alsa ]; then
  . /etc/rc.d/rc.alsa
fi

# Load a custom keymap if the user has an rc.keymap script.
if [ -x /etc/rc.d/rc.keymap ]; then
  . /etc/rc.d/rc.keymap
fi

# Start the MySQL database:
if [ -x /etc/rc.d/rc.mysqld ]; then
  /bin/dash /etc/rc.d/rc.mysqld start
fi

# If there are SystemV init scripts for this runlevel, run them.
if [ -x /etc/rc.d/rc.sysvinit ]; then
  . /etc/rc.d/rc.sysvinit
fi

# Start all other rc files not listed in here
if [ -x /etc/rc.d/rc.services ]; then
	python /etc/rc.d/rc.services
fi

# Start numlockx if it's activated.
if [ -x /etc/rc.d/rc.numlock ]; then
  /bin/dash /etc/rc.d/rc.numlock start
fi

# Load a custom screen font if the user has an rc.font script.
if [ -x /etc/rc.d/rc.font ]; then
  . /etc/rc.d/rc.font
fi

# We need to wait 25 secs and try to mount everything not mounted
# already for networks shares, as network connections might not have
# established properly yet.
sleep 25 && {
	mount -a -v 2> /dev/null | grep -v "already mounted"
	/bin/rm -f /var/lock/* /var/spool/uucp/LCK..* /tmp/.X*lock /tmp/core /core 2> /dev/null
} &

# Start the local setup procedure.
if [ -x /etc/rc.d/rc.local ]; then
  . /etc/rc.d/rc.local
fi

# All done.
