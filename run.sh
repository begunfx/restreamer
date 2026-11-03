#!/bin/sh

# Start script for the Restreamer bundle

# First run the import program. It will read the db.dir from the config file in order to
# find an old v1.json. This will be converted to the new db format.

if [ -x ./bin/import ]; then
    ./bin/import
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# Run the FFmpeg migration program. In case a FFmpeg 5 binary is present, it will create a
# backup of the current DB and modify the FFmpeg parameter such that they are compatible
# with FFmpeg 5.

if [ -x ./bin/ffmigrate ]; then
    ./bin/ffmigrate
    if [ $? -ne 0 ]; then
        exit 1
    fi
fi

# Create a hint for the admin interface if there is no index.html

if ! [ -f "${CORE_STORAGE_DISK_DIR}/index.html" ]; then
    cp /core/ui-root/index.html /core/ui-root/index_icon.svg ${CORE_STORAGE_DISK_DIR}
fi

# Install / refresh HSTile low-latency player assets into public storage root.
# Served as: /hstile-player.html?id=<channel-uuid>&autoplay=1&mute=1
if [ -d /core/ui-root/hstile ]; then
    cp -f /core/ui-root/hstile/hstile-player.html ${CORE_STORAGE_DISK_DIR}/hstile-player.html
    cp -f /core/ui-root/hstile/hls.min.js ${CORE_STORAGE_DISK_DIR}/hls.min.js
fi

# Now run the core with the possibly converted configuration.

exec ./bin/core
