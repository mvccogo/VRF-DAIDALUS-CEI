# VRF-DAIDALUS-CEI
NASA's DAIDALUS implemented in a VR-Forces plug-in.

## Prerequisites 

This plugin was built using the following:
 - VR-Forces 5.0 (Internal Product Build 15)
 - VR-Link 5.8
 - MAK RTI 4.6 MSVC++ 14.0
 - Microsoft Visual Studio 2017, SDK version 10.0.17763.0, platform tools v141

Set the environment variables for VRL and RTI accordingly: MAK_VLRDIR and MAK_RTIDIR, and include MSVC++ directories to build the project properly.


## Usage

### Setting up the plugin

1. Compile NASA's DAIDALUS static library (included in the solution as a VS project named "DAIDALUS-LIB")
2. Compile the VRF plugin as a dynamic library (included in the solution as a VS project named "VRF-DAIDALUS-CEI")
3. Launch VRF and create a new plugin entry (this will create the plugin .xml), link it to the .dll file compiled on step 2.
4. Copy both the .lua file and the .xml file from VRF-scripts to VRF_DIR/data/simulationModelSets/EntityLevel/scripts to add the lua task.
5. Copy the .conf file from VRF-scripts to VRF_DIR/bin64/ to load DAIDALUS's configuration parameters.

### Using the plugin

The Daidalus object is created and initialized for every simulated object. At every tick, traffic data is fed into the object (daa.addTrafficState()). Conflict results and guidance parameters are then used together with VRF subtasks to move the aircraft. 

### Saving changes to Tasks

1. If the task is a system script, simply save the .lua file. The file can then be accessed directly in VRF_DIR/data/simulationModelSets/EntityLevel/scripts.
2. If the task is a scenario script, save the scenario. In order to access the file directly (either the script or the metadata), export the script using the context menu.



## TODOs

- Add some VRF scenarios as examples
- Get input from sensors, not from object list
- Tinker with wrapper 
