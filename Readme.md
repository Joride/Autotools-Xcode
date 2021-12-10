# Configuring, building and debugging libexif, an autotools configured project, using Xcode.

## Requirements
- a mac computer with brew installed (https://brew.sh/index_nl)
- autotools:
> `brew install autoconf automake libtool`
- Xcode (at the time of writing this, Xcode 13.0/13.1 were used
- Xcode project with 'Debug' and / or 'Release' configuration in build settings. If there are different names for the configuration, pre-actions.sh needs to be adapted to it. These names affect whether or not the library will be built with debugging information ('-g3' option will provided to 'cc' compiler).


## Prepare files and folders
1. Create a container folder that will contain:
	* a directory in which the Xcode project and related files will live
		- this directory should contain a pre-actions script (can be obtained here: ...)
	* a directory for the libexif code
	* a directory containing the built libexif
	* a configure script specific for use with this libexif (can be obtained here: ...)

2. inside that container folder, run:
> `git clone https://github.com/libexif/libexif.git && cd libexif && autoreconf -i`
> `curl configure-xcrun.sh`

3. inside the 'applications' directory run:
> `curl pre-actions.sh`

4. Create a project using Xcode
Choose for the location that container dir

The directory structure now should look like this:
- <container dir>
| - (dir) applications
|	| - <project-name>.xcodeproj
|	| - (dir) <project-name>
|	| - pre-actions.sh
|	| - ...
| - (dir) libexif
|	| - README
|	| - AUTHORS
|	| - ...
| - configure-xcrun.sh


## Setting up the project in Xcode to build libexif
1. In Xcode, select the Project Navigator and then select the project. Select the target that needs to include the libexif library
2. Click on one of the build schemes, and select 'Edit Scheme' from the dropdown.
3. Unfold the 'Build' section on the left, and click 'pre-actions'. Click on the '+' and select 'New Run Script Action'
4. From the dropdown menu preceded by 'Provide build settings from', select the project (instead of 'None', which is the default)
5. Clear the textfield (where it says: "# Type a script or drag a script file from your workspace to insert its path."), and copy and paste the following:
"$SRCROOT/pre-actions.sh" >> "$SRCROOT/pre-action.log" 2>&1
6. Build. N.b. this build *will fail*. This is expected.
The build has caused this script to run, and in turn has caused libexif to be built and a symlink to be added to the 'applications' directory. Now we can continue updating some build settings.


## Setting up the project in Xcode to use libexif
1. In Xcode, select the Project Navigator and then select the project. Select the target that needs to include the libexif library
2. Select the 'Build Settings' tab add to 'Header Search Paths' (HEADER_SEARCH_PATHS) the 'include' path behind that 'libexif-build-active' symlink within the 'applications' directory: "$(SRCROOT)/libexif-build-active/include".
3. While still in 'Build Settings' tab, add to 'Library Search Paths' (LIBRARY_SEARCH_PATHS) the 'lib' path behind that 'libexif-build-active' symlink within the 'applications' directory: "$(SRCROOT)/libexif-build-active/lib"
N.b. double check these two paths above: the MUST include the symlink! Dragging from the Finder will actually use the hard path, so be careful.
4. Select the 'Build Phases' tab, and unfold 'Link Binary With Libraries'. Click the '+' and select 'Add Other' -> 'Add Files'. Browse via the symlink to the libexif.a file in the 'lib' directory.
5. Build and run ✔.
Every build will output / replace the `pre-actions.log` file inside the 'applications' director. It contains output from 'pre-actions.sh', and 'configure-xcrun.sh'  (which calls through ot 'configure' and some 'make' commands).


## Setting up the project in Xcode to be able to debug libexif
N.b. to get Xcode to index the libexif files and be able to jump to definitions, create new target, and these files to it. No need to every build this taraget. It is just there to trigger Xcode into triggering indexing. Not strictly required, but it will make live considerably more convenient.

Drag the folder ../applications/libexif/libexif/ into Xcode. N.b! Make sure to unselect 'Create external build system project', 'Copy items if needed' is unchecked and select 'Create groups' (and not 'Create folder references'). Don't add to any target.
You can then remove all non .h and non .c files (but this is not required)
Break points set in these .c files using Xcode will be hit (provided a 'Debug' build is done, 'Release' will not build the library with debugger information).

Joride - 9 Dec 2021