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


-- Possible states:
-- Starting
-- moving: moving to destination
-- maneuvering: avoiding an aircraft
taskId = -1

myState = "starting"

-- Task Parameters Available in Script
--  taskParameters.destination Type: Location3D - Move to location destination.
destination = taskParameters.position

-- Called when the task first starts. Never called again.
function init()
   daidalus:luaExamplePrintMessage("Starting up Daidalus")
   local ret = daidalus:reloadConfig()
   --daidalus:setHorVerNMAC(250, 100)
   --daidalus:setLookaheadTime(180.0)
   -- Set up wind configuration
   local loc3d = this:getLocation3D()
   local wind_dir = vrf:getWindDirection(loc3d)
   local wind_speed = vrf:getWindSpeed(loc3d)
   
   local wind_vect = Vector3D(0,0,0)
   wind_vect:setBearingInclRange(wind_dir, 0, wind_speed)
   
   --daidalus:setWindVelocityTo(wind_vect:getEast(), wind_vect:getNorth() , -wind_vect:getDown())
   
   -- Set the tick period for this script.
   vrf:setTickPeriod(0.5)
   
   -- Check destination 
   if (destination == nil) then
      printWarn("Daidalus startup: no destination?\n")
      vrf:endTask(false)
      return
   end
   
   
   -- Get destination altitude, then subtrack it from goal altitude if available
   local nHAT = 0
   local dAlt, bAvailable = vrf:getTerrainAltitude(destination:getLat(), destination:getLon())
   
   if (bAvailable) then
      nHAT = destination:getAlt() - dAlt
   end
   
   
   -- Skip subordinates for now
--~    for idx,sub in ipairs(subordinates) do
--~       local subLocation = sub:getLocation3D()
--~       local offset = this:getLocation3D():vectorToLoc3D(subLocation)

--~       if (sub:isDestroyed() == false) then
--~          subOffsets[sub:getUUID()] = offset;
--~          subGoals[sub:getUUID()] = destination:addVector3D(subOffsets[sub:getUUID()]):makeCopy()

--~          local goalAlt, bFound = vrf:getTerrainAltitude(subGoals[sub:getUUID()]:getLat(), subGoals[sub:getUUID()]:getLon())

--~          if (bAvailable and bFound) then
--~             goalAlt = goalAlt + nHAT
--~          else
--~             goalAlt = destination:getAlt()
--~          end
--~          
--~          subGoals[sub:getUUID()]:setAlt(goalAlt)
--~       end   
--~    end
--~    
   

end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   
   
   
   
   -- Add this object to ownship
   
   local loc3d = this:getLocation3D()
   local vel = this:getVelocity3D()
   local time = vrf:getSimulationTime()
   
   daidalus:setOwnshipState(this:getName(), loc3d:getLat(), loc3d:getLon(), loc3d:getAlt(), vel:getEast(), vel:getNorth(), -vel:getDown(), time)
   
   local objs = vrf:getVrfObjects()
   
   
   -- Iterate over all simulated objects, add their traffic states.
   for i, obj in ipairs(objs) do
      if obj:isValid() == true then
         local type = obj:getEntityType()
         type = type.sub(type, type.find(type,":")+1, type.find(type,":")+1)
         if type == "2" and this:getUUID() ~= obj:getUUID() then
            local loc3d_obj = obj:getLocation3D()
            local vel_obj = obj:getVelocity3D()
            local id = daidalus:addTrafficState(obj:getName(), loc3d_obj:getLat(), loc3d_obj:getLon(), loc3d_obj:getAlt(), vel_obj:getEast(), vel_obj:getNorth(), -vel_obj:getDown(), -1)  
            end
      
      end

   end
   
   local aircraftNo = daidalus:numberOfAircraft()
   for i, obj in ipairs(objs) do
      if obj:isValid() == true then
         local id = daidalus:aircraftIndex(obj:getName())
         if id ~= -1 and id ~= 0 then
            local timeToConflict = daidalus:getDetectionTime(id)
            daidalus:luaExamplePrintMessage("time to conflict with "..obj:getName()..": "..timeToConflict)
            
         end
      end
   end

   if (myState == "starting") then 
      if (this:isDestroyed() == false) and (destination ~= nil) then
      local params = {
            position = taskParameters.position,
            keepAltitude = 1,
            altitude = 304.8,
            heading = 90,
            keepSpeed = 0,
            speed = 250,
            lateralAcceleration = 1}

         taskId = vrf:startSubtask("fly_to_position_and_heading", params)
         myState = "moving-to-goal"
      end
   end
   
   if (myState == "moving-to-goal") then
      if(this:isDestroyed() == false) then
         local resBands = daidalus:getResolutionDirection()
         daidalus:luaExamplePrintMessage("res. dir!!:"..resBands)
         if (resBands == resBands) then
            local params = {
               allow_task_visualizations = true,
               heading = resBands*3.1415/180,
               use_magnetic = false,
               turn_rate = 0.05
            }
            vrf:stopSubtask(taskId)
            taskId = vrf:startSubtask("fly-heading", params)
            myState = "avoiding-aircraft"
         end
      end
   end
   
   if (myState == "avoiding-aircraft") then
      if (this:isDestroyed() == false) then
      for i, obj in ipairs(objs) do
         if obj:isValid() == true then
            local id = daidalus:aircraftIndex(obj:getName())
            if id ~= -1 and id ~= 0 then
               local timeToConflict = daidalus:getDetectionTime(id)
               if (timeToConflict ~= 1/0) then
                  myState = "moving-to-goal"
               else
                  myState = "starting"
               end
               
            end
      end
   end
      end
   end
   
   
   
   
   daidalus:getHorizontalDirectionBands()
   daidalus:luaExamplePrintMessage("daidalus tick: "..daidalus:getCurrentTime())
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
