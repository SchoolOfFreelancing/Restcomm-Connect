#!/bin/bash
##
## Description: Configures RestComm
## Author: Henrique Rosa (henrique.rosa@telestax.com)
## Author: Pavel Slegr (pavel.slegr@telestax.com)
##

# VARIABLES
RESTCOMM_BIN=$RESTCOMM_HOME/bin
RESTCOMM_DARS=$RESTCOMM_HOME/standalone/configuration/dars
RESTCOMM_CONF=$RESTCOMM_HOME/standalone/configuration
RESTCOMM_DEPLOY=$RESTCOMM_HOME/standalone/deployments/restcomm.war
RVD_DEPLOY=$RESTCOMM_HOME/standalone/deployments/restcomm-rvd.war

## FUNCTIONS

## Description: Configures Java Options for Application Server
## Parameters : none
configRCJavaOpts() {
	FILE=$RESTCOMM_BIN/standalone.conf
    echo "RestComm java options with: $RC_JAVA_OPTS"
    sed -e "/if \[ \"x\$JAVA_OPTS\" = \"x\" \]; then/ {
		N; s|JAVA_OPTS=.*|JAVA_OPTS=\"$RC_JAVA_OPTS\"|
	}" $FILE > $FILE.bak
	mv $FILE.bak $FILE
}

## Description: Updates RestComm configuration file
## Parameters : 1.STATIC_ADDRESS
configRestcomm() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	static_address="$1"

	sed -e  "s|<\!--.*<external-ip>.*<\/external-ip>.*-->|<external-ip>$static_address<\/external-ip>|" \
		-e "s|<external-ip>.*<\/external-ip>|<external-ip>$static_address<\/external-ip>|" \
		 $FILE > $FILE.bak;

	mv $FILE.bak $FILE
	echo 'Updated RestComm configuration'

    #If "STRICT" no self-signed certificate is permitted.
	if [ "$SSL_MODE" == "strict" ] || [ "$SSL_MODE" == "STRICT" ]; then
		sed -e "s/<ssl-mode>.*<\/ssl-mode>/<ssl-mode>strict<\/ssl-mode>/" $FILE > $FILE.bak
		mv $FILE.bak $FILE
	else
		sed -e "s/<ssl-mode>.*<\/ssl-mode>/<ssl-mode>allowall<\/ssl-mode>/" $FILE > $FILE.bak
		mv $FILE.bak $FILE
	fi

	#Configure RESTCOMM_HOSTNAME at restcomm.xml. If not set "STATIC_ADDRESS" will be used.
	if [ -n "$RESTCOMM_HOSTNAME" ]; then
  		echo "HOSTNAME $RESTCOMM_HOSTNAME"
  		sed -i "s|<hostname>.*<\/hostname>|<hostname>${RESTCOMM_HOSTNAME}<\/hostname>|" $RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	else
  		sed -i "s|<hostname>.*<\/hostname>|<hostname>${PUBLIC_IP}<\/hostname>|" $RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
 	fi
}
## Description: OutBoundProxy configuration.
configOutboundProxy(){
    echo "Configure outbound-proxy"
    FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
    sed -e "s|<outbound-proxy-uri>.*<\/outbound-proxy-uri>|<outbound-proxy-uri>$OUTBOUND_PROXY<\/outbound-proxy-uri>|" \
	-e "s|<outbound-proxy-user>.*<\/outbound-proxy-user>|<outbound-proxy-user>$OUTBOUND_PROXY_USERNAME<\/outbound-proxy-user>|"  \
	-e "s|<outbound-proxy-password>.*<\/outbound-proxy-password>|<outbound-proxy-password>$OUTBOUND_PROXY_PASSWORD<\/outbound-proxy-password>|" $FILE > $FILE.bak;
	mv $FILE.bak $FILE
}

## Description: Configures Voip Innovations Credentials
## Parameters : 1.Login
## 				2.Password
## 				3.Endpoint
configVoipInnovations() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<voip-innovations>/ {
		N; s|<login>.*</login>|<login>$1</login>|
        N; s|<password>.*</password>|<password>$2</password>|
        N; s|<endpoint>.*</endpoint>|<endpoint>$3</endpoint>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Voip Innovation credentials'
}

## Description: PROVISION MANAGER configuration.
# MANAGERS : VI (Voip innovations),NX (nexmo),VB (Voxbone), BW(Bandwidth).
configDidProvisionManager() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	#Check for port offset.
	if (( $PORT_OFFSET > 0 )); then
		local SIP_PORT_UDP=$((SIP_PORT_UDP + PORT_OFFSET))
	fi

		if [[ "$PROVISION_PROVIDER" == "VI" || "$PROVISION_PROVIDER" == "vi" ]]; then
			sed -e "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.vi.VoIPInnovationsNumberProvisioningManager\"|" $FILE > $FILE.bak

			sed -e "/<voip-innovations>/ {
				N; s|<login>.*</login>|<login>$1</login>|
				N; s|<password>.*</password>|<password>$2</password>|
				N; s|<endpoint>.*</endpoint>|<endpoint>$3</endpoint>|
			}" $FILE.bak > $FILE
			sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE
			echo 'Configured Voip Innovation credentials'
		else
			if [[ "$PROVISION_PROVIDER" == "BW" || "$PROVISION_PROVIDER" == "bw" ]]; then
			sed -e "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.bandwidth.BandwidthNumberProvisioningManager\"|" $FILE > $FILE.bak

			sed -e "/<bandwidth>/ {
				N; s|<username>.*</username>|<username>$1</username>|
				N; s|<password>.*</password>|<password>$2</password>|
				N; s|<accountId>.*</accountId>|<accountId>$6</accountId>|
				N; s|<siteId>.*</siteId>|<siteId>$4</siteId>|
			}" $FILE.bak > $FILE
			sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE
			echo 'Configured Bandwidth credentials'
			else
				if [[ "$PROVISION_PROVIDER" == "NX" || "$PROVISION_PROVIDER" == "nx" ]]; then
					echo "Nexmo PROVISION_PROVIDER"
					sed -i "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.nexmo.NexmoPhoneNumberProvisioningManager\"|" $FILE

					sed -i "/<callback-urls>/ {
						N; s|<voice url=\".*\" method=\".*\" />|<voice url=\"$5:$SIP_PORT_UDP\" method=\"SIP\" />|
						N; s|<sms url=\".*\" method=\".*\" />|<sms url=\"\" method=\"\" />|
						N; s|<fax url=\".*\" method=\".*\" />|<fax url=\"\" method=\"\" />|
						N; s|<ussd url=\".*\" method=\".*\" />|<ussd url=\"\" method=\"\" />|
					}" $FILE

					sed -i "/<nexmo>/ {
						N; s|<api-key>.*</api-key>|<api-key>$1</api-key>|
						N; s|<api-secret>.*</api-secret>|<api-secret>$2</api-secret>|
						N
						N; s|<smpp-system-type>.*</smpp-system-type>|<smpp-system-type>$7</smpp-system-type>|
					}" $FILE

					sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"true"<\/outboudproxy-user-at-from-header>|" $FILE

				else
					if [[ "$PROVISION_PROVIDER" == "VB" || "$PROVISION_PROVIDER" == "vb" ]]; then
					echo "Voxbone PROVISION_PROVIDER"
					sed -i "s|phone-number-provisioning class=\".*\"|phone-number-provisioning class=\"org.mobicents.servlet.restcomm.provisioning.number.voxbone.VoxbonePhoneNumberProvisioningManager\"|" $FILE

					sed -i "/<callback-urls>/ {
						N; s|<voice url=\".*\" method=\".*\" />|<voice url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
						N; s|<sms url=\".*\" method=\".*\" />|<sms url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
						N; s|<fax url=\".*\" method=\".*\" />|<fax url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
						N; s|<ussd url=\".*\" method=\".*\" />|<ussd url=\"\+\{E164\}\@$5:$SIP_PORT_UDP\" method=\"SIP\" />|
					}" $FILE

					sed -i "/<voxbone>/ {
						N; s|<username>.*</username>|<username>$1</username>|
						N; s|<password>.*</password>|<password>$2</password>|
					}" $FILE
					sed -i "s|<outboudproxy-user-at-from-header>.*<\/outboudproxy-user-at-from-header>|<outboudproxy-user-at-from-header>"false"<\/outboudproxy-user-at-from-header>|" $FILE

					fi
				fi
			fi
		fi
}

## Description: Configures Fax Service Credentials
## Parameters : 1.Username
## 				2.Password
configFaxService() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<fax-service.*>/ {
		N; s|<user>.*</user>|<user>$1</user>|
		N; s|<password>.*</password>|<password>$2</password>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Fax Service credentials'
}

## Description: Configures Sms Aggregator
## Parameters : 1.Outbound endpoint IP
##
configSmsAggregator() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<sms-aggregator.*>/ {
		N; s|<outbound-prefix>.*</outbound-prefix>|<outbound-prefix>$2</outbound-prefix>|
		N; s|<outbound-endpoint>.*</outbound-endpoint>|<outbound-endpoint>$1</outbound-endpoint>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo "Configured Sms Aggregator using OUTBOUND PROXY $1"
}

## Description: Configures Speech Recognizer
## Parameters : 1.iSpeech Key
configSpeechRecognizer() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<speech-recognizer.*>/ {
		N; s|<api-key.*></api-key>|<api-key production=\"true\">$1</api-key>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured the Speech Recognizer'
}

## Description: Configures available speech synthesizers
## Parameters : none
configSpeechSynthesizers() {
	configAcapela $ACAPELA_APPLICATION $ACAPELA_LOGIN $ACAPELA_PASSWORD
	configVoiceRSS $VOICERSS_KEY
}

## Description: Configures Acapela Speech Synthesizer
## Parameters : 1.Application Code
## 				2.Login
## 				3.Password
configAcapela() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<speech-synthesizer class=\"org.mobicents.servlet.restcomm.tts.AcapelaSpeechSynthesizer\">/ {
		N
		N; s|<application>.*</application>|<application>$1</application>|
		N; s|<login>.*</login>|<login>$2</login>|
		N; s|<password>.*</password>|<password>$3</password>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured Acapela Speech Synthesizer'
}

## Description: Configures VoiceRSS Speech Synthesizer
## Parameters : 1.API key
configVoiceRSS() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	sed -e "/<service-root>http:\/\/api.voicerss.org<\/service-root>/ {
		N; s|<apikey>.*</apikey>|<apikey>$1</apikey>|
	}" $FILE > $FILE.bak

	mv $FILE.bak $FILE
	echo 'Configured VoiceRSS Speech Synthesizer'
}

## Description: Updates Mobicents properties for RestComm
## Parameters : none
configMobicentsProperties() {
	FILE=$RESTCOMM_DARS/mobicents-dar.properties
	sed -e 's|^ALL=.*|ALL=("RestComm", "DAR\:From", "NEUTRAL", "", "NO_ROUTE", "0")|' $FILE > $FILE.bak
	mv $FILE.bak $FILE
	echo "Updated mobicents-dar properties"
}

## Description: Configures TeleStax Proxy
## Parameters : 1.Enabled
##              2.login
##              3.password
## 		4.Endpoint
## 		5.Proxy IP
configTelestaxProxy() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	enabled="$1"
	if [ "$enabled" == "true" ] || [ "$enabled" == "TRUE" ]; then
		sed -e "/<telestax-proxy>/ {
			N; s|<enabled>.*</enabled>|<enabled>$1</enabled>|
		N; s|<login>.*</login>|<login>$2</login>|
		N; s|<password>.*</password>|<password>$3</password>|
		N; s|<endpoint>.*</endpoint>|<endpoint>$4</endpoint>|
		N; s|<siteId>.*</siteId>|<siteId>$6</siteId>|
		N; s|<uri>.*</uri>|<uri>http:\/\/$5:2080</uri>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo 'Enabled TeleStax Proxy'
	else
		sed -e "/<telestax-proxy>/ {
			N; s|<enabled>.*</enabled>|<enabled>false</enabled>|
			N; s|<login>.*</login>|<login></login>|
			N; s|<password>.*</password>|<password></password>|
			N; s|<endpoint>.*</endpoint>|<endpoint></endpoint>|
			N; s|<siteid>.*</siteid>|<siteid></siteid>|
			N; s|<uri>.*</uri>|<uri>http:\/\/127.0.0.1:2080</uri>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo 'Disabled TeleStax Proxy'
	fi
}


## Description: Configures Media Server Manager
## Parameters : 1.Enabled
## 		2.private IP
## 		3.public IP

configMediaServerManager() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	enabled="$1"
	bind_address="$2"
	ms_external_address="$3"

	if [ "$enabled" == "true" ] || [ "$enabled" == "TRUE" ]; then
		sed -e "/<mgcp-server class=\"org.mobicents.servlet.restcomm.mgcp.MediaGateway\">/ {
			N
			N; s|<local-address>.*</local-address>|<local-address>$bind_address</local-address>|
			N; s|<local-port>.*</local-port>|<local-port>2727</local-port>|
			N; s|<remote-address>127.0.0.1</remote-address>|<remote-address>$bind_address</remote-address>|
			N; s|<remote-port>.*</remote-port>|<remote-port>2427</remote-port>|
			N; s|<response-timeout>.*</response-timeout>|<response-timeout>500</response-timeout>|
			N; s|<\!--.*<external-address>.*</external-address>.*-->|<external-address>$ms_external_address</external-address>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo 'Configured Media Server Manager'
	fi
}

## Description: Configures SMPP Account Details
## Parameters : 1.activate
## 		2.systemID
## 		3.password
## 		4.systemType
## 		5.peerIP
## 		6.peerPort
##      7.sourceMap
##      8.destinationMap

configSMPPAccount() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
	activate="$1"
	systemID="$2"
	password="$3"
	systemType="$4"
	peerIP="$5"
	peerPort="$6"
	sourceMap="$7"
	destinationMap="$8"


	sed -i "s|<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\" activateSmppConnection =\".*\">|<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\" activateSmppConnection =\"$activate\">|g" $FILE
	#Add sourceMap && destinationMap


	if [ "$activate" == "true" ] || [ "$activate" == "TRUE" ]; then
		sed -e	"/<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\"/{
			N
			N
			N
			N
			N; s|<systemid>.*</systemid>|<systemid>$systemID</systemid>|
			N; s|<peerip>.*</peerip>|<peerip>$peerIP</peerip>|
			N; s|<peerport>.*</peerport>|<peerport>$peerPort</peerport>|
			N
			N
			N; s|<password>.*</password>|<password>$password</password>|
			N; s|<systemtype>.*</systemtype>|<systemtype>$systemType</systemtype>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE

        sed -i "s|<connection activateAddressMapping=\"false\" sourceAddressMap=\"\" destinationAddressMap=\"\" tonNpiValue=\"1\">|<connection activateAddressMapping=\"false\" sourceAddressMap=\"${sourceMap}\" destinationAddressMap=\"${destinationMap}\" tonNpiValue=\"1\">|" $FILE
		echo 'Configured SMPP Account Details'

	else
		sed -e	"/<smpp class=\"org.mobicents.servlet.restcomm.smpp.SmppService\"/{
			N
			N
			N
			N
			N; s|<systemid>.*</systemid>|<systemid></systemid>|
			N; s|<peerip>.*</peerip>|<peerip></peerip>|
			N; s|<peerport>.*</peerport>|<peerport></peerport>|
			N
			N
			N; s|<password>.*</password>|<password></password>|
			N; s|<systemtype>.*</systemtype>|<systemtype></systemtype>|
		}" $FILE > $FILE.bak

		mv $FILE.bak $FILE

        sed -i "s|<connection activateAddressMapping=\"false\" sourceAddressMap=\"\" destinationAddressMap=\"\" tonNpiValue=\"1\">|<connection activateAddressMapping=\"false\" sourceAddressMap=\"\" destinationAddressMap=\"\" tonNpiValue=\"1\">|" $FILE
		echo 'Configured SMPP Account Details'
	fi
}

## Description: Configures RestComm "prompts & cache" URIs
#Mostly used for external MS.
configRestCommURIs() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	#check for port offset
	if (( $PORT_OFFSET > 0 )); then
		local HTTP_PORT=$((HTTP_PORT + PORT_OFFSET))
		local HTTPS_PORT=$((HTTPS_PORT + PORT_OFFSET))
	fi

	if [ -n "$MS_ADDRESS" ] && [ "$MS_ADDRESS" != "$BIND_ADDRESS" ]; then
		if [ "$DISABLE_HTTP" = "true" ]; then
            PORT="$HTTPS_PORT"
            SCHEME='https'
		else
			PORT="$HTTP_PORT"
			SCHEME='http'
		fi

		# STATIC_ADDRESS will be populated by user or script before
		REMOTE_ADDRESS="${SCHEME}://${PUBLIC_IP}:${PORT}"
		sed -e "s|<prompts-uri>.*</prompts-uri>|<prompts-uri>$REMOTE_ADDRESS/restcomm/audio<\/prompts-uri>|" \
		-e "s|<cache-uri>.*/cache-uri>|<cache-uri>$REMOTE_ADDRESS/restcomm/cache</cache-uri>|" \
		-e "s|<error-dictionary-uri>.*</error-dictionary-uri>|<error-dictionary-uri>$REMOTE_ADDRESS/restcomm/errors</error-dictionary-uri>|" $FILE > $FILE.bak

		mv $FILE.bak $FILE
		echo "Updated prompts-uri cache-uri error-dictionary-uri External MSaddress for "
	fi
	echo 'Configured RestCommURIs'
}

## Description: Specify the path where Recordings are saved.
updateRecordingsPath() {
	FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml

	if [ -n "$RECORDINGS_PATH" ]; then
		sed -e "s|<recordings-path>.*</recordings-path>|<recordings-path>file://${RECORDINGS_PATH}<\/recordings-path>|" $FILE > $FILE.bak
		echo "Updated RECORDINGS_PATH "

	else
		sed -e "s|<recordings-path>.*</recordings-path>|<recordings-path>file://\${restcomm:home}/recordings<\/recordings-path>|" $FILE > $FILE.bak
	fi
	mv $FILE.bak $FILE
	echo 'Configured Recordings path'
}

## Description: Specify HTTP/S ports used.
#Needed when port offset is set.
configHypertextPort(){
    MSSFILE=$RESTCOMM_CONF/mss-sip-stack.properties

    #Check for Por Offset
	if (( $PORT_OFFSET > 0 )); then
		local HTTP_PORT=$((HTTP_PORT + PORT_OFFSET))
		local HTTPS_PORT=$((HTTPS_PORT + PORT_OFFSET))
	fi

    sed -e "s|org.mobicents.ha.javax.sip.LOCAL_HTTP_PORT=.*|org.mobicents.ha.javax.sip.LOCAL_HTTP_PORT=$HTTP_PORT|" \
     	-e	"s|org.mobicents.ha.javax.sip.LOCAL_SSL_PORT=.*|org.mobicents.ha.javax.sip.LOCAL_SSL_PORT=$HTTPS_PORT|" $MSSFILE > $MSSFILE.bak
    mv $MSSFILE.bak $MSSFILE
    echo "Configured HTTP ports"
}

## Description: Other single configuration
#enable/disable SSLSNI (default:false)
otherRestCommConf(){
    echo "Rest RestComm configuration0"
    FILE=$RESTCOMM_DEPLOY/WEB-INF/conf/restcomm.xml
    sed -e "s|<play-music-for-conference>.*</play-music-for-conference>|<play-music-for-conference>${PLAY_WAIT_MUSIC}<\/play-music-for-conference>|" $FILE > $FILE.bak
	mv $FILE.bak $FILE

     echo "Rest RestComm configuration01"
    #Remove if is set in earlier run.
    grep -q 'allowLegacyHelloMessages' $RESTCOMM_BIN/standalone.conf && sed -i "s|-Dsun.security.ssl.allowLegacyHelloMessages=false -Djsse.enableSNIExtension=.* ||" $RESTCOMM_BIN/standalone.conf

    if [[ "$SSLSNI" == "false" || "$SSLSNI" == "FALSE" ]]; then
		  sed -i "s|-Djava.awt.headless=true|& -Dsun.security.ssl.allowLegacyHelloMessages=false -Djsse.enableSNIExtension=false |" $RESTCOMM_BIN/standalone.conf
	else
	 	  sed -i "s|-Djava.awt.headless=true|& -Dsun.security.ssl.allowLegacyHelloMessages=false -Djsse.enableSNIExtension=true |" $RESTCOMM_BIN/standalone.conf
	fi

    echo "Rest RestComm configuration02"
	if [ -n "$HSQL_DIR" ]; then
  		echo "HSQL_DIR $HSQL_DIR"
  		FILE=$HSQL_DIR/restcomm.script
  		mkdir -p $HSQL_DIR
  		if [ ! -f $FILE ]; then
  		    sed -i "s|<data-files>.*</data-files>|<data-files>${HSQL_DIR}</data-files>|"  $FILE
  		    cp $RESTCOMM_DEPLOY/WEB-INF/data/hsql/* $HSQL_DIR
        fi
 echo "Rest RestComm configuration03"
	fi
 echo "Rest RestComm configuration04"
	if [ -n "$MGMT_PASS" ] && [ -n "$MGMT_USER" ]; then
        grep -q "$MGMT_USER" $RESTCOMM_CONF/mgmt-users.properties || exec $RESTCOMM_BIN/add-user.sh "$MGMT_USER" "$MGMT_PASS" -s
        #Management bind address
        grep -q 'jboss.bind.address.management' $RESTCOMM_BIN/restcomm/start-restcomm.sh || sed -i 's|RESTCOMM_HOME/bin/standalone.sh -b .*|RESTCOMM_HOME/bin/standalone.sh -b $bind_address -Djboss.bind.address.management=$bind_address|' $RESTCOMM_BIN/restcomm/start-restcomm.sh
    fi
    echo "End Rest RestComm configuration05"
}

confRVD(){
    echo "Configure RVD1"
	if [ -n "$RVD_LOCATION" ]; then
  		echo "RVD_LOCATION $RVD_LOCATION"
  		mkdir -p `echo $RVD_LOCATION`
  		sed -i "s|<workspaceLocation>.*</workspaceLocation>|<workspaceLocation>${RVD_LOCATION}</workspaceLocation>|" $RVD_DEPLOY/WEB-INF/rvd.xml
echo "Configure RVD2"
  		COPYFLAG=$RVD_LOCATION/.demos_initialized
  		if [ -f "$COPYFLAG" ]; then
   			#Do nothing, we already copied the demo file to the new workspace
    		echo "RVD demo application are already copied"
    		echo "Configure RVD3"
  		else
  		echo "Configure RVD4"
    		echo "Will copy RVD demo applications to the new workspace $RVD_LOCATION"
    		cp -ar $RVD_DEPLOY/workspace/* $RVD_LOCATION
    		touch $COPYFLAG
  		fi

	fi
echo "Configure RVD5"
	if [ -n "$RVD_PORT" ]; then
        echo "RVD_PORT $RVD_PORI"
        if [[ "$DISABLE_HTTP" == "true" || "$DISABLE_HTTP" == "TRUE" ]]; then
			SCHEME='https'
		else
			SCHEME='http'
		fi
		echo "Configure RVD6"
        #If used means that port mapping at docker (e.g: -p 445:443) is not the default (-p 443:443)
        sed -i "s|<restcommBaseUrl>.*</restcommBaseUrl>|<restcommBaseUrl>${SCHEME}://${PUBLIC_IP}:${RVD_PORT}/</restcommBaseUrl>|" $RVD_DEPLOY/WEB-INF/rvd.xml
    fi
echo "Configure RVD7"
     echo "End Configure RVD"
}


# MAIN
echo 'Configuring RestComm...'
configRCJavaOpts
configMobicentsProperties
configRestcomm "$PUBLIC_IP"
#configVoipInnovations "$VI_LOGIN" "$VI_PASSWORD" "$VI_ENDPOINT"
configDidProvisionManager "$DID_LOGIN" "$DID_PASSWORD" "$DID_ENDPOINT" "$DID_SITEID" "$PUBLIC_IP" "$DID_ACCOUNTID" "$SMPP_SYSTEM_TYPE"
configFaxService "$INTERFAX_USER" "$INTERFAX_PASSWORD"
configSmsAggregator "$SMS_OUTBOUND_PROXY" "$SMS_PREFIX"
configSpeechRecognizer "$ISPEECH_KEY"
configSpeechSynthesizers
configTelestaxProxy "$ACTIVE_PROXY" "$TP_LOGIN" "$TP_PASSWORD" "$INSTANCE_ID" "$PROXY_IP" "$SITE_ID"
configMediaServerManager "$ACTIVE_PROXY" "$BIND_ADDRESS" "$MEDIASERVER_EXTERNAL_ADDRESS"
configSMPPAccount "$SMPP_ACTIVATE" "$SMPP_SYSTEM_ID" "$SMPP_PASSWORD" "$SMPP_SYSTEM_TYPE" "$SMPP_PEER_IP" "$SMPP_PEER_PORT" "$SMPP_SOURCE_MAP" "$SMPP_DEST_MAP"
configRestCommURIs
updateRecordingsPath
configHypertextPort
configOutboundProxy
otherRestCommConf
confRVD
echo 'Configured RestComm!'
