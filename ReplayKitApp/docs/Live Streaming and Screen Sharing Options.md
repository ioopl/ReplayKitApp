#  Live Streaming 

In a production environment, instead of writing frames to a local file, the Broadcast Extension streams the encoded video/audio frames to a server:

1. Twitch/YouTube Live: Both platforms ingest streams using RTMP (Real-Time Messaging Protocol). You would use an RTMP library (like HaishinKit) inside SampleHandler to encode the frame sequence into H.264/AAC and push it directly to their server ingestion URL using a Twitch/YouTube Stream Key (obtained by signing up to their developer console).

2. Custom Screen Share/WebRTC: For peer-to-peer screen sharing (like Zoom/Discord), you would integrate a WebRTC iOS SDK. Each captured video frame buffer is fed into WebRTC's video capturer class (RTCVideoCapturer), which automatically handles WebRTC network packets.
