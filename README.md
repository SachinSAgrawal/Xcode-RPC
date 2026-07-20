# Xcode RPC

## About
An Custom Rich Presence utility app to display Xcode as your activity on Discord. Other RPC apps already exist, but they come with a few caveats, namely that they rely on AppleScript to poll Xcode. Xcode RPC uses Accessibility APIs which work better and avoids launching Xcode randomly like AppleScript does.

## Acknowledgments
Ths app was fully created by Lakhan Lothiyi, also known as llsc12. I wanted to know how he had Xcode as his Discord RPC after seeing it, and he pointed me towards [his app](https://github.com/llsc12/XRPC). There were a few changes I wanted to make to the app to mainly improve the user interface. Because of the permissive free software license he included, I am publishing my changes on Github. The basic functionality and logic is not mine, however, so almost all of the credit should go to him. 

## Improvements
* This app's icon matches that of the original version.
* There is now the ability to pause and resume connection.
* The menu bar item is now a `NSMenu` instead of a `NSPopover`.
* The setup screen is better laid out for a nicer UI.
* The icon in the menu bar is now a hammer inside a circle.
* It is filled if the RPC is connected and Xcode is open.
* The code is commented with the help of various AI tools.
* Setup and about screens now appear above other windows.
* There is a preview of the activity displayed on Discord.
* A refresh button has been added in case the RPC does not update.
* The menu bar icon's size better matches other icons.
* The appp should no longer be identified as malware by macOS.
* Other various performance improvements and bug fixes.

## Installation
Assuming I did things correctly, check out [Releases](https://github.com/SachinSAgrawal/Xcode-RPC/releases) for the most recent build. Download the `XcodeRPC.zip` (not the source code) and uncompress the folder. Drag it into to the Applications folder and open it from `Launchpad`.

#### Building Yourself
1. Clone this repository or download it as a zip folder and uncompress it.
2. Open up the `.xcworkspace` file, which should automatically launch Xcode.
3. You might need to change the signing of the app from the current one.
4. Under `Product`, click on `Archive`, then distribute it by exporting a copy.
5. Save the archive to the Applications folder and open it from `Launchpad`.

## SDKs
* [SwiftUI](https://developer.apple.com/xcode/swiftui/) - SwiftUI is an innovative, exceptionally simple way to build user interfaces.
* [AXSwift](https://github.com/tmandry/AXSwift) - A basic Swift wrapper for easier accessibility client APIs made by Tmandry.
* [SwordRPC](https://github.com/Azoy/SwordRPC) - A Discord Rich Presence Library pod for Swift made by Azoy.
* [Cocoa](https://cocoapods.org/) - A dependency manager for Swift and Objective-C Cocoa projects.
* [Swift](https://developer.apple.com/swift/) - A powerful and intuitive programming language for all Apple platforms.

## Bugs
If you find any, you are welcome to open up a new issue here, however, since I really didn't code this app, I would recommend opening one on llsc12's repository. 

#### Known
- [x] Some file types do not display an icon.
- [x] Presence is always one scrape cycle (2s) stale.
- [x] A stale SwordRPC instance spuriously marks you disconnected.
- [x] The "no windows open" state is never actually reported.
- [x] Malformed data from Discord or a presence that was never set can crash the app.
- [x] A message split across two reads permanently desyncs the connection.
- [x] Files without an extension, or ones like `contents.xcworkspacedata`, show the wrong type.
- [x] The elapsed timer keeps counting from the previous project after switching.
- [x] A failed connection attempt reuses a dead socket.

## Contributors
Lakhan Lothiyi: Original creator of XRPC and developer of DeltaTube. Go check him out! <br>
Sachin Agrawal: I'm a self-taught programmer who knows many languages and I'm into app, game, and web development. For more information, check out my website or Github profile. If you would like to contact me, my email is [github@sachin.email](mailto:github@sachin.email).

## License
This package is licensed under the [MIT License](LICENSE.txt).
