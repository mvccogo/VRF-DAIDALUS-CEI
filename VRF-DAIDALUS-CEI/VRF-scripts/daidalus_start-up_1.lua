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

daidalus_on = true
daidalus_delay = 0

-- Possible states:
-- starting: setting up destination
-- moving-to-goal: moving to destination
-- maneuvering: avoiding an aircraft

moving_taskId = -1
fly_heading_taskid = -1




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
   vrf:setTickPeriod(0.33)
   
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
   if myState == "starting" and vrf:isSubtaskComplete(moving_taskId) then
      writeToFile("severity.txt")
      vrf:endTask(false)
      vrf:finishTest(0, "Scenario 1 simulation completed.")
      return
   end
   
   
   
   for i,k in pairs(severity_table) do
      --daidalus:luaExamplePrintMessage(""..i..","..k[1])
   end
   
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
   
   -- print time to conflict for every aircraft
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

   -- Set original destination 
   if (myState == "starting") then 
      if (this:isDestroyed() == false) and (destination ~= nil) then
      local params = {
            position = taskParameters.position,
            keepAltitude = 0,
            altitude = taskParameters.altitude,
            heading = taskParameters.finalHeading,
            keepSpeed = 0,
            speed = taskParameters.cruiseSpeed,
            lateralAcceleration = 1}
         
         if not vrf:isSubtaskRunning(moving_taskId) then
            vrf:stopSubtask(fly_heading_taskid)
            moving_taskId = vrf:startSubtask("fly_to_position_and_heading", params)
            myState = "moving-to-goal"
         end
      end
   end
   
   -- start avoiding aircraft
   local resBands = -1
   
   -- Create heading direction
   prev_heading = math.deg(loc3d:vectorToLoc3D(taskParameters.position):getBearing())
   
   
   if (myState == "moving-to-goal" and daidalus_on == true) then
      if(this:isDestroyed() == false) then
         resBands = daidalus:getResolutionDirection()
         if (resBands == resBands) then
            local params = {
               allow_task_visualizations = true,
               heading = math.rad(resBands),
               use_magnetic = false,
               turn_rate = math.rad(3)
            }
            vrf:stopSubtask(moving_taskId)
            fly_heading_taskid = vrf:startSubtask("fly-heading", params)
            myState = "avoiding-aircraft"
         else
            resBands = -1
            if maneuvering ==  true then
               myState = "avoiding-aircraft"
            end
         end
      end
      
   end
   
   if (myState == "avoiding-aircraft") then
      if (this:isDestroyed() == false) then
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
         daidalus:luaExamplePrintMessage("Setting new alerting time: "..new_alerting.."s")
         daidalus:setAlertingTime(new_alerting)
         local timeToConflict = daidalus:isDirectionInConflict(prev_heading, time)
         if (timeToConflict < 1e8) then
            daidalus:luaExamplePrintMessage("Still in conflict, keep maneuvering...")
            myState = "moving-to-goal"
            maneuvering = true
         else
            daidalus:luaExamplePrintMessage("Not in conflict, restart navigation")
            myState = "starting"
         end
      end
   end
   
   
   calcAndSetSeverity()
end


function calcAndSetSeverity()
      local RangePen = getRangePen(1)
      daidalus:luaExamplePrintMessage("RangePen: "..RangePen)
      local HMDPen = getHMDPen(1)
      daidalus:luaExamplePrintMessage("HMDPen: "..HMDPen)
      local VertPen = getVertPen(1)
      daidalus:luaExamplePrintMessage("VertPen: "..VertPen)
      table.insert(severity_table, getSeverity(RangePen, HMDPen, VertPen))
      daidalus:luaExamplePrintMessage("severity: "..getSeverity(RangePen, HMDPen, VertPen))
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
   local DTHR = 656.168
   local taumod = 20
   local b = 0.5*math.sqrt((rdot_i * taumod)*(rdot_i * taumod) + 4*DTHR*DTHR) - rdot_i*taumod
   local S_i = math.max(DTHR, b)
   return math.min(r_i/S_i, 1)
end


-- Horizontal Miss-distance Projection (HMD)

function getHMDPen(idx)
   r_i = daidalus:getHorizontalDistance(idx)
   dx, dy, vrx, vry = daidalus:getHorizontalMissDistanceParams(idx)
   local t_CPA = (-dx*vrx+dy*vrx)/(vrx*vrx + vry*vry)
   local DTHR = 656.168
   local HMD_i
   if t_CPA > 0 then
   HMD_i = math.sqrt((dx + vrx*t_CPA)*(dx + vrx*t_CPA) + (dy + vry*t_CPA)*(dy + vry*t_CPA))   
   else
   HMD_i = r_i
   end
   return math.min(HMD_i/DTHR, 1)
end

-- Vertical Distance 

function getVertPen(idx)
   local dh_i = daidalus:getRelativeAltitude(idx)
   local ZTHR = 450
   return math.min(dh_i/ZTHR, 1)
end


-- Norm operator

function norm(a,b)
   return math.sqrt(a*a + b*b - a*a*b*b)
end

-- Severity calculation

function getSeverity(RangePen, HMDPen, VertPen)
   SLoWC_i = (1 - norm(norm(RangePen,HMDPen), VertPen)) * 100
   return SLoWC_i
end

-- Write severity to file
function writeToFile(file)
   local file = io.open("C:\\Users\\matheusmc\\Documents\\GitHub\\VRF-DAIDALUS-CEI\\VRF-DAIDALUS-CEI\\VRF-scripts\\Scenario1\\"..file, "a")
   io.output(file)
   
   local max_sev = 0
   
   for i,k in pairs(severity_table) do
      if k > max_sev then
         max_sev = k
      end
   end
   
   io.write(max_sev.."\n")
   
   io.close(file)
end
