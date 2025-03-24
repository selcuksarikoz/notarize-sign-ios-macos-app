#!/bin/bash

# Script to notarize a macOS application
# Usage: ./notarize_app.sh /path/to/YourApp.app

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if an argument was provided or prompt for app path
if [ $# -eq 0 ]; then
    read -p "Enter the path to your application (.app): " APP_PATH
else
    APP_PATH="$1"
fi

# Check if the app exists
if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: Application not found at '$APP_PATH'${NC}"
    exit 1
fi

# Prompt for Apple ID credentials
echo -e "${BLUE}======= Apple ID Information =======${NC}"
read -p "Enter your Apple ID email: " APPLE_ID
read -s -p "Enter your app-specific password: " APP_PASSWORD
echo ""
read -p "Enter your Team ID: " TEAM_ID

# Extract app name without path and extension
APP_NAME=$(basename "$APP_PATH" .app)
ZIP_PATH="/tmp/${APP_NAME}.zip"

echo -e "\n${YELLOW}======= STEP 1: Creating ZIP archive =======${NC}"
echo -e "Creating ZIP archive of ${APP_PATH}..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to create ZIP archive.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ ZIP archive created at $ZIP_PATH${NC}"

echo -e "\n${YELLOW}======= STEP 2: Submitting for notarization =======${NC}"
echo -e "This may take several minutes. Please wait..."
SUBMISSION_OUTPUT=$(xcrun notarytool submit "$ZIP_PATH" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" --wait 2>&1)
SUBMISSION_STATUS=$?

if [ $SUBMISSION_STATUS -ne 0 ]; then
    echo -e "${RED}Error: Notarization submission failed.${NC}"
    echo -e "${RED}Output: $SUBMISSION_OUTPUT${NC}"
    # Cleanup
    rm -f "$ZIP_PATH"
    exit 1
fi

# Extract submission ID for reference
SUBMISSION_ID=$(echo "$SUBMISSION_OUTPUT" | grep -o "id: [a-z0-9-]\+" | head -1 | cut -d ' ' -f 2)
echo -e "${GREEN}✅ Notarization submitted successfully.${NC}"
echo -e "Submission ID: $SUBMISSION_ID"

# Check if notarization succeeded
if echo "$SUBMISSION_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}Notarization completed successfully!${NC}"
else
    echo -e "${RED}Notarization failed or is pending.${NC}"
    echo -e "${YELLOW}Full output:${NC}\n$SUBMISSION_OUTPUT"
    
    # Optionally get notarization log for debugging
    if [ ! -z "$SUBMISSION_ID" ]; then
        echo -e "\n${YELLOW}Getting detailed notarization log...${NC}"
        xcrun notarytool log "$SUBMISSION_ID" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID"
    fi
    
    # Cleanup
    rm -f "$ZIP_PATH"
    exit 1
fi

echo -e "\n${YELLOW}======= STEP 3: Stapling the ticket =======${NC}"
echo -e "Stapling notarization ticket to ${APP_PATH}..."
xcrun stapler staple "$APP_PATH"
STAPLE_STATUS=$?

if [ $STAPLE_STATUS -ne 0 ]; then
    echo -e "${RED}Error: Failed to staple ticket.${NC}"
    # Cleanup
    rm -f "$ZIP_PATH"
    exit 1
fi
echo -e "${GREEN}✅ Notarization ticket stapled successfully.${NC}"

# Final verification
echo -e "\n${YELLOW}======= Final Verification =======${NC}"
echo -e "Verifying application signature and notarization status..."
spctl --assess --verbose=4 --type=execute "$APP_PATH"
VERIFY_STATUS=$?

if [ $VERIFY_STATUS -eq 0 ]; then
    echo -e "\n${GREEN}✅ SUCCESS: Your application is now properly signed and notarized!${NC}"
else
    echo -e "\n${RED}⚠️ WARNING: Verification failed. The application may not be properly notarized.${NC}"
fi

# Cleanup
echo -e "\n${YELLOW}Cleaning up temporary files...${NC}"
rm -f "$ZIP_PATH"
echo -e "${GREEN}Done!${NC}"

exit 0