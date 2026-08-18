# Question: But why are we importing Photos in the ViewModel (SystemWideScreenBroadcastViewModel), isn't that breaking our MVVM architecture, we should be following that and keep all the UI logic separately, should this be in a Service Layer actually which the ViewModel is dependency injected?

#  chatGPT/AI: Yes—you’re right. PHPhotoLibrary is an infrastructure concern, not ViewModel logic. I’ll move Photos persistence behind an injected service protocol, keep the ViewModel responsible only for orchestration/state, and preserve the existing permission/error behavior.

