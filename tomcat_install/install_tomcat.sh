#!/bin/bash

if [ $UID -ne 0 ]
then
	echo "Run script with sudo permission!!!"
	exit 1
fi


function CHK_ERR()
{
	if [ $? -ne 0 ]
	then
		echo "Failed to $1 $2"
		exit 1
	fi
}

# Install JDK
apt update 
apt install openjdk-8-jdk -y
CHK_ERR "install JDK"

# Add tomcat user
useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat
#CHK_ERR "add tomcat user"

# Download latest stable tomcat 
if [ ! -f /tmp/apache-tomcat-9.0.24.tar.gz ]
then
	wget http://www-eu.apache.org/dist/tomcat/tomcat-9/v9.0.24/bin/apache-tomcat-9.0.24.tar.gz -P /tmp
	CHK_ERR "download tomcat"
fi

# unzip and install tomcat package
tar xf /tmp/apache-tomcat-9*.tar.gz -C /opt/tomcat && ln -sf /opt/tomcat/apache-tomcat-9.0.24 /opt/tomcat/latest && chown -RH tomcat: /opt/tomcat/latest
CHK_ERR "extract and install tomcat"
sh -c 'chmod +x /opt/tomcat/latest/bin/*.sh'


# Create tomcat startup systemd service 
tee /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Tomcat 9 servlet container
After=network.target

[Service]
Type=forking

User=tomcat
Group=tomcat

Environment="JAVA_HOME=`readlink -f /etc/alternatives/java | sed -e 's/\/jre\/bin\/java$//'`"
Environment="JAVA_OPTS=-Djava.security.egd=file:///dev/urandom -Djava.awt.headless=true"

Environment="CATALINA_BASE=/opt/tomcat/latest"
Environment="CATALINA_HOME=/opt/tomcat/latest"
Environment="CATALINA_PID=/opt/tomcat/latest/temp/tomcat.pid"
Environment="CATALINA_OPTS=-Xms512M -Xmx1024M -server -XX:+UseParallelGC"

ExecStart=/opt/tomcat/latest/bin/startup.sh
ExecStop=/opt/tomcat/latest/bin/shutdown.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl start tomcat
CHK_ERR "start tomcat service"

#systemctl status tomcat

systemctl enable tomcat
CHK_ERR "enable tomcat service"

# Allow tomcat port 8080 in firewall
ufw allow 8080/tcp


# Setup Tomcat Admin & Manager Users
tee /opt/tomcat/latest/conf/tomcat-users.xml <<EOF
<tomcat-users>

  <!-- user manager can access only manager section -->
  <role rolename="manager-gui" />
  <user username="tomcat" password="tomcat" roles="manager-gui" />

  <!-- user admin can access manager and admin section both -->
  <role rolename="admin-gui" />
  <user username="tomcat" password="tomcat" roles="manager-gui,admin-gui" />

</tomcat-users>
EOF

tee /opt/tomcat/latest/webapps/manager/META-INF/context.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
<!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
-->
</Context>
EOF

tee /opt/tomcat/latest/webapps/host-manager/META-INF/context.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context antiResourceLocking="false" privileged="true" >
<!--
  <Valve className="org.apache.catalina.valves.RemoteAddrValve"
         allow="127\.\d+\.\d+\.\d+|::1|0:0:0:0:0:0:0:1" />
-->
</Context>
EOF


# Restart tomcat service 
systemctl restart tomcat

echo "------------------------------------------------------"
echo "		Tomcat9 installed successfully	    	    "
echo "------------------------------------------------------"
