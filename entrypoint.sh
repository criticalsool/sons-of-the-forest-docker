#! /bin/bash

# Quick function to generate a timestamp
timestamp () {
  date +"%Y-%m-%d %H:%M:%S,%3N"
}

shutdown () {
    echo ""
    echo "$(timestamp) INFO: Recieved SIGTERM, shutting down gracefully"
    kill -2 $sotf_pid
}

# Set our trap
trap 'shutdown' TERM

# Install/Update Sotf
echo "$(timestamp) INFO: Updating Sotf Dedicated Server"
${STEAMCMD_PATH}/steamcmd.sh +@sSteamCmdForcePlatformType windows +force_install_dir "$SOTF_PATH" +login anonymous +app_update ${STEAM_APP_ID} validate +quit

# Check that steamcmd was successful
if [ $? != 0 ]; then
    echo "$(timestamp) ERROR: steamcmd was unable to successfully initialize and update Sotf"
    exit 1
fi

# Check for proper save permissions
if ! touch "${SOTF_PATH}/savegame/test"; then
    echo ""
    echo "$(timestamp) ERROR: The ownership of /home/steam/sotf/savegame is not correct and the server will not be able to save..."
    echo "the directory that you are mounting into the container needs to be owned by 10000:10000"
    echo "from your container host attempt the following command 'chown -R 10000:10000 /your/sotf/folder'"
    echo ""
    exit 1
fi

rm "${SOTF_PATH}/savegame/test"

# Wine talks too much and it's annoying
export WINEDEBUG=-all

# Check that log directory exists, if not create
if ! [ -d "${SOTF_PATH}/logs" ]; then
    mkdir -p "${SOTF_PATH}/logs"
fi

# Check that log file exists, if not create
if ! [ -f "${SOTF_PATH}/logs/sotf_server.log" ]; then
    touch "${SOTF_PATH}/logs/sotf_server.log"
fi

# Link logfile to stdout of pid 1 so we can see logs
ln -sf /proc/1/fd/1 "${SOTF_PATH}/logs/sotf_server.log"

# Launch Sotf
echo "$(timestamp) INFO: Starting Sotf Dedicated Server"

${STEAMCMD_PATH}/compatibilitytools.d/GE-Proton${GE_PROTON_VERSION}/proton run ${SOTF_PATH}/SonsOfTheForestDS.exe &

# Find pid for SonsOfTheForestDS.exe
timeout=0
while [ $timeout -lt 11 ]; do
    if ps -e | grep "SonsOfTheForestDS"; then
        sotf_pid=$(ps -e | grep "SonsOfTheForestDS" | awk '{print $1}')
        break
    elif [ $timeout -eq 10 ]; then
        echo "$(timestamp) ERROR: Timed out waiting for SonsOfTheForestDS.exe to be running"
        exit 1
    fi
    sleep 6
    ((timeout++))
    echo "$(timestamp) INFO: Waiting for SonsOfTheForestDS.exe to be running"
done

# Hold us open until we recieve a SIGTERM
wait

# Handle post SIGTERM from here
# Hold us open until WSServer-Linux pid closes, indicating full shutdown, then go home
tail --pid=$sotf_pid -f /dev/null

# o7
echo "$(timestamp) INFO: Shutdown complete."
exit 0