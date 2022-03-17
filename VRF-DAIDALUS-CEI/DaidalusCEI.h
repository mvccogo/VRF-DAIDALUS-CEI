#pragma once
#include "vrfcgf/vrfPluginExtension.h"
#include "vrfLua/luaScriptInterfaceImpl.h"
#include "vrfLua/luaObjectSerializer.h"
#include "vrfobjcore/localObject.h"
#include "luabind/out_value_policy.hpp"
#include "NASA-DAIDALUS/C++/include/Daidalus.h"


//! This class will be used to bind Lua functions to.  The example is provided for
//! a single function, however, many functions can be added to the bind
class DaidalusCEI : public DtLuaScriptInterfaceExtension
{

public:
	DaidalusCEI() : daa() {
		if (!daa.loadFromFile("daidalus_params.conf")) {
			daa.set_DO_365A();
		}
	}

	virtual ~DaidalusCEI() {}

	static DtLuaScriptInterfaceExtension* create(void* usr) {
		return new DaidalusCEI;
	}


	virtual void setOwnshipState(std::string ido, double lat, double lon, double alt, double vx, double vy, double vz, double to);

	virtual void addTrafficState(int& aci_idx, std::string idi, double lat, double lon, double alt, double vx, double vy, double vz, double to);

	virtual void getDetectionTime(double& time_to_violation, int ac_idx);

	inline virtual void setWindVelocityTo(double vx, double vy, double vz) {
		larcfm::Velocity vel((vx, vy, vz));
		daa.setWindVelocityTo(vel);
	}
	inline virtual void setWindVelocityFrom(double vx, double vy, double vz) {
		larcfm::Velocity vel((vx, vy, vz));
		daa.setWindVelocityFrom(vel);
	}


	inline virtual void setHorizontalPositionUncertainty(int ac_idx, double s_EW, double s_NS, double s_EN, const std::string& xy_units)
	{
		daa.setHorizontalPositionUncertainty(ac_idx, s_EW, s_NS, s_EN, xy_units);
	}
	inline virtual void setVerticalPositionUncertainty(int ac_idx, double sz, const std::string& z_units)
	{
		daa.setVerticalPositionUncertainty(ac_idx, sz, z_units);
	}
	inline virtual void setHorizontalVelocityUncertainty(int ac_idx, double v_EW, double v_NS, double v_EN, const std::string& vxy_units)
	{
		daa.setHorizontalVelocityUncertainty(ac_idx, v_EW, v_NS, v_EN, vxy_units);
	}
	inline virtual void setVerticalSpeedUncertainty(int ac_idx, double vz, const std::string& vz_units)
	{
		daa.setVerticalSpeedUncertainty(ac_idx, vz, vz_units);
	}

	inline virtual void aircraftIndex(int& ac_idx, const std::string& id)
	{
		ac_idx = daa.aircraftIndex(id);
	}

	inline virtual void numberOfAircraft(int& no)
	{
		no = daa.numberOfAircraft();
	}

	inline virtual void lastTrafficIndex(int& index)
	{
		index = daa.lastTrafficIndex();
	}

	inline virtual void getCurrentTime(double& time)
	{
		time = daa.getCurrentTime();
	}


	virtual void printMessage(const std::string& message);

	//! This function is an example of binding a function with multiple return values.
   //! The function call in lua itself will be similar to the following:
   //! local stringReturn, intReturn, boolReturn = example:luaExampleMultiReturn(true)
   //! This will result in the 3 variables having the values as such:
   //! stringReturn = "return string", intReturn = 40, boolReturn = true
   //! You will notice that the function call only has the first bool in it. Specifying
   //! the other arguments will result in the function call not working since these are
   //! out parameters only.
   //! To see how it is bound, see the .def below.
	virtual std::string multipleReturn(bool b, int& someNumber, bool& success);

	bool alreadyInitialized(lua_State* L, const char* moduleName) const;


	//! Binds method for this class to the lua state.  This simple method will
	//! send an object console message to the entity that implements this task
	virtual void bindLuaFunctions(DtLocalObject* entity, const DtString& scriptId, lua_State* L);

protected:
	DtLocalObject*			myEntity;
	larcfm::Daidalus		daa;

};

extern "C" {
	DT_VRF_DLL_PLUGIN void DtPluginInformation(DtVrfPluginInformation& info)
	{
		info.pluginName = "DAIDALUS";
		info.pluginDescription = "NASA's DAIDALUS SAA/DAA method implemented as a VRF plug-in";
		info.pluginVersion = "0.1";
		info.pluginCreator = "Matheus V. C. Cogo";
		info.pluginCreatorEmail = "matheus.cogo@unesp.br";
		info.pluginContactWebPage = "";
		info.pluginContactMailingAddress = "";
		info.pluginContactPhone = "+55 14981830802";
	}


	DT_VRF_DLL_PLUGIN bool DtInitializeVrfPlugin(DtCgf* cgf)
	{
		return true;

	}

	DT_VRF_DLL_PLUGIN bool DtPostInitializeVrfPlugin(DtCgf* cgf)
	{
		DtLuaScriptInterfaceImpl::addLuaScriptInterfaceExtension(DaidalusCEI::create, 0);
		return true;
	}

	DT_VRF_DLL_PLUGIN void DtUnloadVrfPlugin()
	{
		DtLuaScriptInterfaceImpl::removeLuaScriptInterfaceExtension(DaidalusCEI::create, 0);
	}
}