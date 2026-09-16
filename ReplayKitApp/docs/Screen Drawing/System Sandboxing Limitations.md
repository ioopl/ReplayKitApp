## System Sandboxing Limitations:

Q: When I switch to different App while System Wide Screen Recording to do the Screen record the newly added Screen Drawing is not there? When I switch to other apps while recording like outlook or photos app or any app the compositing or drawing does not work at all. The drawing options are not even there - they are only available and work when I am only inside our main ReplayKitApp
Q: So the App does start the drawing and shows the drawing features when the user is in the App but when I switch to the externals apps the Drawing controls are not visible over external apps? is it due to iOS sandboxing. Fun fact 1 in the existing recent implementation : the existing drawing remains burned into the recorded MP4 which is nice but is there no way we can also show the Drawing controls too when we are in external apps. Fun fact 2: the recorded individual Frames - don't show the Drawn drawing over them like in individual Frames - but as I said they are shown in the MP4 but just not on individual recorded and encrypted frames. Is that an expected behaviour?

## Expected Behaviour:

- Correct—the drawing toolbar cannot appear over Outlook, Photos, or other apps on iOS. Only the system-owned app is interactive; ReplayKitApp is no longer on the display.

- The existing drawing remains burned into the recorded MP4.
- Drawing controls are unavailable over external apps due to iOS sandboxing.
- Interactive drawing over another app requires iPad Split View/Slide Over or the future in-app browser mode.

👉 Yes—this is due to iOS sandboxing. A third-party app cannot display interactive windows, PencilKit controls, or touch overlays above Outlook, Photos, Safari, or the Home Screen. The Broadcast Upload Extension is also headless and cannot create UI.

## Possible Solution: 
