/*******************************************************************************
** Copyright (c) 2012 MAK Technologies, Inc.
** All rights reserved.
*******************************************************************************/

//VR-Forces includes
#include "vrfcgf/vrfPluginExtension.h"
#include "vrfLua/luaScriptInterfaceImpl.h"
#include "vrfLua/luaObjectSerializer.h"
#include "vrfobjcore/localObject.h"
#include "luabind/out_value_policy.hpp"

//! This class will be used to bind Lua functions to.  The example is provided for
//! a single function, however, many functions can be added to the bind
class AddLuaFunctionInterfaceExtension : public DtLuaScriptInterfaceExtension
{
public:
   //! CTOR
   AddLuaFunctionInterfaceExtension()
   {
   }

   //! DTOR
   virtual ~AddLuaFunctionInterfaceExtension()
   {
   }

   // Creator function.
   static DtLuaScriptInterfaceExtension* create(void* usr)
   {
      // In this example, the usr pointer is unused.
      return new AddLuaFunctionInterfaceExtension;
   }

   //! Called from the lua script this method will print a message
   virtual void printMessage(const std::string& message)
   {
      DtWarn << myEntity->objectName().string() << ": " << message.c_str() << std::endl;
      myEntity->objectConsoleInfo() << message << std::endl;
   }

   //! This function is an example of binding a function with multiple return values.
   //! The function call in lua itself will be similar to the following:
   //! local stringReturn, intReturn, boolReturn = example:luaExampleMultiReturn(true)
   //! This will result in the 3 variables having the values as such:
   //! stringReturn = "return string", intReturn = 40, boolReturn = true
   //! You will notice that the function call only has the first bool in it. Specifying
   //! the other arguments will result in the function call not working since these are
   //! out parameters only.
   //! To see how it is bound, see the .def below.
   virtual std::string multipleReturn(bool b, int& someNumber, bool& success)
   {
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

   bool alreadyInitialized(lua_State* L, const char* moduleName) const
   {
      luabind::object obj = luabind::globals(L)["example"];

      if (luabind::type(obj) != LUA_TNIL)
      {
         return true;
      }

      return false;
   }

   //! Binds method for this class to the lua state.  This simple method will
   //! send an object console message to the entity that implements this task
   virtual void bindLuaFunctions(DtLocalObject* entity, const DtString& scriptId,
      lua_State* L)
   {
      // Since this initialization get called twice in some instances (due to lua table changes when loading a scenario)
      // check to make sure this is not already initialized
      if (alreadyInitialized(L, "example"))
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
            luabind::class_<AddLuaFunctionInterfaceExtension>("AddLuaFunctionInterfaceExtension")
               .def("luaExamplePrintMessage", 
                  &AddLuaFunctionInterfaceExtension::printMessage)
               .def("luaExampleMultiReturn", &AddLuaFunctionInterfaceExtension::multipleReturn,
                      luabind::pure_out_value(_3) + luabind::pure_out_value(_4))
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
      DtLuaObjectSerializer::instance()->addKeyToIgnore("example");
   }

protected:
   DtLocalObject*   myEntity;
};

extern "C" {

   DT_VRF_DLL_PLUGIN void DtPluginInformation(DtVrfPluginInformation& info)
   {
      info.pluginName = "DAIDALUS";
      info.pluginDescription = "NASA's DAIDALUS SAA method implemented as a VRF plugin";
      info.pluginVersion = "1.00";
      info.pluginCreator = "Matheus V. C. Cogo";
      info.pluginCreatorEmail = "matheus.cogo@unesp.br";
      info.pluginContactWebPage = "";
      info.pluginContactMailingAddress = "";
      info.pluginContactPhone = "+55 14981830802";
   }

   DT_VRF_DLL_PLUGIN bool DtPostInitializeVrfPlugin(DtCgf* cgf)
   {
      DtLuaScriptInterfaceImpl::addLuaScriptInterfaceExtension(AddLuaFunctionInterfaceExtension::create, 0);
      return true;
   }

   DT_VRF_DLL_PLUGIN void DtUnloadVrfPlugin()
   {
      DtLuaScriptInterfaceImpl::removeLuaScriptInterfaceExtension(AddLuaFunctionInterfaceExtension::create, 0);
   }
}

