#  Wi-Fi Aware (A2) is the newer, modern technology, introduced as a direct P2P standard via the Wi-Fi Aware framework and Network.framework extensions. While MultipeerConnectivity (A1) has been the workhorse since iOS 7, it is built on legacy stack layers that abstract away direct socket and transport-level controls.  

# For a media pipeline, go with the architecture approach of (Wi-Fi Aware via Network Framework) as the primary target, while keeping a pluggable transport layer to fallback on MultipeerConnectivity (optional as this is deprecated by Apple!)

