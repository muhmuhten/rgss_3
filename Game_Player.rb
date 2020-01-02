#==============================================================================
# ** Game_Player
#------------------------------------------------------------------------------
#  This class handles the player. Its functions include event starting
#  determinants and map scrolling. Refer to "$game_player" for the one
#  instance of this class.
#==============================================================================

class Game_Player < Game_Character
	#--------------------------------------------------------------------------
	# * Invariables
	#--------------------------------------------------------------------------
	CENTER_X = (320 - 16) * 4   # Center screen x-coordinate * 4
	CENTER_Y = (240 - 16) * 4   # Center screen y-coordinate * 4
	#--------------------------------------------------------------------------
	# * Passable Determinants
	#     x : x-coordinate
	#     y : y-coordinate
	#     d : direction (0,2,4,6,8)
	#         * 0 = Determines if all directions are impassable (for jumping)
	#--------------------------------------------------------------------------
	def passable?(x, y, d)
		# If debug mode is ON and ctrl key was pressed
		if $DEBUG and Input.press?(Input::CTRL)
			# Get new coordinates
			new_x, new_y = new_coords(x, y, d)
			return $game_map.valid?(new_x, new_y)
		end
		super
	end
	#--------------------------------------------------------------------------
	# * Set Map Display Position to Center of Screen
	#--------------------------------------------------------------------------
	def center(x, y)
		max_x = ($game_map.width - 20) * 128
		max_y = ($game_map.height - 15) * 128
		$game_map.display_x = [0, [x * 128 - CENTER_X, max_x].min].max
		$game_map.display_y = [0, [y * 128 - CENTER_Y, max_y].min].max
	end
	#--------------------------------------------------------------------------
	# * Move to Designated Position
	#     x : x-coordinate
	#     y : y-coordinate
	#--------------------------------------------------------------------------
	def moveto(x, y)
		super
		# Centering
		center(x, y)
		# Make encounter count
		make_encounter_count
	end
	#--------------------------------------------------------------------------
	# * Increaase Steps
	#--------------------------------------------------------------------------
	def increase_steps
		super
		# If move route is not forcing
		unless @move_route_forcing
			# Increase steps
			$game_party.increase_steps
			# Number of steps are an even number
			if $game_party.steps % 2 == 0
				# Slip damage check
				$game_party.check_map_slip_damage
			end
		end
	end
	#--------------------------------------------------------------------------
	# * Get Encounter Count
	#--------------------------------------------------------------------------
	def encounter_count
		return @encounter_count
	end
	#--------------------------------------------------------------------------
	# * Make Encounter Count
	#--------------------------------------------------------------------------
	def make_encounter_count
		# Image of two dice rolling
		if $game_map.map_id != 0
			n = $game_map.encounter_step
			@encounter_count = rand(n) + rand(n) + 1
		end
	end
	#--------------------------------------------------------------------------
	# * Refresh
	#--------------------------------------------------------------------------
	def refresh
		# If party members = 0
		if $game_party.actors.size == 0
			# Clear character file name and hue
			@character_name = ""
			@character_hue = 0
			# End method
			return
		end
		# Get lead actor
		actor = $game_party.actors[0]
		# Set character file name and hue
		@character_name = actor.character_name
		@character_hue = actor.character_hue
		# Initialize opacity level and blending method
		@opacity = 255
		@blend_type = 0
	end
	#--------------------------------------------------------------------------
	# * Same Position Starting Determinant
	#--------------------------------------------------------------------------
	def check_event_trigger_here(triggers)
		check_event_trigger_touch(@x, @y, triggers, true)
	end
	#--------------------------------------------------------------------------
	# * Front Envent Starting Determinant
	#--------------------------------------------------------------------------
	def check_event_trigger_there(triggers)
		new_x, new_y = new_coords(@x, @y, @direction)
		# If fitting event is not found
		if !check_event_trigger_touch(new_x, new_y, triggers)
			# If front tile is a counter
			if $game_map.counter?(new_x, new_y)
				# Calculate 1 tile inside coordinates
				new_x, new_y = new_coords(new_x, new_y, @direction)
				return check_event_trigger_touch(new_x, new_y, triggers)
			end
		else
			return true
		end
	end
	#--------------------------------------------------------------------------
	# * Touch Event Starting Determinant
	#--------------------------------------------------------------------------
	def check_event_trigger_touch(x, y, triggers=[1,2], over_trigger=false)
		# If event is running
		if $game_system.map_interpreter.running?
			return false
		end
		result = false
		# All event loops
		for event in $game_map.events.values
			# If event coordinates and triggers are consistent
			if event.x == x and event.y == y and triggers.include?(event.trigger)
				# If starting determinant is front event (other than jumping)
				if not event.jumping? and event.over_trigger? == over_trigger
					event.start
					result = true
				end
			end
		end
		return result
	end
	#--------------------------------------------------------------------------
	# * Frame Update
	#--------------------------------------------------------------------------
	def update
		# Remember whether or not moving in local variables
		last_moving = moving?
		# If moving, event running, move route forcing, and message window
		# display are all not occurring
		unless moving? or $game_system.map_interpreter.running? or
				@move_route_forcing or $game_temp.message_window_showing
			# Move player in the direction the directional button is being pressed
			move_forward(Input.dir4, true)
		end
		# Remember coordinates in local variables
		last_real_x = @real_x
		last_real_y = @real_y
		super
		# If character moves down and is positioned lower than the center
		# of the screen
		if @real_y > last_real_y and @real_y - $game_map.display_y > CENTER_Y
			# Scroll map down
			$game_map.scroll_down(@real_y - last_real_y)
		end
		# If character moves left and is positioned more let on-screen than
		# center
		if @real_x < last_real_x and @real_x - $game_map.display_x < CENTER_X
			# Scroll map left
			$game_map.scroll_left(last_real_x - @real_x)
		end
		# If character moves right and is positioned more right on-screen than
		# center
		if @real_x > last_real_x and @real_x - $game_map.display_x > CENTER_X
			# Scroll map right
			$game_map.scroll_right(@real_x - last_real_x)
		end
		# If character moves up and is positioned higher than the center
		# of the screen
		if @real_y < last_real_y and @real_y - $game_map.display_y < CENTER_Y
			# Scroll map up
			$game_map.scroll_up(last_real_y - @real_y)
		end
		# If not moving
		unless moving?
			# If player was moving last time
			if last_moving
				# Event determinant is via touch of same position event
				result = check_event_trigger_here([1,2])
				# If event which started does not exist
				if result == false
					# Disregard if debug mode is ON and ctrl key was pressed
					unless $DEBUG and Input.press?(Input::CTRL)
						# Encounter countdown
						if @encounter_count > 0
							@encounter_count -= 1
						end
					end
				end
			end
			# If C button was pressed
			if Input.trigger?(Input::C)
				# Same position and front event determinant
				check_event_trigger_here([0])
				check_event_trigger_there([0,1,2])
			end
		end
	end
end
