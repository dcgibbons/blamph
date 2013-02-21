BLAMPH
======

Blamph is chat client for the ICB chat system (see http://www.icb.net/ for 
more information about the system) native to Mac OS X. Blamph currently
provides a simple textual interface to ICB as most of the users of this
chat network use command-line clients.

Blamph is modeled off of my ICB chat client named IcyBee that is implemented
in Java and that can be found at https://github.com/dcgibbons/icybee - as
Java has fallen out of Java for client-side applications, it made sense to me
to develop a native version that would work well with modern OS X features,
such as the retina display.

USING BLAMPH
------------

While Blamph is open source, the final application is available on the Mac
App Store. If you are interested in using Blamph, visit your Mac App Store
and give it go!

DEVELOPMENT
-----------

If you are interested in working with Blamph, either to add features or fix
bugs, here's what you need to know:

1. Check out the Blamph project from https://github.com/dcgibbons/blamph

2. Blamph depends upon a variety of submodules within its deps subdirectory.
   Perform the following to check them out:
````
    git submodule init
    git submodule update
````

3. Open up the Blamph project in Xcode. Or, if you prefer to build from the
   command-line:
````
    xcodebuild -scheme Blamph -sdk macosx10.8 archive
````

If you wish to make any changes to Blamph, please fork the repository on
github and create a topic branch for your changes before submitting your
pull request.
