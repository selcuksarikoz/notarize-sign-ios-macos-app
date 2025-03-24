#!/bin/bash

# Script to check if an app is signed on macOS and sign it if needed
# Usage: ./check_app_signature.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Prompt for application path
read -p "Please enter the path to the application you want to check: " APP_PATH

# Check if the path exists
if [ ! -e "$APP_PATH" ]; then
    echo -e "${RED}Error: '$APP_PATH' not found.${NC}"
    exit 1
fi

# Check if the path is a directory (applications are folders in macOS)
if [ ! -d "$APP_PATH" ]; then
    echo -e "${YELLOW}Warning: '$APP_PATH' is not a directory. macOS applications are typically directories with .app extension.${NC}"
fi

echo -e "${YELLOW}Checking application signature information: $APP_PATH${NC}"
echo "----------------------------------------"

# Get basic signature information
SIGNATURE_INFO=$(codesign -vv -d "$APP_PATH" 2>&1)
SIGNATURE_STATUS=$?

NEEDS_SIGNING=false
NEEDS_NOTARIZATION=false

if [ $SIGNATURE_STATUS -eq 0 ]; then
    echo -e "${GREEN}✅ Application is signed.${NC}"
    
    # Extract and display signature details
    echo -e "\n${YELLOW}Signature Details:${NC}"
    echo "$SIGNATURE_INFO"
    
    # Check for more detailed info about the signature
    echo -e "\n${YELLOW}Detailed Signature Information:${NC}"
    codesign --display --verbose=4 "$APP_PATH" 2>&1
    
    # Verify the signature
    echo -e "\n${YELLOW}Signature Verification:${NC}"
    codesign --verify --verbose "$APP_PATH" 2>&1
    VERIFY_STATUS=$?
    
    if [ $VERIFY_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Signature verified.${NC}"
    else
        echo -e "${RED}❌ Signature verification failed!${NC}"
        NEEDS_SIGNING=true
    fi
    
    # Check notarization status (for newer macOS versions)
    echo -e "\n${YELLOW}Notarization Check:${NC}"
    spctl --assess --verbose=4 --type=execute "$APP_PATH" 2>&1
    NOTARIZED_STATUS=$?
    
    if [ $NOTARIZED_STATUS -eq 0 ]; then
        echo -e "${GREEN}✅ Application is notarized (approved by Apple).${NC}"
    else
        echo -e "${RED}❌ Application is not notarized!${NC}"
        NEEDS_NOTARIZATION=true
    fi
    
else
    echo -e "${RED}❌ Application is not signed or signature is invalid!${NC}"
    echo -e "\n${YELLOW}Error message:${NC} $SIGNATURE_INFO"
    NEEDS_SIGNING=true
    NEEDS_NOTARIZATION=true
fi

# If app needs signing or notarization, offer to do it
if [ "$NEEDS_SIGNING" = true ] || [ "$NEEDS_NOTARIZATION" = true ]; then
    echo -e "\n${YELLOW}=== Signing and Notarization Operations ===${NC}"
    
    if [ "$NEEDS_SIGNING" = true ]; then
        echo -e "${YELLOW}Application needs to be signed.${NC}"
        read -p "Do you want to sign the application? (y/n): " SIGN_CHOICE
        
        if [[ $SIGN_CHOICE == "y" || $SIGN_CHOICE == "Y" ]]; then
            # Ask for developer information
            read -p "Apple Developer Identity (e.g., 'Developer ID Application: Name (TEAM_ID)'): " DEV_IDENTITY
            
            echo -e "${YELLOW}Signing the application...${NC}"
            # Remove any existing signature first
            codesign --remove-signature "$APP_PATH" 2>/dev/null
            
            # Sign the application
            codesign --force --options runtime --deep --sign "$DEV_IDENTITY" "$APP_PATH" 2>&1
            SIGN_RESULT=$?
            
            if [ $SIGN_RESULT -eq 0 ]; then
                echo -e "${GREEN}✅ Application signed successfully.${NC}"
            else
                echo -e "${RED}❌ Signing operation failed!${NC}"
                exit 1
            fi
        else
            echo -e "${YELLOW}Signing operation cancelled by user.${NC}"
            exit 0
        fi
    fi
    
    if [ "$NEEDS_NOTARIZATION" = true ]; then
        echo -e "${YELLOW}Application needs to be notarized.${NC}"
        read -p "Do you want to notarize the application? (y/n): " NOTARIZE_CHOICE
        
        if [[ $NOTARIZE_CHOICE == "y" || $NOTARIZE_CHOICE == "Y" ]]; then
            # Ask for Apple ID information
            read -p "Apple ID email: " APPLE_ID
            read -s -p "App-specific password: " APP_PASSWORD
            echo ""
            read -p "Team ID (found in Apple Developer portal): " TEAM_ID
            
            # Create a temporary zip file for submission
            TEMP_ZIP="/tmp/app_to_notarize.zip"
            echo -e "${YELLOW}Preparing application for notarization...${NC}"
            ditto -c -k --keepParent "$APP_PATH" "$TEMP_ZIP"
            
            # Submit for notarization
            echo -e "${YELLOW}Submitting application to Apple for notarization...${NC}"
            xcrun notarytool submit "$TEMP_ZIP" --apple-id "$APPLE_ID" --password "$APP_PASSWORD" --team-id "$TEAM_ID" --wait
            NOTARIZE_RESULT=$?
            
            # Clean up the temporary zip
            rm -f "$TEMP_ZIP"
            
            if [ $NOTARIZE_RESULT -eq 0 ]; then
                # Staple the notarization ticket to the app
                echo -e "${YELLOW}Stapling notarization ticket to the application...${NC}"
                xcrun stapler staple "$APP_PATH"
                STAPLE_RESULT=$?
                
                if [ $STAPLE_RESULT -eq 0 ]; then
                    echo -e "${GREEN}✅ Application successfully notarized and ticket stapled.${NC}"
                else
                    echo -e "${RED}❌ Ticket stapling failed!${NC}"
                fi
            else
                echo -e "${RED}❌ Notarization process failed!${NC}"
            fi
        else
            echo -e "${YELLOW}Notarization process cancelled by user.${NC}"
        fi
    fi
    
    # Final verification after signing/notarization
    echo -e "\n${YELLOW}=== Final Checks ===${NC}"
    echo -e "${YELLOW}Checking application signature status:${NC}"
    codesign --verify --verbose "$APP_PATH"
    
    echo -e "\n${YELLOW}Application Gatekeeper check:${NC}"
    spctl --assess --verbose=4 --type=execute "$APP_PATH"
else
    echo -e "\n${GREEN}✅ Application is fully signed and notarized. No further action required.${NC}"
fi

exit 0