# VKB
Quick and dirty mouse and keyboard forwarding.

## First and foremost, the Caveats

* No throttling. Rapid mouse movements can cause lag.
* It's not secure. Quartz events are forwarded across the network using Distributed Objects, which means your keystrokes and mouse movements could be logged.
* Mouse forwarding only works well if both computers have the same display resolution.
* It's quick.
* It's dirty.
* There is little to no error handling.
* There are probably memory leaks.

## How the heck do I use it?
Don't.

If you must, `vkbd.m` is the server (to be run on the computer you want to forward input to) and `vkb-client.m` is the client. Both compile to command-line tools. Link against the Cocoa framework.

Once the server is running, run the client with `vkb-client HOST` where _HOST_ is the server you want to connect to. `fn-ESC` toggles mouse and keyboard forwarding. Your local mouse pointer may continue to move when forwarding is enabled, but applications won't notice a thing.

If you're having trouble following along, vkb is probably too dangerous for you. I wasn't kidding when I said don't. It's going to be a gaping security hole on a shared network.

## So, what good is it?
I like to use my old MacBook to play music and watch LiveStream while I do other things on the new one. Now I don't have to lean over to interact with it.

## Hacking and snacking.
I consider this trivial shit. It's public domain. But feel free to send me yr sweet hax if you manage to improve on my undesign.
