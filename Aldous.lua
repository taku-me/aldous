-- Tree with Note Progression, Interval Control, LFOs, Revival Mechanism, and Demo Mode
engine.name = 'PolyPerc'

local DEMO_MODE = true  -- Set to true to activate demo mode

local WIDTH = 128
local HEIGHT = 64
local GROW_INTERVAL = 0.2
local ANIMATION_FPS = 17
local MIN_BRANCH_INTERVAL = 0.2
local MAX_BRANCHES = 14
local MAX_ACTIVE_BRANCHES = 10
local MIN_BRIGHTNESS = 3
local MAX_BRIGHTNESS = 15
local GRADIENT_LENGTH = 30
local RIPPLE_DURATION = 120
local BOOST_DURATION = 2
local BOOST_FACTOR = 4
local REVIVAL_INTERVAL = 30 -- seconds

local DEMO_CYCLE_DURATION = 90  -- Duration of each demo cycle in seconds
local DEMO_DECAY_INTERVAL = 0.5  -- Interval between branch removals during decay
local DEMO_PAUSE_DURATION = 10  -- Duration of pause after decay

local tree = {branches = {}}
local ripples = {}
local branch_timer = 0
local next_branch_time = 0
local active_branch_count = 0

local demo_timer = 0
local demo_state = "growing"  -- Can be "growing", "decaying", or "paused"
local demo_decay_timer = 0

local NOTE_PROGRESSIONS = {
  {62},
  {57, 62},
  {57, 60, 62},
  {57, 60, 62, 66},
  {57, 60, 62, 66},
  {57, 60, 62, 63, 66},
  {57, 60, 62, 63, 66, 67},
  {57, 58, 60, 62, 63, 66, 67}
}

local scale_base = 70  -- 0 to 100
local interval_base = 3  -- 0.2 to 10
local is_frozen = false

-- LFO parameters
local scale_lfo_amp = 30
local scale_lfo_freq = 1/100
local interval_lfo_amp = 2.5
local interval_lfo_freq = 1/80

local start_time

function init()
  start_time = os.time()
  add_branch(WIDTH/2, HEIGHT/2)

  grow_metro = metro.init()
  grow_metro.time = GROW_INTERVAL
  grow_metro.event = update_tree
  grow_metro:start()

  anim_metro = metro.init()
  anim_metro.time = 1/ANIMATION_FPS
  anim_metro.event = update_animation
  anim_metro:start()

  -- New revival metro
  revival_metro = metro.init()
  revival_metro.time = REVIVAL_INTERVAL
  revival_metro.event = check_and_revive
  revival_metro:start()

  if DEMO_MODE then
    demo_metro = metro.init()
    demo_metro.time = 1  -- Update demo state every second
    demo_metro.event = update_demo
    demo_metro:start()
  end

  engine.release(math.random(10,200)/100)
  engine.cutoff(1000)

  update_next_branch_time()
end

function update_demo()
  if not DEMO_MODE then return end

  demo_timer = demo_timer + 1

  if demo_state == "growing" and demo_timer >= DEMO_CYCLE_DURATION then
    demo_state = "decaying"
    demo_timer = 0
    demo_decay_timer = 0
  elseif demo_state == "decaying" then
    demo_decay_timer = demo_decay_timer + 1
    if demo_decay_timer >= DEMO_DECAY_INTERVAL then
      remove_branch()
      demo_decay_timer = 0
    end
    if #tree.branches == 0 then
      demo_state = "paused"
      demo_timer = 0
    end
  elseif demo_state == "paused" and demo_timer >= DEMO_PAUSE_DURATION then
    demo_state = "growing"
    demo_timer = 0
    add_branch(WIDTH/2, HEIGHT/2)  -- Start a new tree from the center
  end
end

function check_and_revive()
  if active_branch_count == 0 and not is_frozen and (not DEMO_MODE or demo_state == "growing") then
    add_branch(WIDTH/2, HEIGHT/2)
  end
end

function update_next_branch_time()
  local interval = get_current_interval()
  next_branch_time = math.random(MIN_BRANCH_INTERVAL * 10, interval * 10) / 10
end

function get_current_scale()
  local elapsed_time = os.time() - start_time
  local lfo_value = scale_lfo_amp * math.sin(2 * math.pi * scale_lfo_freq * elapsed_time)
  return util.clamp(scale_base - lfo_value, 0, 100)
end

function get_current_interval()
  local elapsed_time = os.time() - start_time
  local lfo_value = interval_lfo_amp * math.sin(2 * math.pi * interval_lfo_freq * elapsed_time)
  return util.clamp(interval_base + lfo_value, 0.2, 10)
end

function reset_tree()
  tree.branches = {}
  active_branch_count = 0
  ripples = {}
  add_branch(WIDTH/2, HEIGHT/2)
end

function add_branch(x, y)
  if not is_frozen and (not DEMO_MODE or demo_state == "growing") then
    if #tree.branches >= MAX_BRANCHES then
      remove_branch()
    end
    
    if active_branch_count < MAX_ACTIVE_BRANCHES then
      local new_branch = {
        points = {{x = x, y = y}},
        direction = {x = (math.random(-10, 10) / 10), y = (math.random(-10, 10) / 10)},
        active = true,
        age = 0,
        creation_time = os.time()
      }
      table.insert(tree.branches, new_branch)
      active_branch_count = active_branch_count + 1
      play_note()
      add_ripple(x, y)
      update_next_branch_time()
    end
  end
end

function remove_branch()
  -- First, try to remove an inactive branch
  for i, branch in ipairs(tree.branches) do
    if not branch.active then
      table.remove(tree.branches, i)
      return
    end
  end
  
  -- If all branches are active, remove the oldest one
  local oldest_index = 1
  local oldest_time = math.huge
  
  for i, branch in ipairs(tree.branches) do
    if branch.creation_time < oldest_time then
      oldest_index = i
      oldest_time = branch.creation_time
    end
  end
  
  if tree.branches[oldest_index].active then
    active_branch_count = active_branch_count - 1
  end
  table.remove(tree.branches, oldest_index)
end

function ease_out_cubic(t)
  return 1 - (1 - t) ^ 3
end

function get_growth_factor(age)
  if age >= BOOST_DURATION then
    return 1
  else
    local t = age / BOOST_DURATION
    return 1 + (BOOST_FACTOR - 1) * (1 - ease_out_cubic(t))
  end
end

function grow_branch(branch, dt)
  if not branch.active then return end
  
  branch.age = branch.age + dt
  
  local growth_factor = get_growth_factor(branch.age)
  local growth_amount = growth_factor * dt / GROW_INTERVAL
  
  local last_point = branch.points[#branch.points]
  local new_point = {
    x = last_point.x + branch.direction.x * growth_amount,
    y = last_point.y + branch.direction.y * growth_amount
  }
  
  if new_point.x < 1 or new_point.x > WIDTH or new_point.y < 1 or new_point.y > HEIGHT then
    branch.active = false
    active_branch_count = active_branch_count - 1
    return
  end
  
  table.insert(branch.points, new_point)
  
  branch.direction.x = util.clamp(branch.direction.x + (math.random(-20, 20) / 100), -1, 1)
  branch.direction.y = util.clamp(branch.direction.y + (math.random(-20, 20) / 100), -1, 1)
end

function update_tree()
  if not is_frozen and (not DEMO_MODE or demo_state == "growing") then
    for _, branch in ipairs(tree.branches) do
      grow_branch(branch, GROW_INTERVAL)
    end

    branch_timer = branch_timer + GROW_INTERVAL
    if branch_timer >= next_branch_time then
      branch_timer = 0
      local active_branches = {}
      for _, branch in ipairs(tree.branches) do
        if branch.active then
          table.insert(active_branches, branch)
        end
      end
      if #active_branches > 0 then
        local random_branch = active_branches[math.random(#active_branches)]
        local random_point = random_branch.points[math.random(#random_branch.points)]
        add_branch(random_point.x, random_point.y)
      elseif active_branch_count == 0 then
        -- If no active branches, start a new one from the center
        add_branch(WIDTH/2, HEIGHT/2)
      end
    end
  end
end

function update_animation()
  for i = #ripples, 1, -1 do
    ripples[i].frame = ripples[i].frame + 1
    if ripples[i].frame > RIPPLE_DURATION then
      table.remove(ripples, i)
    end
  end
  
  redraw()
end

function add_ripple(x, y)
  table.insert(ripples, {x = x, y = y, frame = 1})
end

function play_note()
  local current_scale = get_current_scale()
  local progression_index = math.floor(current_scale / (100 / (#NOTE_PROGRESSIONS - 1))) + 1
  local current_progression = NOTE_PROGRESSIONS[progression_index]
  local note_index = math.random(#current_progression)
  local octave = math.random(0, 1)
  
  local midi_note = current_progression[note_index] + (octave * 12)
  local freq = midi_to_hz(midi_note)
  
  engine.hz(freq)
  engine.amp(math.random() * 0.6 + 0.2)
end

function midi_to_hz(note)
  return (440 / 32) * (2 ^ ((note - 9) / 12))
end

function enc(n, d)
  if n == 2 then
    -- Control scale base
    scale_base = util.clamp(scale_base + d, 0, 100)
  elseif n == 3 then
    -- Control interval base
    interval_base = util.clamp(interval_base + d * 0.1, 0.2, 10)
  end
end

function key(n, z)
  if z == 1 then  -- on key press
    if n == 2 then
      reset_tree()
    elseif n == 3 then
      is_frozen = not is_frozen
    end
  end
end

function redraw()
  screen.clear()
  
  for _, branch in ipairs(tree.branches) do
    local points = branch.points
    if #points > 1 then
      screen.level(MIN_BRIGHTNESS)
      screen.move(points[1].x, points[1].y)
      for i = 2, math.max(1, #points - GRADIENT_LENGTH) do
        screen.line(points[i].x, points[i].y)
      end
      screen.stroke()
      
      local start_index = math.max(1, #points - GRADIENT_LENGTH + 1)
      for i = start_index, #points - 1 do
        local brightness = util.linlin(start_index, #points, MIN_BRIGHTNESS, MAX_BRIGHTNESS, i)
        screen.level(math.floor(brightness))
        screen.move(points[i].x, points[i].y)
        screen.line(points[i+1].x, points[i+1].y)
        screen.stroke()
      end
    end
  end
  
  for _, ripple in ipairs(ripples) do
    local brightness = math.floor(MAX_BRIGHTNESS - ripple.frame/2 - 2)
    if brightness > 0 then
      screen.level(brightness)
      if ripple.frame == 1 then
        screen.pixel(ripple.x, ripple.y)
      else
        screen.circle(ripple.x, ripple.y, ripple.frame/3 - 1)
      end
      screen.stroke()
    end
  end
  
  -- Draw scale, interval, freeze information, and active branch count
  local current_scale = get_current_scale()
  local current_interval = get_current_interval()
  local scale_lfo = current_scale - scale_base
  local interval_lfo = current_interval - interval_base
  
  screen.level(1)
  
  -- Scale information
  screen.move(0, 60)
  screen.text(string.format("S:%d%+.1f", math.floor(scale_base), scale_lfo))

  -- Interval information
  screen.move(49, 60)
  screen.text(string.format("I:%.1f%+.1f", interval_base, interval_lfo))
  
  -- Freeze status and active branch count
  screen.move(90, 60)
  screen.text(string.format("%s A:%d", 
                            (is_frozen and "FROZEN" or ""), 
                            active_branch_count))
  
  -- Add demo mode information to the display
  if DEMO_MODE then
   -- screen.move(0, 5)
    --screen.text(string.format("Demo: %s T:%d", demo_state, demo_timer))
  end

  screen.update()
end

function cleanup()
  grow_metro:stop()
  anim_metro:stop()
  revival_metro:stop()
  if DEMO_MODE then
    demo_metro:stop()
  end
end
