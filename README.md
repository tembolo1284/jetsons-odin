# jetsons-odin
Lock-free streaming audio pipeline in Odin: 23 wave files through File -> Coordinator -> PlayBack -> 20 wave buffers using only atomics, SPSC rings, and hand-rolled futex/ulock wait-notify.
