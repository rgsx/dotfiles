#!/bin/bash

# Universal Hostname Change Script
#
NEW_HOSTNAME=$1

if [ -z "$NEW_HOSTNAME" ]; then
  echo "Usage: $0 <new-hostname>"
  exit 1
fi

echo "Changing hostname to: $NEW_HOSTNAME"

# macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
#  sudo scutil --set ComputerName "$NEW_HOSTNAME"
  sudo scutil --set HostName "$NEW_HOSTNAME"
 # sudo scutil --set LocalHostName "$NEW_HOSTNAME"
  dscacheutil -flushcache
  echo "Hostname updated on macOS."
# Linux
#elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
#  sudo hostnamectl set-hostname "$NEW_HOSTNAME"
#  sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
#  echo "Hostname updated on Linux."
else
  echo "Unsupported OS."
  exit 1
fi


