#!/bin/bash

# Source BuildPiper functions
source /opt/buildpiper/shell-functions/functions.sh
source /opt/buildpiper/shell-functions/log-functions.sh

# Set codebase location
CODEBASE_LOCATION="/bp/workspace/${CODEBASE_DIR}"
sleep 1000
echo "$CODEBASE_LOCATION"
logInfoMessage "=========================================="
logInfoMessage " BuildPiper Fastlane Deployment Pipeline"
logInfoMessage "=========================================="

logInfoMessage "Codebase Location: [$CODEBASE_LOCATION]"
logInfoMessage "Platform: [$PLATFORM]"
logInfoMessage "Fastlane Mode: [$FASTLANE_MODE]"

# Sleep if configured - FIXED: Only sleep if SLEEP_DURATION is set and > 0
if [ ! -z "$SLEEP_DURATION" ] && [ "$SLEEP_DURATION" -gt 0 ]; then
    logInfoMessage "Sleeping for ${SLEEP_DURATION} seconds..."
    sleep $SLEEP_DURATION
fi

# Navigate to platform directory with smart fallback
TARGET_DIR="${CODEBASE_LOCATION}"

# If PLATFORM is specified, try to use platform subdirectory
if [ -n "$PLATFORM" ]; then
    PLATFORM_DIR="${CODEBASE_LOCATION}/${PLATFORM}"
    
    if [ -d "$PLATFORM_DIR" ]; then
        TARGET_DIR="$PLATFORM_DIR"
        logInfoMessage "Using platform subdirectory: ${TARGET_DIR}"
    else
        logWarningMessage "Platform directory '${PLATFORM_DIR}' not found"
        logInfoMessage "Using codebase root instead: ${CODEBASE_LOCATION}"
        TARGET_DIR="${CODEBASE_LOCATION}"
    fi
fi

# Verify target directory exists
if [ ! -d "$TARGET_DIR" ]; then
    logErrorMessage "Directory does not exist: ${TARGET_DIR}"
    logInfoMessage "Available directories in workspace:"
    ls -la /bp/workspace/ 2>/dev/null || ls -la / | head -20
    saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
    exit 1
fi

# Navigate to target directory
cd "${TARGET_DIR}"

if [ $? -ne 0 ]; then
    logErrorMessage "Failed to navigate to directory: ${TARGET_DIR}"
    saveTaskStatus 1 ${ACTIVITY_SUB_TASK_CODE}
    exit 1
fi

logInfoMessage "Current directory: $(pwd)"
logInfoMessage ""
logInfoMessage "Directory contents:"
ls -la | head -20

# Check if fastlane directory exists
if [ ! -d "fastlane" ]; then
    logWarningMessage "No 'fastlane' directory found in current location"
    logInfoMessage "Please ensure Fastlane is initialized in your project"
fi

# Function to execute fastlane instruction
execute_fastlane_instruction() {
    logInfoMessage "Executing Fastlane instruction: [$INSTRUCTION]"
    
    fastlane $INSTRUCTION
    TASK_STATUS=$?
    
    if [ $TASK_STATUS -eq 0 ]; then
        logSuccessMessage "Fastlane instruction [$INSTRUCTION] completed successfully!"
    else
        logErrorMessage "Fastlane instruction [$INSTRUCTION] failed with status: $TASK_STATUS"
    fi
    
    return $TASK_STATUS
}

# Function to decode and save Play Store key
decode_playstore_key() {
    if [ ! -z "$KEY" ]; then
        logInfoMessage "Decoding KEY and saving to fastlane/playstore-key.json..."
        
        mkdir -p fastlane
        
        echo "$KEY" | base64 --decode > fastlane/playstore-key.json
        
        if [ $? -eq 0 ]; then
            logSuccessMessage "Successfully decoded and saved playstore key"
            return 0
        else
            logErrorMessage "Failed to decode KEY variable"
            return 1
        fi
    else
        logInfoMessage "No KEY environment variable found, skipping key decode"
        return 0
    fi
}

# Function to execute fastlane supply
execute_fastlane_supply() {
    logInfoMessage "=========================================="
    logInfoMessage " Executing Fastlane Supply"
    logInfoMessage "=========================================="
    
    if [ -z "$PACKAGE_NAME" ]; then
        logErrorMessage "Error: PACKAGE_NAME is required for fastlane supply"
        return 1
    fi
    
    if [ ! -f "${JSON_KEY_PATH}" ]; then
        logErrorMessage "Error: JSON key file not found at ${JSON_KEY_PATH}"
        logInfoMessage "Please ensure the service account key is available"
        return 1
    fi
    
    SUPPLY_CMD="fastlane supply"
    
    if [ "$BUILD_TYPE" = "apk" ]; then
        if [ ! -f "${APK_PATH}" ]; then
            logErrorMessage "Error: APK file not found at ${APK_PATH}"
            logInfoMessage "Available APK files:"
            find . -name "*.apk" -type f || true
            return 1
        fi
        SUPPLY_CMD="${SUPPLY_CMD} --apk ${APK_PATH}"
        logInfoMessage "Using APK: ${APK_PATH}"
    elif [ "$BUILD_TYPE" = "aab" ]; then
        if [ ! -f "${AAB_PATH}" ]; then
            logErrorMessage "Error: AAB file not found at ${AAB_PATH}"
            logInfoMessage "Available AAB files:"
            find . -name "*.aab" -type f || true
            return 1
        fi
        SUPPLY_CMD="${SUPPLY_CMD} --aab ${AAB_PATH}"
        logInfoMessage "Using AAB: ${AAB_PATH}"
    else
        logErrorMessage "Error: Invalid BUILD_TYPE: ${BUILD_TYPE}. Must be 'apk' or 'aab'"
        return 1
    fi
    
    SUPPLY_CMD="${SUPPLY_CMD} --track ${RELEASE_TRACK}"
    logInfoMessage "Release Track: ${RELEASE_TRACK}"
    
    if [ ! -z "$ROLLOUT_PERCENTAGE" ] && [ "$ROLLOUT_PERCENTAGE" != "0" ]; then
        ROLLOUT_DECIMAL=$(echo "scale=2; ${ROLLOUT_PERCENTAGE} / 100" | bc)
        SUPPLY_CMD="${SUPPLY_CMD} --rollout ${ROLLOUT_DECIMAL}"
        logInfoMessage "Rollout Percentage: ${ROLLOUT_PERCENTAGE}%"
    fi
    
    SUPPLY_CMD="${SUPPLY_CMD} --json_key ${JSON_KEY_PATH}"
    SUPPLY_CMD="${SUPPLY_CMD} --package_name ${PACKAGE_NAME}"
    
    logInfoMessage "Package Name: ${PACKAGE_NAME}"
    
    if [ "$SKIP_UPLOAD_SCREENSHOTS" = "true" ]; then
        SUPPLY_CMD="${SUPPLY_CMD} --skip_upload_screenshots true"
    fi
    
    if [ "$SKIP_UPLOAD_IMAGES" = "true" ]; then
        SUPPLY_CMD="${SUPPLY_CMD} --skip_upload_images true"
    fi
    
    if [ "$SKIP_UPLOAD_METADATA" = "true" ]; then
        SUPPLY_CMD="${SUPPLY_CMD} --skip_upload_metadata true"
    fi
    
    logInfoMessage ""
    logInfoMessage "Executing command:"
    logInfoMessage "${SUPPLY_CMD}"
    logInfoMessage ""
    
    eval ${SUPPLY_CMD}
    TASK_STATUS=$?
    
    if [ $TASK_STATUS -eq 0 ]; then
        logSuccessMessage "=========================================="
        logSuccessMessage "Successfully uploaded to ${RELEASE_TRACK}!"
        logSuccessMessage "=========================================="
        if [ ! -z "$ROLLOUT_PERCENTAGE" ] && [ "$ROLLOUT_PERCENTAGE" != "0" ]; then
            logInfoMessage "Rollout: ${ROLLOUT_PERCENTAGE}% of users"
        fi
    else
        logErrorMessage "Fastlane supply failed with status: $TASK_STATUS"
    fi
    
    return $TASK_STATUS
}

# Main execution logic based on FASTLANE_MODE
case "$FASTLANE_MODE" in
    instruction)
        logInfoMessage "Mode: Fastlane Instruction"
        execute_fastlane_instruction
        TASK_STATUS=$?
        
        if [ $TASK_STATUS -eq 0 ]; then
            decode_playstore_key
            TASK_STATUS=$?
        fi
        ;;
    supply)
        logInfoMessage "Mode: Fastlane Supply"
        execute_fastlane_supply
        TASK_STATUS=$?
        ;;

    both)
        logInfoMessage "Mode: Both - Instruction and Supply"       
        execute_fastlane_instruction
        TASK_STATUS=$?
        
        if [ $TASK_STATUS -eq 0 ]; then
            decode_playstore_key
            TASK_STATUS=$?
            
            if [ $TASK_STATUS -eq 0 ]; then
                logInfoMessage ""
                logInfoMessage "Proceeding to upload..."
                execute_fastlane_supply
                TASK_STATUS=$?
            fi
        else
            logErrorMessage "Skipping key decode and supply due to instruction failure"
        fi
        ;;
    *)
        TASK_STATUS=1
        ;;
esac

saveTaskStatus ${TASK_STATUS} ${ACTIVITY_SUB_TASK_CODE}
exit $TASK_STATUS
