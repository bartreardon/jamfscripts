#!/bin/bash

DEPNotifyLog="/var/tmp/depnotify.log"
DeterminateLevel="80"     # 80 is the current value set in BOE 01 - Launch DEPNotify script

O365Latest="https://macadmins.software/latest.xml"

# called as a jamf profile script
# custom parameters start at $4
# accept app name - must be one of Word / Excel / PowerPoint / Outlook / OneNote / OneDrive
# TODO: add other package types Edge / Remote Desktop / Auto Update

APPName=$4

#if [[ ${APPName} == "Yammer" ]]; then
if [[ "${APPName}" =~ ^(Yammer|Teams)$ ]]; then
    PKGID="com.microsoft.$(echo ${APPName} | /usr/bin/awk '{print tolower($0)}').standalone"
else
    PKGID="com.microsoft.$(echo ${APPName} | /usr/bin/awk '{print tolower($0)}').standalone.365"
fi
echo $PKGID
#exit 0
XML=$(/usr/bin/curl -s ${O365Latest})

if [[ ! -z ${XML} ]]; then
        
    O365Version=$(/usr/bin/xmllint --xpath '//latest/o365/text()' - <<< "${XML}")
    
    PKGVersion=$(/usr/bin/xmllint --xpath '//latest/package[id="'"${PKGID}"'"]/version/text()' - <<< "${XML}" | awk '{print $1}')
    PKGURL=$(/usr/bin/xmllint --xpath '//latest/package[id="'"${PKGID}"'"]/download/text()' - <<< "${XML}")
    if [[ ! $? -eq 0 ]]; then
        echo "Status: Error No Package URL for ${PKGID}..." >> ${DEPNotifyLog}
        exit 0
    fi
    # follow the redirects until we get the actual package URL we want
    PKGURL=$(curl -sIL "${PKGURL}" | grep -i location)
    PKGURL=$(echo "${PKGURL##*$'\n'}" | awk '{print $NF}' | tr -d '\r')
    
    # get the header and package name from the URL
    PKGName=$(echo ${PKGURL} | awk -F "/" '{print $NF}' | tr -d '\r')    
    PKGEXT=$(echo "${PKGName}" | awk -F "." '{print $NF}' | tr -d '\r')
    
    TMPFileName="/tmp/${PKGName}"
    /bin/rm ${TMPFileName}
    
    echo "${APPName} pkgurl ${PKGURL}"

    echo "Status: Downloading Microsoft ${APPName} ${PKGVersion}..." >> ${DEPNotifyLog}
    /bin/sleep 2
    
    # set determinate to Manual - will pause the status bar updating while we spam the status line
    echo "Command: DeterminateManual: ${DeterminateLevel}" >> ${DEPNotifyLog}
    
    #debug
    #echo "PKGURL = ${PKGURL}"
    #echo "PKGName = ${PKGName}"
    #echo "PKGEXT = ${PKGEXT}"
    #echo "TMPFileName = ${TMPFileName}"
    #echo "APPName = ${APPName}"
    
    #if [[ ${PKGEXT} == "pkg" ]]; then
    #    echo "detected pkg"
    #elif [[ ${PKGEXT} == "dmg" ]]; then
    #    echo "detected dmg"
    #else
    #    echo "detected nothing"
    #fi
    
    #exit 0
    
    # download the file
    # curl outputs progress - we look for % sign and capture the progress
    /usr/bin/curl -L -# -o "${TMPFileName}" "${PKGURL}" 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Status: Downloading ${APPName} ${progress}%" >> ${DEPNotifyLog} && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
    done
    
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Installing Microsoft ${APPName} ${PKGVersion}" >> ${DEPNotifyLog}
    /bin/sleep 2
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    
    if [[ ${PKGEXT} == "pkg"* ]]; then
        # run instaler in verboseR mode to give installer percentage
        # when we find a % sign, capture up until the decimal point and then output
        # we don't capture the full percentage as installer outputs to 6 decimal places which is a tad overkill
        echo "installing from ${TMPFileName}"
        /usr/sbin/installer -pkg ${TMPFileName} -target / -verboseR 2>&1 | while read -r -n1 char; do
            [[ $char == % ]] && keep=1 ;
            [[ $char =~ [0-9] ]] && [[ $keep == 1 ]] && progress="$progress$char" ;
            [[ $char == . ]] && [[ $keep == 1 ]] && echo "Status: Installing Microsoft ${APPName} ${progress}%" >> ${DEPNotifyLog} && progress="" && keep=0 ;
        done
    
    elif [[ ${PKGEXT} == "dmg"* ]]; then
        echo "Status: Mounting ${PKGName}" >> ${DEPNotifyLog}
        mountPath=$(hdiutil attach ${TMPFileName} | grep "/Volumes" | awk '{print $NF}')
        echo "Status: Mounted at ${mountPath}" >> ${DEPNotifyLog}
        # copy all .app to /Volumes
        for appBundle in $(ls -d ${mountPath}/*.app); do
            echo "Status: Copying ${appBundle} to Applications" >> ${DEPNotifyLog}
            cp -r ${appBundle} /Applications/
        done
        echo "Status: Ejecting ${mountPath}" >> ${DEPNotifyLog}
        hdiutil eject ${mountPath}
    else
        echo "Status: There was an error determiningnpackage type for ${PKGName}" >> ${DEPNotifyLog}
    fi
    
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Microsoft ${APPName} Install Complete" >> ${DEPNotifyLog}
    /bin/sleep 1
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Cleaning up..." >> ${DEPNotifyLog}
    /bin/rm ${TMPFileName}
    
    # set determinate to back to auto
    echo "Command: Determinate: ${DeterminateLevel}" >> ${DEPNotifyLog}
else
	echo "Status: Error Downloading Microsoft ${APPName} ${PKGVersion} from ${O365Latest}..." >> ${DEPNotifyLog}
    /bin/sleep 2
fi
