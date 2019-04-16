#!/bin/bash

source /home/admin/raspiblitz.info
source /mnt/hdd/raspiblitz.conf 

# command info
if [ "$1" = "-h" ] || [ "$1" = "-help" ]; then
 echo "# script to scan the state of the system after setup"
 exit 1
fi

# measure time of scan
startTime=$(date +%s)

# localIP
localip=$(ip addr | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1 -d'/')
echo "localIP='${localip}'"

# is bitcoind running
bitcoinRunning=$(systemctl status ${network}d.service 2>/dev/null | grep -c running)
echo "bitcoinActive=${bitcoinRunning}"

if [ ${bitcoinRunning} -eq 1 ]; then

  # get blockchain info
  blockchaininfo=$(sudo -u bitcoin ${network}-cli -datadir=/home/bitcoin/.${network} getblockchaininfo 2>/home/bitcoin/.${network}/.bitcoind.error)

  # check if error on request
  bitcoinError=$(sudo -u bitcoin cat /home/bitcoin/.${network}/.bitcoind.error | tr "'" '"' | tr '"' '\"' )
  sudo -u bitcoin rm /home/bitcoin/.${network}/.bitcoind.error
  if [ ${#bitcoinError} -gt 0 ];
    echo "bitcoinError='${bitcoinError}'"
  else

    ##############################
    # Get data from blockchaininfo
    ##############################

    # get total number of blocks
    total=$(echo ${blockchaininfo} | jq -r '.blocks')
    echo "blockchainHeight=${total}"
    
    # is initial sync of blockchain
    initialSync=$(echo ${blockchaininfo} | jq -r '.initialblockdownload' | grep -c 'true')
    echo "initialSync=${initialSync}"

    # get blockchain sync progress
    syncProgress="$(echo ${blockchaininfo} | jq -r '.verificationprogress')"
    syncProgress=$(echo $syncProgress | awk '{printf( "%.2f%%", 100 * $1)}')
    echo "syncProgress=${syncProgress}"

  fi
fi

# is LND running
lndRunning=$(systemctl status lnd.service 2>/dev/null | grep -c running)

# TODO: check how long running ... try to find out if problem on starting

echo "lndActive=${lndRunning}"

if [ ${lndRunning} -eq 1 ]; then

  # get LND info
  lndinfo=$(sudo -u bitcoin lncli getinfo 2>/home/bitcoin/.lnd/.lnd.error)

  # check if error on request
  lndError=$(sudo -u bitcoin cat /home/bitcoin/.lnd/.lnd.error | tr "'" '"' | tr '"' '\"' )
  sudo -u bitcoin rm /home/bitcoin/.lnd/.lnd.error
  if [ ${#lndError} -gt 0 ];
    echo "lndError='${lndError}'"
  else
    
    # synced to chain
    syncedToChain=$(echo ${lndinfo} | jq -r '.synced_to_chain' | grep -c 'true')
    echo "syncedToChain=${syncedToChain}"

    # lnd scan progress
    lndTimestamp=$(echo ${lndinfo} | jq -r '.best_header_timestamp')
    echo "lndTimestamp=${lndTimestamp}"
    lndDate=$(date -d @${lndTimestamp})
    echo "lndDate=${lndDate}"

    # calculate LND scan progress by seconds since Genesisblock
    genesisTimestamp=1230940800
    nowTimestamp=$(date +%s)
    totalSeconds=$(echo "${nowTimestamp}-${genesisTimestamp}" | bc)
    echo "# totalSeconds($totalSeconds)"
    scannedSeconds=$(echo "${lndTimestamp}-${genesisTimestamp}" | bc)
    echo "# scannedSeconds($scannedSeconds)"
    scanProgress=$(echo "scale=2; $scannedSeconds*100/$totalSeconds" | bc)
    echo "scanProgress=${scanProgress}"
    
  fi

fi

# check if online if problem with other stuff 

# info on scan run time
endTime=$(date +%s)
runTime=$(echo "${endTime}-${startTime}" | bc)
echo "scantime=${runTime}"


