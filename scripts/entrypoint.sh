#!/bin/sh

cat <<EOF
################################################################################

samba setup script

################################################################################

EOF

INITALIZED="/.initialized"

if [ ! -f "$INITALIZED" ]; then
  echo ">> CONTAINER: starting initialisation"

  if [ -z ${SAMBA_CONF_WORKGROUP+x} ]
  then
    SAMBA_CONF_WORKGROUP="WORKGROUP"
    echo ">> SAMBA CONFIG: no \$SAMBA_CONF_WORKGROUP set, using '$SAMBA_CONF_WORKGROUP'"
  fi

  if [ -z ${SAMBA_CONF_SERVER_STRING+x} ]
  then
    SAMBA_CONF_SERVER_STRING="file server"
    echo ">> SAMBA CONFIG: no \$SAMBA_CONF_SERVER_STRING set, using '$SAMBA_CONF_SERVER_STRING'"
  fi

  if [ -z ${SAMBA_CONF_MAP_TO_GUEST+x} ]
  then
    SAMBA_CONF_MAP_TO_GUEST="Bad User"
    echo ">> SAMBA CONFIG: no \$SAMBA_CONF_MAP_TO_GUEST set, using '$SAMBA_CONF_MAP_TO_GUEST'"
  fi

  ##
  # SAMBA Configuration
  ##
cat > /etc/smb.conf <<EOF
[global]
 server role = standalone server
 workgroup = $SAMBA_CONF_WORKGROUP
 server string = $SAMBA_CONF_SERVER_STRING
 map to guest = $SAMBA_CONF_MAP_TO_GUEST
 dns proxy = no
 log file = /dev/stdout
EOF

  ##
  # Apple's SMB2+ extension timemachine support activated
  ##
  if env | grep 'SAMBA_VOLUME_CONFIG_' | grep 'fruit:' 2> /dev/null >/dev/null
  then
    echo ">> SAMBA CONFIG: enabling Apple's SMB2+ extentions"
cat >> /etc/smb.conf <<EOF
 vfs objects = catia fruit streams_xattr
 fruit:aapl = yes
EOF
  fi

  ##
  # Global configuration
  ##
  if env | grep 'SAMBA_GLOBAL_CONFIG_' 2> /dev/null >/dev/null
  then
    echo "Global configuration environmental variables found. Adding them now."
  for G_CONF in "$(env | grep '^SAMBA_GLOBAL_CONFIG_')"
  do
    GCONF_CONF_VALUE=$(echo "$G_CONF" | sed 's/^[^=]*=//g')
    echo "$GCONF_CONF_VALUE" | sed 's/;/\n/g' >> /etc/smb.conf
  done
  fi

  ##
  # SAMBA Configuration (enable NTLMv1 passwords/auth)
  ##
  if [ ! -z ${SAMBA_CONF_ENABLE_NTLM_AUTH+x} ]
  then
    echo ">> SAMBA CONFIG: \$SAMBA_CONF_ENABLE_NTLM_AUTH is set, enabling ntlm auth"
cat >> /etc/smb.conf <<EOF
 ntlm auth = yes

EOF
  fi

  ##
  # SAMBA Configuration (Password Sync)
  ##
  if [ ! -z ${SAMBA_CONF_ENABLE_PASSWORD_SYNC+x} ]
  then
    echo ">> SAMBA CONFIG: \$SAMBA_CONF_ENABLE_PASSWORD_SYNC is set, enabling password sync"
cat >> /etc/smb.conf <<EOF
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes

EOF
  fi

  ##
  # USER ACCOUNTS
  ##
  echo "$(env | grep '^ACCOUNT_')" | while IFS= read -r I_ACCOUNT ; do
    ACCOUNT_NAME=$(echo "$I_ACCOUNT" | cut -d'=' -f1 | sed 's/ACCOUNT_//g' | sed -E 's/\_(.*)//g' | tr '[:upper:]' '[:lower:]')
    ACCOUNT_PASSWORD=$(echo "$I_ACCOUNT" | sed 's/^[^=]*=//g')
    ACCOUNT_UID=$(echo "$I_ACCOUNT" | cut -d'=' -f1 | sed -E 's/ACCOUNT_[^_]*_?//g')

    echo ">> ACCOUNT: adding account: $ACCOUNT_NAME"
    if [ -z "$ACCOUNT_UID" ]
    then
      echo -e "$ACCOUNT_PASSWORD\n$ACCOUNT_PASSWORD" | adduser -H -s /bin/false "$ACCOUNT_NAME"
    else
      echo -e "$ACCOUNT_PASSWORD\n$ACCOUNT_PASSWORD" | adduser -H -s /bin/false --uid $ACCOUNT_UID "$ACCOUNT_NAME"
    fi
      
    echo -e "$ACCOUNT_PASSWORD\n$ACCOUNT_PASSWORD" | smbpasswd -a "$ACCOUNT_NAME"
    smbpasswd -e "$ACCOUNT_NAME"

    unset $(echo "$I_ACCOUNT" | cut -d'=' -f1)
  done
  
  ##
  # GROUPS e.g. GROUP_randomdistinctvalue_GID=groupname
  ##
  if env | grep -q '^GROUP_'
  then
    echo "$(env | grep '^GROUP_')" | while IFS= read -r I_GROUP ; do
      GROUP_NAME=$(echo "$I_GROUP" | sed 's/^[^=]*=//g')
      GROUP_GID=$(echo "$I_GROUP" | cut -d'=' -f1 | sed -E 's/GROUP_[^_]*_?//g')
      
      echo ">> GROUP: adding group: $GROUP_NAME"
      if [ -z "$GROUP_GID" ]
      then
        addgroup "$GROUP_NAME"
      else
        addgroup --gid $GROUP_GID "$GROUP_NAME"
      fi
      
      unset $(echo "$I_GROUP" | cut -d'=' -f1)
    done
  else
    echo 'No groups added'
  fi
  
  ##
  # USER TO GROUPS e.g. U2G_user_a=group
  ##
  if env | grep -q '^U2G_'
  then
    echo "$(env | grep '^U2G_')" | while IFS= read -r I_U2G ; do
      ACCOUNT_NAME=$(echo "$I_U2G" | cut -d'=' -f1 | sed 's/U2G_//g' | sed -E 's/\_(.*)//g' | tr '[:upper:]' '[:lower:]')
      GROUP_NAME=$(echo "$I_U2G" | sed 's/^[^=]*=//g')
      
      echo ">> Adding $ACCOUNT_NAME to group $GROUP_NAME"
      
      adduser "$ACCOUNT_NAME" "$GROUP_NAME"
      
      unset $(echo "$I_U2G" | cut -d'=' -f1)
    done
  else
    echo 'No users added to additional groups'
  fi 

  ##
  # Samba Volume Config ENVs
  ##
  for I_CONF in "$(env | grep '^SAMBA_VOLUME_CONFIG_')"
  do
    CONF_CONF_VALUE=$(echo "$I_CONF" | sed 's/^[^=]*=//g')

    echo "$CONF_CONF_VALUE" | sed 's/;/\n/g' >> /etc/smb.conf
    echo "" >> /etc/smb.conf
  done

  cp /etc/smb.conf /etc/samba/smb.conf
  touch "$INITALIZED"
else
  echo ">> CONTAINER: already initialized - direct start of samba"
fi

##
# CMD
##
echo ">> CMD: exec docker CMD"
echo "$@"
exec "$@"
