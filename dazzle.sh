#!/usr/bin/env bash

# This program is free software. It comes without any warranty, to
# the extent permitted by applicable law. You can redistribute it
# and/or modify it under the terms of the Do What The Fuck You Want
# To Public License, Version 2, as published by Sam Hocevar. See
# http://sam.zoy.org/wtfpl/COPYING for more details.

# Check if we're root, if not show a warning
if [[ $UID -ne 0 ]]; then
  case $1 in
    help)
      # You should be allowed to check the help without root
      ;;
    *)
      echo "Sorry, but Dazzle needs to be run as root"
      exit 1
    ;;
  esac
fi
  
# Define text styles
BOLD=`tput bold`
DIM=`tput dim`
NORMAL=`tput sgr0`


function create_account {
  echo "${BOLD}(1/4) Creating account \"storage\"...${NORMAL}"
  
  if [ `grep "^storage:" /etc/passwd | cut -b -7` = "storage" ]; then
    echo " -> Account already exists."
  else
    echo "${DIM} -> useradd storage --create-home --user-group${NORMAL}"
    useradd storage --create-home --user-group
  fi
  
  sleep 0.5
}

function configure_ssh {
  echo "${BOLD}(2/4) Configuring account \"storage\"...${NORMAL}"
  
  echo "${DIM} -> mkdir /home/storage/.ssh${NORMAL}"
  mkdir -p /home/storage/.ssh
  
  echo "${DIM} -> touch /home/storage/.ssh/authorized_keys${NORMAL}"
  touch /home/storage/.ssh/authorized_keys

  echo "${DIM} -> chmod 700 /home/storage/.ssh${NORMAL}"
  chmod 700 /home/storage/.ssh
  
  echo "${DIM} -> chmod 600 /home/storage/.ssh/authorized_keys${NORMAL}"
  chmod 600 /home/storage/.ssh/authorized_keys

  CONFIG_CHECK=`grep "^# SparkleShare$" /etc/ssh/sshd_config`
  if ! [ "$CONFIG_CHECK" = "# SparkleShare" ]; then
    echo "" >> /etc/ssh/sshd_config
    echo "# SparkleShare" >> /etc/ssh/sshd_config
    echo "# Please do not edit the above comment as it's used as a check by Dazzle" >> /etc/ssh/sshd_config
    echo "Match User storage" >> /etc/ssh/sshd_config
    echo "    PasswordAuthentication no" >> /etc/ssh/sshd_config
  fi
  
  sleep 0.5
}

function restart_ssh {
  echo "${BOLD}(3/4) Restarting the SSH service...${NORMAL}"
  
  if [ -f "/etc/init.d/sshd" ]; then
    echo " -> /etc/init.d/sshd restart"
    /etc/init.d/sshd restart >/dev/null
  else
    echo " -> /etc/init.d/ssh restart"
    /etc/init.d/ssh restart >/dev/null
  fi
}

function install_git {
  echo "${BOLD}(4/4) Installing the Git package...${NORMAL}"

  if [ -f "/usr/bin/git" ]; then
    GIT_VERSION=`/usr/bin/git --version | cut -b 13-`
    echo " -> The Git package has already been installed (version $GIT_VERSION)."
  else 
    if [ -f "/usr/bin/yum" ]; then
      echo " -> yum -y install git"
      yum -y install git
    else
      echo " -> apt-get -y install git"
      apt-get -yq install git-core
    fi
  fi
}

function create_project {
  echo "${BOLD}Creating project \"$1\"...${NORMAL}"

  if [ -f "/home/storage/$1/HEAD" ]; then
    echo " -> Project \"$1\" already exists."
    echo
  else
    echo " -> git init --bare /home/storage/$1"
    git init --quiet --bare /home/storage/$1
    
    echo " -> chown -R storage:storage /home/storage"
    chown -R storage:storage /home/storage

    sleep 0.5

    echo 
    echo "${BOLD}Project \"$1\" was successfully created.${NORMAL}"
  fi

  IP=`curl --silent http://ifconfig.me/ip`
  PORT=`grep "^Port " /etc/ssh/sshd_config | cut -b 6-`

  echo "To link up a SparkleShare client, enter the following"
  echo "details into the ${BOLD}\"Add Hosted Project...\"${NORMAL} dialog: "
  echo 
  echo "      Address: ${BOLD}storage@$IP:$PORT${NORMAL}"
  echo "  Remote Path: ${BOLD}/home/storage/$1${NORMAL}"
  echo
  echo "To link up (more) computers, use the \"dazzle link\" command."
  echo
}

function link_client {
  echo "Paste the contents of ${BOLD}\"~/SparkleShare/Your Name's link code.txt\"${NORMAL}"
  echo "(found on the client) into the field below and press ${BOLD}<ENTER>${NORMAL}."
  echo 
  echo -n "${BOLD}Link code: ${NORMAL}"
  read LINK_CODE
  
  if [ ${#SHELL} > 256 ]; then
    echo $LINK_CODE >> /home/storage/.ssh/authorized_keys
    echo
    echo "${BOLD}The client with this link code can now access projects.${NORMAL}"
    echo Repeat this step to link more clients.
    echo
  else
    echo "${BOLD}Not a valid link code...${NORMAL}"
  fi
}

function show_help {
    echo "${BOLD}Dazzle, SparkleShare host setup script${NORMAL}"
    echo "This script needs to be run as root"
    echo
    echo "Usage: dazzle [COMMAND]"
    echo 
    echo "  setup                            configures this machine to serve as a SparkleShare host"
    echo "  create PROJECT_NAME              creates a SparkleShare project called PROJECT_NAME"
    echo "  create-encrypted PROJECT_NAME    creates an encrypted SparkleShare project"
    echo "  link                             links a SparkleShare client to this host by entering a link code"
    echo
}


# Parse the command line arguments
case $1 in
  setup)
    create_account
    configure_ssh
    restart_ssh
    install_git
    echo
    echo "${BOLD}Setup complete!${NORMAL}"
    echo "To create a new project, run \"dazzle create PROJECT_NAME\"."
    echo
    ;;
  create)
    create_project $2
    ;;
  create-encrypted)
    create_project $2-crypto
    ;;
  link)
    link_client $2
    ;;
  *|help)
    show_help
    ;;
esac
