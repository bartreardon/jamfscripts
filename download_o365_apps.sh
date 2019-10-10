#!/bin/bash

DEPNotifyLog="/var/tmp/depnotify.log"
DEPSteps="80" # 80 is the current value set in the DEPNotify initialisation script (this could be a parameter)

O365Latest="https://macadmins.software/latest.xml"

# called as a jamf profile script
# custom parameters start at $4
# accept app name - must be one of Word / Excel / PowerPoint / Outlook / OneNote / OneDrive
# TODO: add other package types Teams / Yammer / Edge / Remote Desktop / Auto Update

APPName=$4

PKGID="com.microsoft.$(echo ${APPName} | /usr/bin/awk '{print tolower($0)}').standalone.365"

XML=$(/usr/bin/curl -s ${O365Latest})

if [[ ! -z ${XML} ]]; then
        
    O365Version=$(/usr/bin/xmllint --xpath '//latest/o365/text()' - <<< "${XML}")

    PKGURL=$(/usr/bin/xmllint --xpath '//latest/package[id="'"${PKGID}"'"]/download/text()' - <<< "${XML}")
    TMPFileName="/tmp/MS${APPName}_${O365Version}.pkg"

    echo "${APPName} pkgurl ${PKGURL}"

    echo "Status: Downloading Microsoft ${APPName} ${O365Version}..." >> ${DEPNotifyLog}
    /bin/sleep 2
    
    # set determinate to Manual - will pause the status bar updating while we spam the status line
    echo "Command: DeterminateManual: ${DEPSteps}" >> ${DEPNotifyLog}
    
    # download the file
    # curl outputs progress - we look for % sign and capture the progress
    /usr/bin/curl -L -# -o ${TMPFileName} ${PKGURL} 2>&1 | while IFS= read -r -n1 char; do
        [[ $char =~ [0-9] ]] && keep=1 ;
        [[ $char == % ]] && echo "Status: Downloading ${appname} ${progress}%" >> ${DEPNotifyLog} && progress="" && keep=0 ;
        [[ $keep == 1 ]] && progress="$progress$char" ;
    done
    
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Installing Microsoft ${APPName} ${O365Version}" >> ${DEPNotifyLog}
    /bin/sleep 2
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    
    # run instaler in verboseR mode to give installer percentage
    # when we find a % sign, capture up until the decimal point and then output
    # we don't capture the full percentage as installer outputs to 6 decimal places which is a tad overkill
    /usr/sbin/installer -pkg ${TMPFileName} -target / -verboseR 2>&1 | while read -r -n1 char; do
        [[ $char == % ]] && keep=1 ;
        [[ $char =~ [0-9] ]] && [[ $keep == 1 ]] && progress="$progress$char" ;
        [[ $char == . ]] && [[ $keep == 1 ]] && echo "Status: Installing Microsoft ${APPName} ${progress}%" >> ${DEPNotifyLog} && progress="" && keep=0 ;
    done
    
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Microsoft ${APPName} Install Complete" >> ${DEPNotifyLog}
    /bin/sleep 1
    echo "Command: DeterminateManualStep: 1" >> ${DEPNotifyLog}
    echo "Status: Deleting Temp Files..." >> ${DEPNotifyLog}
    /bin/rm ${TMPFileName}
    
    # set determinate to back to auto
    echo "Command: Determinate: ${DEPSteps}" >> ${DEPNotifyLog}
else
	echo "Status: Error Downloading Microsoft ${APPName} ${O365Version} from ${O365Latest}..." >> ${DEPNotifyLog}
    /bin/sleep 2
fi
