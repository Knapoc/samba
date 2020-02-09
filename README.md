
# samba
Dockerized samba running in Alpine:latest

# Source Code
Check the following link for a new version: https://download.samba.org/pub/samba/stable/

**credit to https://github.com/MarvAmBass for the initial project.**

## Environment variables and defaults

The samba server can be configured with the following environmental variables.


**Accounts & Groups**  

`-e "ACCOUNT_username_uid=password"`
 - used for account creation
 - multiple variables/accounts possible
 - adds a new user account with the given username and the env value as password
 - optional UID support
 - Examples:  
`-e "ACCOUNT_alice=abcdefg"`  
`-e "ACCOUNT_bob_1009=123456"`  

To restrict access of volumes you can add the following to your samba volume config:  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;`valid users = alice; invalid users = bob;`

`-e "GROUP_distinctvalue_gid=groupname"`
 - used for group creation (optional)
 - multiple variables/groups possible
 - adds a new group with the env value as group name
 - optional GID support
 - Examples:  
`-e "GROUP_a=samba"`  
`-e "GROUP_b_1010=filegroup"`  

`-e "U2G_user_distinctvalue=group"`
 - used to assign users to groups (optional)
 - multiple variables possible
 - adds the given user to a group, which is defined in the env value
 - Examples:  
 `-e "U2G_alice_a=samba`  
 `-e "U2G_alice_b=filegroup`  
 `-e "U2G_bob_a=samba`  

**Main server configuration**  
Workgroup: `-e "SAMBA_CONF_WORKGROUP=name"`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;default: *WORKGROUP*  
Server string: `-e "SAMBA_CONF_SERVER_STRING=file server"`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;default: *file server*  
Map to guest: `-e SAMBA_CONF_MAP_TO_GUEST=Bad User`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;default: *Bad User*  
Password sync: `-e "SAMBA_CONF_ENABLE_PASSWORD_SYNC"`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;default: *not set* - if set password sync is enabled  
NTLM auth: `-e "SAMBA_CONF_ENABLE_NTLM_AUTH"`  
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;default: *not set* - if set password sync is enabled  

**Additional global configuration**  
`SAMBA_GLOBAL_CONFIG_myconfigname`  
* adds additional global configuration  
* multiple variables/confgurations possible by adding unique configname to SAMBA_GLOBAL_CONFIG_  
* Examples  
`-e "SAMBA_GLOBAL_CONFIG_var1= min protocol = SMB2; fruit:metadata = stream"`  
`-e "SAMBA_GLOBAL_CONFIG_var2= fruit:nfs_aces = no"`  

**Volume configuration**  
`SAMBA_VOLUME_CONFIG_myconfigname`  
* adds a new samba volume configuration  
* multiple variables/confgurations possible by adding unique configname to SAMBA_VOLUME_CONFIG_  
 * Examples  
`-e "SAMBA_VOLUME_CONFIG_volumea=[My Share]; path=/shares/myshare; guest ok = no; read only = no; browseable = yes"`  
`-e "SAMBA_VOLUME_CONFIG_volumeb=[Guest Share]; path=/shares/guests; guest ok = yes; read only = no; browseable = yes"`  

# Apple TimeMachine

To enable TimeMachine Support add this to your `SAMBA_VOLUME_CONFIG`: `vfs objects = catia fruit streams_xattr; fruit:time machine = yes;`

You can also limit the size available for timemachine by also adding `fruit:time machine max size = 500G;` (format: `SIZE [K|M|G|T|P]
`)

**Note**: As soon as a share is defined with a `fruit`-option, the following settings are defined within the global section:
* `fruit:aapl = yes`
* `vfs objects = catia fruit streams_xattr`

More infos about the Apple Extensions: https://www.samba.org/samba/docs/current/man-html/vfs_fruit.8.html and https://wiki.samba.org/index.php/Configure_Samba_to_Work_Better_with_Mac_OS_X

# Links
* https://wiki.samba.org/index.php/Samba_AD_DC_Port_Usage
* https://wiki.samba.org/index.php/Setting_up_Samba_as_a_Standalone_Server
* https://www.samba.org/samba/docs/man/manpages-3/smb.conf.5.html


# Avahi / Zeroconf

## Infos:

* https://linux.die.net/man/5/avahi.service

You can't proxy the zeroconf inside the container to the outside, since this would need routing and forwarding to your internal docker0 interface from outside.

You can just expose the needed ports to the docker hosts port and install avahi.
After that just add a new service which fits to your config.

### Example Configuration

__/etc/avahi/services/smb.service__

    <?xml version="1.0" standalone='no'?>
    <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
    <service-group>
     <name replace-wildcards="yes">%h</name>
     <service>
       <type>_smb._tcp</type>
       <port>445</port>
     </service>
     <service>
       <type>_device-info._tcp</type>
       <port>0</port>
       <txt-record>model=RackMac</txt-record>
     </service>
    </service-group>

__/etc/avahi/services/smb.service__ (with TimeMachine Support - more infos: https://gist.github.com/ChloeTigre/4c2022c0d1a281deedba6f7539a2e3ae)

`SAMBA_VOLUME_CONFIG_timecapsule: "[Time Capsule]; path = /shares/TimeCapsule; valid users = johndoe; guest ok = no; read only = no; browseable = no; force user = nobody; force group = nogroup; force create mode = 0660; force directory mode = 2770; fruit:aapl = yes; fruit:time machine = yes; fruit:time machine max size = 2000G;"`

```
<?xml version="1.0" standalone='no'?>
<!DOCTYPE service-group SYSTEM "avahi-service.dtd">
<service-group>
 <name replace-wildcards="yes">%h</name>
 <service>
   <type>_adisk._tcp</type>
   <txt-record>sys=waMa=0,adVF=0x100</txt-record>
   <txt-record>dk0=adVN=Time Capsule,adVF=0x82</txt-record>
 </service>
  <service>
    <type>_smb._tcp</type>
    <port>445</port>
  </service>
</service-group>
```
