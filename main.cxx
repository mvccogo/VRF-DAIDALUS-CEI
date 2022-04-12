/*******************************************************************************
** Copyright (c) 2012 MAK Technologies, Inc.
** All rights reserved.
*******************************************************************************/

//VR-Forces includes
#include "VRF-DAIDALUS-CEI/DaidalusCEI.h"



void DaidalusCEI::isDirectionInConflict(double& result, double direction, double time /* direction in degrees */)
{
	// We must set the previous direction to the ownship, add all the trafic for that state, then clean-up to the original state
	larcfm::Position pos = daa.getOwnshipState().getPosition();
	larcfm::Velocity vel = daa.getOwnshipState().getVelocity();
	double gs = vel.groundSpeed("knot");
	larcfm::Velocity vel_conflict = larcfm::Velocity::makeTrkGsVs(direction, gs, 0);

	// Save all traffic
	std::vector<larcfm::TrafficState> states;
	for (int i = 1; i < daa.numberOfAircraft(); i++) {
		if (daa.getAircraftStateAt(i).isValid()) {
			larcfm::TrafficState ts;
			memcpy(&ts, &daa.getAircraftStateAt(i), sizeof(larcfm::TrafficState));
			states.push_back(ts);
		}
	}
	std::string ido(daa.getOwnshipState().getId());
	// Clear traffic by adding new ownship position
	daa.setOwnshipState(ido, pos, vel_conflict, time);

	// Add back all traffic 
	for (auto i : states) {
		daa.addTrafficState(i.getId(), i.getPosition(), i.getVelocity());
	}
	
	// Now, check if this direction has a conflict. 

	double time_to_violation;
	double result_temp = MAXDOUBLE;
	for (int i = 1; i < daa.numberOfAircraft(); i++) {
		getDetectionTime(time_to_violation, i);
		if (time_to_violation != PINFINITY) {
			result_temp = daa.timeToHorizontalClosestPointOfApproach(i) <= result_temp ? daa.timeToHorizontalClosestPointOfApproach(i) : result_temp;
		}
	}
	result = result_temp;

	// Now, set the original state back.

	daa.setOwnshipState(ido, pos, vel, time);

	for (auto i : states) {
		daa.addTrafficState(i.getId(), i.getPosition(), i.getVelocity());
	}
}



void DaidalusCEI::setAlertingTime(bool& bUpdated, double time) {
	larcfm::ParameterData param = daa.getParameterData();
	bUpdated = param.set("DWC_Phase_I_alert_3_alerting_time", time, "s");

}

void DaidalusCEI::getAlertingTime(double& time) {
	larcfm::ParameterData param = daa.getParameterData();
	time = param.getValue("DWC_Phase_I_alert_3_alerting_time");
}


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
	larcfm::Position pos = larcfm::Position::makeLatLonAlt(lat,"rad", lon,"rad", alt, "m");
	larcfm::Velocity vel = larcfm::Velocity::makeVxyz(velx, vely, "m/s",velz,"m/s");
	daa.setOwnshipState(ido, pos, vel, to);
}


void DaidalusCEI::addTrafficState(int& aci_idx, std::string idi, double lat, double lon, double alt, double velx, double vely, double velz, double to) {
	larcfm::Position pos = larcfm::Position::makeLatLonAlt(lat, "rad", lon, "rad", alt, "m");
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
		.def("getHorizontalDirectionBands", &DaidalusCEI::getHorizontalDirectionBands)
		.def("setAlertingTime", &DaidalusCEI::setAlertingTime,
			luabind::pure_out_value(_2))
		.def("getAlertingTime", &DaidalusCEI::getAlertingTime,
			luabind::pure_out_value(_2))
		.def("getResolutionDirection", &DaidalusCEI::getResolutionDirection,
			luabind::pure_out_value(_2))
		.def("isDirectionInConflict", &DaidalusCEI::isDirectionInConflict,
			luabind::pure_out_value(_2))
		.def("getClosureRate", &DaidalusCEI::getClosureRate,
			luabind::pure_out_value(_2))
		.def("getHorizontalDistance", &DaidalusCEI::getHorizontalDistance,
			luabind::pure_out_value(_2))
		.def("getHorizontalMissDistanceParams", &DaidalusCEI::getHorizontalMissDistanceParams,
			luabind::pure_out_value(_2) + luabind::pure_out_value(_3) + luabind::pure_out_value(_4) + luabind::pure_out_value(_5))
		.def("getRelativeAltitude", &DaidalusCEI::getRelativeAltitude,
			luabind::pure_out_value(_2))
		.def("getTime2CPA", &DaidalusCEI::getTime2CPA,
			luabind::pure_out_value(_2))
		.def("getHMD", &DaidalusCEI::getHMD,
			luabind::pure_out_value(_2))
		.def("getModifiedTau", &DaidalusCEI::getModifiedTau,
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
	}

static std::string num2str(double res, const std::string& u) {
	if (!ISFINITE(res)) {
		return "N/A";
	}
	else {
		return larcfm::Fm2(res) + " [" + u + "]";
	}
}

void DaidalusCEI::getResolutionDirection(double& trackOrHeading) {
	if (daa.preferredHorizontalDirectionRightOrLeft()) {
		trackOrHeading = daa.horizontalDirectionResolution(true, "deg");
	}
	else {
		trackOrHeading = daa.horizontalDirectionResolution(false, "deg");
	}
}



void DaidalusCEI::getHorizontalDirectionBands() {
	// Horizontal Direction
	larcfm::TrafficState own = daa.getOwnshipState();
	bool nowind = daa.getWindVelocityTo().isZero();
	std::string hdstr = nowind ? "Track" : "Heading";
	std::string hsstr = nowind ? "Ground Speed" : "Airspeed";

	std::vector<std::string> acs;
	for (int regidx = 1; regidx <= larcfm::BandsRegion::NUMBER_OF_CONFLICT_BANDS; ++regidx) {
		larcfm::BandsRegion::Region region = larcfm::BandsRegion::regionFromOrder(regidx);
		daa.conflictBandsAircraft(acs, region);
		std::string s;
		s << "Conflict Aircraft for Bands Region " << larcfm::BandsRegion::to_string(region) << ": " << larcfm::TrafficState::listToString(acs);
		printMessage(s);
	}

	double hd_deg = own.horizontalDirection("deg");
	std::string s;
	s << "Ownship " << hdstr << ": " << larcfm::Fm2(hd_deg) << " [deg]";
	s << "Region of Current " << hdstr << ": " <<

		larcfm::BandsRegion::to_string(daa.regionOfHorizontalDirection(hd_deg, "deg"));
	s << hdstr << " Bands [deg,deg]";
	printMessage(s);

	for (int i = 0; i < daa.horizontalDirectionBandsLength(); ++i) {
		larcfm::Interval ii = daa.horizontalDirectionIntervalAt(i, "deg");
		s.clear();

		s << "  " << larcfm::BandsRegion::to_string(daa.horizontalDirectionRegionAt(i)) << ":\t" << ii.toString(2);
		printMessage(s);
	}
	for (int regidx = 1; regidx <= larcfm::BandsRegion::NUMBER_OF_CONFLICT_BANDS; ++regidx) {
		larcfm::BandsRegion::Region region = larcfm::BandsRegion::regionFromOrder(regidx);
		daa.peripheralHorizontalDirectionBandsAircraft(acs, region);
		s.clear();
		s << "Peripheral Aircraft for " << hdstr << " Bands Region " << larcfm::BandsRegion::to_string(region) << ": " <<
			larcfm::TrafficState::listToString(acs);
		printMessage(s);
	}
	s.clear();
	s << hdstr << " Resolution (right): " << num2str(daa.horizontalDirectionResolution(true, "deg"), "deg");
	printMessage(s);
	s.clear();
	s << hdstr << " Resolution (left): " << num2str(daa.horizontalDirectionResolution(false, "deg"), "deg");
	printMessage(s);
	s.clear();
	s << "Preferred " << hdstr << " Direction: ";
	if (daa.preferredHorizontalDirectionRightOrLeft()) {
		s << "right";
	}
	else {
		s << "left";
	}
	printMessage(s);
	s.clear();
	s << "Recovery Information for Horizontal Speed Bands:";
	printMessage(s);
	larcfm::RecoveryInformation recovery = daa.horizontalDirectionRecoveryInformation();
	std::cout << "  Time to Recovery: " <<
		larcfm::Units::str("s", recovery.timeToRecovery()) << std::endl;
	std::cout << "  Recovery Horizontal Distance: " <<
		larcfm::Units::str("nmi", recovery.recoveryHorizontalDistance()) << std::endl;
	std::cout << "  Recovery Vertical Distance: " <<
		larcfm::Units::str("ft", recovery.recoveryVerticalDistance()) << std::endl;

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
