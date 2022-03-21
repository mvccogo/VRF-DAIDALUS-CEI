/*******************************************************************************
** Copyright (c) 2012 MAK Technologies, Inc.
** All rights reserved.
*******************************************************************************/

//VR-Forces includes
#include "VRF-DAIDALUS-CEI/DaidalusCEI.h"




void DaidalusCEI::reloadConfig(bool& ret) {
	if (daa.loadFromFile("daidalus_params.conf")) {
		// Default configuration parameters
		ret = true;
		printMessage("Successfully reloaded configuration for Daidalus obj...");
	}
	else {
		printMessage("Failed to reload configuration!");
		ret = false;
	}
}

void DaidalusCEI::setOwnshipState(std::string ido, double lat, double lon, double alt, double velx, double vely, double velz, double to)
{
	larcfm::Position pos = larcfm::Position::makeLatLonAlt(lat,"rad", lon,"rad", alt, "meters");
	larcfm::Velocity vel = larcfm::Velocity::makeVxyz(velx, vely, "m/s",velz,"m/s");
	daa.setOwnshipState(ido, pos, vel, to);
}


void DaidalusCEI::addTrafficState(int& aci_idx, std::string idi, double lat, double lon, double alt, double velx, double vely, double velz, double to) {
	larcfm::Position pos = larcfm::Position::makeLatLonAlt(lat, "rad", lon, "rad", alt, "meters");
	larcfm::Velocity vel = larcfm::Velocity::makeVxyz(velx, vely, "m/s", velz, "m/s");

	if (to != -1)
		aci_idx = daa.addTrafficState(idi, pos, vel, to);
	else
		aci_idx = daa.addTrafficState(idi, pos, vel);
}


void DaidalusCEI::getDetectionTime(double& time_to_violation, int ac_idx) {
	time_to_violation = daa.timeToCorrectiveVolume(ac_idx);
}

void DaidalusCEI::printMessage(const std::string& message) {
	DtWarn << myEntity->objectName().string() << ": " << message.c_str() << std::endl;
	myEntity->objectConsoleInfo() << message << std::endl;
}


std::string DaidalusCEI::multipleReturn(bool b, int& someNumber, bool& success) {
	if (b)
	{
		someNumber = 40;
		success = true;
	}
	else
	{
		someNumber = 10;
		success = false;
	}
	return "return string";
}

bool DaidalusCEI::alreadyInitialized(lua_State* L, const char* moduleName) const {
	luabind::object obj = luabind::globals(L)[moduleName];

	if (luabind::type(obj) != LUA_TNIL)
	{
		return true;
	}

	return false;
}


void DaidalusCEI::bindLuaFunctions(DtLocalObject* entity, const DtString& scriptId, lua_State* L) {
	// Since this initialization get called twice in some instances (due to lua table changes when loading a scenario)
	  // check to make sure this is not already initialized
	if (alreadyInitialized(L, "daidalus"))
	{
		return;
	}

	myEntity = entity;

	//! This will bind the lua method "printMessage" to an object that can be
	//! referenced by the name "example" as well as the multiple return function example.
	//! Note that each function bound works off of each other .def()
	luabind::module(L)
		[
			//! Use luabind to bind class functions for lua implementation
			luabind::class_<DaidalusCEI>("AddLuaFunctionInterfaceExtension")
			.def("luaExamplePrintMessage",
				&DaidalusCEI::printMessage)
		.def("luaExampleMultiReturn", &DaidalusCEI::multipleReturn,
			luabind::pure_out_value(_3) + luabind::pure_out_value(_4))
		.def("setOwnshipState", &DaidalusCEI::setOwnshipState)
		.def("addTrafficState", &DaidalusCEI::addTrafficState, 
			luabind::pure_out_value(_2))
		.def("getDetectionTime", &DaidalusCEI::getDetectionTime,
			luabind::pure_out_value(_2))
		.def("setWindVelocityTo", &DaidalusCEI::setWindVelocityTo)
		.def("setWindVelocityFrom", &DaidalusCEI::setWindVelocityFrom)
		.def("setHorizontalPositionUncertainty", &DaidalusCEI::setHorizontalPositionUncertainty)
		.def("setVerticalPositionUncertainty", &DaidalusCEI::setVerticalPositionUncertainty)
		.def("setHorizontalVelocityUncertainty", &DaidalusCEI::setHorizontalVelocityUncertainty)
		.def("setVerticalSpeedUncertainty", &DaidalusCEI::setVerticalSpeedUncertainty)
		.def("aircraftIndex", &DaidalusCEI::aircraftIndex,
			luabind::pure_out_value(_2))
		.def("numberOfAircraft", &DaidalusCEI::numberOfAircraft,
			luabind::pure_out_value(_2))
		.def("lastTrafficIndex", &DaidalusCEI::lastTrafficIndex,
			luabind::pure_out_value(_2))
		.def("getCurrentTime", &DaidalusCEI::getCurrentTime,
			luabind::pure_out_value(_2))
		.def("setHorVerNMAC", &DaidalusCEI::setHorVerNMAC)
		.def("setLookaheadTime", &DaidalusCEI::setLookaheadTime)
		.def("reloadConfig", &DaidalusCEI::reloadConfig,
			luabind::pure_out_value(_2))
		//! The multiple return function requires you to specify which arguments are used to return.
		//! Here, the indexes start at _2 for the first argument in the function. Our sample function
		//! has the first out value in the argument slot _3. We also have a second out argument at slot
		//! _4 so we need to use the + with the two out values. It is recommended that if you want in values
		//! to also be out values, you make separate arguments for each in and each out value.
		];

	//! Bind this object to the object "example".  Reference methods for this object in lua by
	//! calling "example:<method_name>"
	luabind::globals(L)["daidalus"] = this;

	//! We want to be able to recreate this global from the plugin whenever we load.
	//! Tell the DtLuaObjectSerializer to ignore this object so that it is not saved
	//! with the scenario.
	DtLuaObjectSerializer::instance()->addKeyToIgnore("daidalus");
	printMessage("Daidalus plug-in was loaded for entity: " + std::string(myEntity->objectName()) + "\n");
	if (bConfigFileFound) {
		printMessage("Loaded config file");
	}
	else {
		printMessage("Could not load config file, defaulting to DO 365A");
	}
	}


////! This is defined for all plugins so the plugin manager can retrieve the version that this plugin was built
////! against to use to check against the version the application is running against
//#ifdef BUILDING_PLUGIN
//
//#include "vrfutil/version.h"
//#include <vlutil/vlString.h>
//
//extern "C" {
//	DT_VRF_DLL_PLUGIN void DtPluginVersion(DtString& version)
//	{
//		version = PLUGIN_COMPATIBLE_VERSION;
//
//#ifdef WIN32
//#ifdef NDEBUG
//		version += " Release";
//#else
//		version += " Debug";
//#endif
//#endif
//	}
//}
//
//#endif
