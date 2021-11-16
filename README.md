# DefiChain Masternode Signer

This Project is supposed to helper Masternode Owners to create the signings for DFIPs and CFPs.

## HowTo

 1. Run the Application
 2. Run the Desktop Wallet
 3. Enter the RPC Auth Info of your local Wallet
 4. Click "Load Masternodes"
 5. Select your votes for the DFIPs and CFPs
 6. Click Sign
 7. Copy and Paste the Result into Github


## Building on MacOS
```
flutter build macos --build-name=0.5 --build-number 5 --verbose --release
create-dmg \
      --volname "saiive-MN-Signer" \
      --window-pos 200 120 \
      --window-size 800 529 \
      --icon-size 130 \
      --text-size 14 \
      --icon "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024 08.26.38.png" 260 250 \
      --hide-extension "DefiChain Masternode Signer.app" \
      --app-drop-link 540 250 \
      --hdiutil-quiet \
      "saiive MN Signer.dmg" \
      "build/macos/Build/Products/Release/DefiChain Masternode Signer.app"
```