-- >>>> Task documentation here <<<<

-- This script template has each of the script entry point functions.
-- They are described in detail in VR-Forces Users Guide.

-- Some basic VRF Utilities defined in a common module.
require "vrfutil"

-- Global Variables
--
-- Global variables get saved when a scenario gets checkpointed in one of
-- the folowing ways:
-- 1) If the checkpoint mode is AllGlobals, all global variables in the script 
--   will be saved as part of the save state. To get this mode, call
--   vrf:setCheckpointMode(AllGlobals).
-- 2) If the checkpoint mode is CheckpointStateOnly, the script will *only* 
--    save variables that are part of the checkpointState table.  
--    To get this mode, call vrf:setCheckpointMode(CheckpointStateOnly).
--    Example: 
--    checkpointState.importantNumber = 42
vrf:setCheckpointMode(CheckpointStateOnly)

-- Task Parameters Available in Script


-- Called when the task first starts. Never called again.
function init()
   daidalus:luaExamplePrintMessage("Starting up Daidalus")
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   
   
   
   
   -- Add this object to ownship
   
   local loc3d = this.getLocation3D(this)
   local vel = this.getVelocity3D(this)
   
   daidalus:setOwnshipState(this.getName(this), loc3d.getLat(loc3d), loc3d.getLon(loc3d), loc3d.getAlt(loc3d), vel.getNorth(vel), vel.getEast(vel), vel.getDown(vel), 0)
   
   
   local objs = vrf:getVrfObjects()
   
   for i, obj in ipairs(objs) do
      if obj.isValid(obj) == true then
         local type = obj.getEntityType(obj)
         type = type.sub(type, type.find(type,":")+1, type.find(type,":")+1)
         if type == "2" and this.getUUID(this) ~= obj.getUUID(obj) then
            local loc3d_obj = obj.getLocation3D(obj)
            local vel_obj = obj.getVelocity3D(obj)
            local id = daidalus:addTrafficState(obj.getName(obj), loc3d_obj.getLat(loc3d_obj), loc3d_obj.getLon(loc3d_obj), loc3d_obj.getAlt(loc3d_obj), vel_obj.getNorth(vel_obj), vel_obj.getEast(vel_obj), vel_obj.getDown(vel_obj), 0)
            daidalus:luaExamplePrintMessage(""..obj.getName(obj))   
      end
      
      end

   end
   
   --daidalus:setOwnshipState(
   
   
   --vrf:endTask(true)
end


-- Called when this task is being suspended, likely by a reaction activating.
function suspend()
   -- By default, halt all subtasks and other entity tasks started by this task when suspending.
   vrf:stopAllSubtasks()
   vrf:stopAllTasks()
end

-- Called when this task is being resumed after being suspended.
function resume()
   -- By default, simply call init() to start the task over.
   init()
end

-- Called immediately before a scenario checkpoint is saved when
-- this task is active.
-- It is typically not necessary to add code to this function.
function saveState()
end

-- Called immediately after a scenario checkpoint is loaded in which
-- this task is active.
-- It is typically not necessary to add code to this function.
function loadState()
end

-- Called when this task is ending, for any reason.
-- It is typically not necessary to add code to this function.
function shutdown()
end

-- Called whenever the entity receives a text report message while
-- this task is active.
--   message is the message text string.
--   sender is the SimObject which sent the message.
function receiveTextMessage(message, sender)
end
