#  I am onto this part as per your suggestions and and done A, B, C, D however I reaise the part E can't be done as the Broadcast Upload Extension target is not added yet? how do I do that


## Step 0: Create the App Groups

```
Xcode Configuration Guide
To configure the App Groups and compile the Broadcast Extension target in Xcode, follow these steps:

1. Setup App Groups Entitlements
A) Select the main ReplayKitApp project in the file navigator.
B) Go to the Signing & Capabilities tab of the ReplayKitApp target.
C) Click + Capability and search for App Groups.
D) Add a new App Group named group.com.apkia.replaykitapp.shared-group (matching the ID declared in SharedKeychainManager).
E) Repeat this step for your Broadcast Upload Extension target, checking the exact same checkbox for group.com.apkia.replaykitapp.shared-group.
Note: To share keychain items, also add the Keychain Sharing capability under the same group if you configure a custom keychain service identifier.
```

## Step 1: Create the Broadcast Extension Target

```
1. Open your project in Xcode.
2. In the top menu, select File ➔ New ➔ Target...
3. In the template sheet that appears, select iOS at the top.
4. Search for or scroll down to the Application Extension section and select Broadcast Upload Extension, then click Next.
5. Configure the options:
    Product Name: BroadcastExtension
    Organization Identifier: com.example (or your company identifier)
    Language: Swift
    Include UI Extension: Uncheck this box (we only need the Upload Extension, which handles the raw buffer processing in the background. A UI extension is only needed if you want a custom setup screen before streaming). ✅ (Note: I included it)
6. Click Finish.
7. If Xcode asks you to activate the scheme for the new target, click Activate.
```

## Step 2: Link the Shared Code Files

```
Xcode will automatically create a default SampleHandler.swift inside a new folder named BroadcastExtension.

Since we have already written a high-performance, optimized version of SampleHandler.swift and KeychainService.swift (which contains SharedKeychainManager), we need to link them:

1. Locate the default SampleHandler.swift that Xcode just created inside the BroadcastExtension folder and delete it (move it to trash).
2. Now, select our custom SampleHandler.swift in the file navigator (located under the ReplayKitApp folder).
3. Open the Inspectors panel on the right side of Xcode (File Inspector, first tab).
4. Under the Target Membership section, check the box next to BroadcastExtension (ensure it is checked for both ReplayKitApp and BroadcastExtension).
5. Select KeychainService.swift in the file navigator. 
6. Under Target Membership, check the box next to BroadcastExtension here as well (so the extension target has access to the shared keychain logic).
```
