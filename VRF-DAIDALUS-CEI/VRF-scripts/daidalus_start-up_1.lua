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

prev_heading = -1
alerting_time = daidalus:getAlertingTime()
maneuvering = false

severity_table = {}

daidalus_on = taskParameters.daidalusOn
delay_timestamp = -1


trafficID = -1
-- Possible states:
-- starting: setting up destination
-- moving-to-goal: moving to destination
-- maneuvering: avoiding an aircraft

moving_taskId = -1
fly_heading_taskid = -1

lost_wellclear = false
preferred_direction_set = false
is_right = false

myState = "starting"

-- Task Parameters Available in Script
--  taskParameters.destination Type: Location3D - Move to location destination.
destination = taskParameters.position

-- Called when the task first starts. Never called again.
function init()
   daidalus:luaExamplePrintMessage("Starting up Daidalus")
   local ret = daidalus:reloadConfig()

   
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
   

end

-- Called each tick while this task is active.
function tick()
   -- endTask() causes the current task to end once the current tick is complete. tick() will not be called again.
   -- Wrap it in an appropriate test for completion of the task.
   
   
   -- Check for task completion
   if (myState == "starting" or not daidalus_on) and vrf:isSubtaskComplete(moving_taskId) then
      writeToFile("severity.txt")
      vrf:endTask(false)
      --vrf:finishTest(0, "Scenario 1 simulation completed.")
      return
   end
   
   -- Add this object to ownship
   local loc3d = this:getLocation3D()
   local vel = this:getVelocity3D()
   local time = vrf:getSimulationTime()
   
   daidalus:setOwnshipState(this:getName(), loc3d:getLat(), loc3d:getLon(), loc3d:getAlt(), vel:getEast(), vel:getNorth(), -vel:getDown(), time)
   
   local objs = vrf:getVrfObjects()
 
   -- Iterate over all aerial simulated objects, add their traffic states.
   for i, obj in ipairs(objs) do
      if obj:isValid() == true then
         local type = obj:getEntityType()
         type = type.sub(type, type.find(type,":")+1, type.find(type,":")+1)
         if type == "2" and this:getUUID() ~= obj:getUUID() then
            local loc3d_obj = obj:getLocation3D()
            local vel_obj = obj:getVelocity3D()
            trafficID = daidalus:addTrafficState(obj:getName(), loc3d_obj:getLat(), loc3d_obj:getLon(), loc3d_obj:getAlt(), vel_obj:getEast(), vel_obj:getNorth(), -vel_obj:getDown(), -1)  
            end
      
      end

   end
   
   -- print time to conflict for every aircraft
   local aircraftNo = daidalus:numberOfAircraft()
   for i, obj in ipairs(objs) do
      if obj:isValid() == true then
         local id = daidalus:aircraftIndex(obj:getName())
         if id ~= -1 and id ~= 0 then
            local timeToConflict = daidalus:getDetectionTime(id)
            if timeToConflict < 1e-3 then 
               lost_wellclear = true
            end
         
         end
      end
   end

   -- Set original destination 
   if (myState == "starting") then 
      if (this:isDestroyed() == false) and (destination ~= nil) then
      local params = {
            position = taskParameters.position,
            keepAltitude = 1,
            altitude = taskParameters.altitude,
            heading = taskParameters.finalHeading,
            keepSpeed = 1,
            speed = this:getOrderedSpeed(),
            lateralAcceleration = 1}
         
         if not vrf:isSubtaskRunning(moving_taskId) then
            vrf:stopSubtask(fly_heading_taskid)
            if taskParameters.isFixedWing == true then
               moving_taskId = vrf:startSubtask("fly_to_position_and_heading", params)
            else
               local pos = taskParameters.position
               --local pos_with_altitude = pos:setAlt(taskParameters.altitude)
               moving_taskId = vrf:startSubtask("move-to-location", {aiming_point = pos, speed = this:getOrderedSpeed()})
            end
            myState = "moving-to-goal"
            --delay_timestamp = -1
         end
      end
   end
   
   -- start avoiding aircraft
   local resBands = -1
   
   -- Create heading direction
   prev_heading = math.deg(loc3d:vectorToLoc3D(taskParameters.position):getBearing())
   
   
   if (myState == "moving-to-goal" and daidalus_on == true) then
      if(this:isDestroyed() == false) then
         if not preferred_direction_set then
            preferred_direction_set = true
            is_right = daidalus:isPreferredRight()
         end
         resBands = daidalus:getResolutionDirection(is_right)
         if (resBands == -2) then
            -- No conflict.
            resBands = -1
         end
         if (resBands ~= -1) then
            -- Resolution maneuver was found, apply it after the delay.
            if delay_timestamp == -1 then delay_timestamp = time end
            if time - delay_timestamp > taskParameters.resolutionDelay then
               local params = {
                  allow_task_visualizations = true,
                  heading = math.rad(resBands),
                  use_magnetic = false,
                  turn_rate = math.rad(12)
               }
               vrf:stopSubtask(moving_taskId)
               fly_heading_taskid = vrf:startSubtask("fly-heading", params)
               myState = "avoiding-aircraft"
            end
         else 
            -- todo: remove this if check, no longer needed.
            if maneuvering ==  true then
               myState = "avoiding-aircraft"
            end
         end
      end
      
   end
   
   
   if resBands == -1 then
      daidalus:luaExamplePrintMessage("Aircraft not in conflict")
   else
      daidalus:luaExamplePrintMessage("Resolution maneuver for current conflict:"..resBands)
   end
   
   
   if (myState == "avoiding-aircraft") then
      if (this:isDestroyed() == false) then
      
         -- "Wrapper" start
         local CPA = daidalus:isDirectionInConflict(prev_heading, time)
         local new_alerting = -1
         if (CPA > 1e8 or CPA == 0) then
            CPA = alerting_time
         end
         if(CPA > alerting_time) then
            new_alerting = CPA
         else
            if(daidalus:getAlertingTime() > CPA) then
               new_alerting = math.max(alerting_time, CPA)
            else
               new_alerting = daidalus:getAlertingTime()
            end
         end
         daidalus:setAlertingTime(new_alerting)
         -- "Wrapper" end
         
         local timeToConflict = daidalus:isDirectionInConflict(prev_heading, time)
         if (timeToConflict < 1e8) then
            myState = "moving-to-goal"
            maneuvering = true
            daidalus:luaExamplePrintMessage("Original heading still has conflicts, keep maneuvering around them. (Time2Conflict:"..timeToConflict)
         else
            daidalus:luaExamplePrintMessage("Original heading has no conflicts, resume navigation")
            myState = "starting"
         end
      end
   end
   
   --daidalus:getHorizontalDirectionBands()
   calcAndSetSeverity()
end


function calcAndSetSeverity()
      local RangePen = getRangePen(trafficID)
      local HMDPen = getHMDPen(trafficID)
      local VertPen = getVertPen(trafficID)
      if lost_wellclear == false then 
         table.insert(severity_table, -1)
      else
         table.insert(severity_table, getSeverity(RangePen, HMDPen, VertPen))
      end
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


-- Batch analysis utilities

-- Horizontal Proximity (tau MOD)

function getRangePen(idx)
   r_i = daidalus:getHorizontalDistance(idx)
   rdot_i = daidalus:getClosureRate(true, idx)
   --rdot_i = math.abs(rdot_i)
   local DTHR = 180 -- Meters
   local taumod = 0
   local taumod_test = daidalus:getModifiedTau(DTHR,idx)
   --taumod = taumod_test
   local b = 0.5*math.sqrt((rdot_i * taumod)^2 + 4*DTHR^2) - rdot_i*taumod
   local S_i = math.max(DTHR, b)
   return math.min(r_i/S_i, 1)
  
end


-- Horizontal Miss-distance Projection (HMD)

function getHMDPen(idx)
   local DTHR = 180
   return math.min(daidalus:getHMD(idx)/DTHR, 1)
end

-- Vertical Distance

function getVertPen(idx)
   local dh_i = daidalus:getRelativeAltitude(idx)
   local ZTHR = 91
   return math.min(dh_i/ZTHR, 1)
end


-- Norm operator

function norm(a,b)
   return ((a*a) + (b*b) - (a*a*b*b))^0.5
end

-- Severity calculation

function getSeverity(RangePen, HMDPen, VertPen)
   local a = norm(RangePen,HMDPen)
   local b = norm(a, VertPen)
   SLoWC_i = (1 - norm(norm(RangePen,HMDPen), VertPen)) * 100
   return SLoWC_i
end

-- Write severity to file
function writeToFile(file)
   local file = io.open("C:\\Users\\matheusmc\\Documents\\GitHub\\VRF-DAIDALUS-CEI\\VRF-DAIDALUS-CEI\\VRF-scripts\\Scenario4\\"..file, "a")
   io.output(file)
   
   local max_sev = 0
   local current_fuel, total_fuel = this:getResourceAmounts("movement|fuel")
   for i,k in pairs(severity_table) do
      if k == -1 then
         max_sev = -1
      elseif k > max_sev then
         max_sev = k
      end
   end
   
   io.write(max_sev..","..(total_fuel-current_fuel).."\n")
   
   io.close(file)
end
