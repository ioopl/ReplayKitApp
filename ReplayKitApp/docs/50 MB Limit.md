# 50 MB Limit 
The Broadcast Extension runs as a separate system process with a strict 50MB memory limit.
Running AVAssetWriter inside the extension requires careful memory management. We will leverage
the extension's existing backpressure frame-dropping serial queue to ensure writing frames does
not cause memory leaks or OOM crashes.
