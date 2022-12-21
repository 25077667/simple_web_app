#!/bin/bash

# Need the root privilege to run this script
if [ "$EUID" -ne 0 ]; then
    # Use sudo to run this script
    sudo "$0" "$@"
    exit $?
fi

# Check the $(pwd)/../../swag/auto-update/flag/ directory for the flag file
# If the flag's status file is not empty, then the update is in progress

# If the flag's status file is "update {target}", then we do the update
FLAG_DIR=$(pwd)/../../swag/auto-update/flag/
FLAG_STATUS_FILE=$FLAG_DIR/status

do_update() {
    # $TARGET is the argument passed to this function from check_update()
    # Do the update
    echo "Updating to $TARGET"

    # docker pull the target url
    # url = zxc25077667/simple-web-${TARGET}:latest
    docker pull zxc25077667/simple-web-${TARGET}:latest

    # Take down the current web service
    # Target docker-compose file is $(pwd)/../../swag/web/docker-compose.yml
    TARGET_WEB_COMPOSE=$(pwd)/../../swag/web/docker-compose.yml
    docker-compose -f $TARGET_WEB_COMPOSE down

    # Relaunch the web service without cache
    docker-compose -f $TARGET_WEB_COMPOSE up --no-cache -d
}

# A function that checks if we need to do the update via the status file
# The only one chaging the status file is set the flag to "{TARGET}{docker-image-hash}{TIME} complete"
check_update() {
    if [ -f $FLAG_STATUS_FILE ]; then
        # The status file is not empty or it not contains "empty"
        if [ -s $FLAG_STATUS_FILE ]; then
            # The status file is not empty
            # Check if the status file is "update {target}"
            if grep -q "update" $FLAG_STATUS_FILE; then
                # We need to do the update
                # Get the target
                TARGET=$(cat $FLAG_STATUS_FILE | cut -d ' ' -f 2)
                # Invoke the update function
                do_update

                # Set the status file to "{TARGET}{docker-image-hash}{TIME} complete"
                DOCKER_IMAGE_HASH=$(docker images | grep "zxc25077667/simple-web-${TARGET}" | awk '{print $3}')
                # Time is format as "hh:mm:ss"
                TIME=$(date +"%T")
                echo "${TARGET}${DOCKER_IMAGE_HASH}${TIME} complete" >$FLAG_STATUS_FILE

                # Clean local variables
                # Prevent any unexpected behavior
                unset TARGET
                unset DOCKER_IMAGE_HASH
                unset TIME
            fi
        fi

        if grep -q "empty" $FLAG_STATUS_FILE; then
            echo "It is up-to-date"
        fi
    else
        # The status file does not exist
        # Warn the user with "Time and red message"
        TIME=$(date +"%T")
        echo -e "${TIME} \e[31m[WARNING] The status file does not exist\e[0m"
        unset TIME
    fi
}

# Main function
main() {
    # Keep checking if we need to do the update
    while true; do
        check_update
        sleep 5
    done
}

main
