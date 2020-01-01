#==============================================================================
# ** Game_Character (part 3)
#------------------------------------------------------------------------------
#  This class deals with characters. It's used as a superclass for the
#  Game_Player and Game_Event classes.
#==============================================================================

class Game_Character
	#--------------------------------------------------------------------------
	# * Move Down
	# * Move Left
	# * Move Right
	# * Move Up
	#     turn_enabled : a flag permits direction change on that spot
	#--------------------------------------------------------------------------
	def move_down(turn_enabled = true)
		move_forward(2, turn_enabled)
	end
	def move_left(turn_enabled = true)
		move_forward(4, turn_enabled)
	end
	def move_right(turn_enabled = true)
		move_forward(6, turn_enabled)
	end
	def move_up(turn_enabled = true)
		move_forward(8, turn_enabled)
	end
	#--------------------------------------------------------------------------
	# * Move Lower Left
	# * Move Lower Right
	# * Move Upper Left
	# * Move Upper Right
	#--------------------------------------------------------------------------
	def move_diagonal(dix, diy)
		nx, ny = @x, @y
		case dix
		when 4: nx -= 1
		when 6: nx += 1
		end
		case diy
		when 2: ny += 1
		when 8: ny -= 1
		end

		unless @direction_fix
			case @direction
			when 10-dix:
				@direction = dix
			when 10-diy:
				@direction = diy
			end
		end

		if (passable?(@x, @y, dix) and passable?(nx, @y, diy)) or
				(passable?(@x, @y, diy) and passable?(@x, ny, dix))
			@x, @y = nx, ny
			increase_steps
		end
	end
	def move_lower_left
		move_diagonal(4, 2)
	end
	def move_lower_right
		move_diagonal(6, 2)
	end
	def move_upper_left
		move_diagonal(4, 8)
	end
	def move_upper_right
		move_diagonal(6, 8)
	end
	#--------------------------------------------------------------------------
	# * Move at Random
	#--------------------------------------------------------------------------
	def move_random
		move_forward(2+rand(4)*2, false)
	end
	#--------------------------------------------------------------------------
	# * Move toward Player
	# The original routine has been replaced with an A* search with roughly
	# Manhattan heuristic (see below), vastly improving pathfinding around
	# obstacles and mazes.
	#--------------------------------------------------------------------------
	def distance_heuristic(x1, y1, x2, y2)
		case @direction
		when 2: @y <=> y1
		when 4: x1 <=> @x
		when 6: @x <=> x1
		when 8: y1 <=> @y
		else 0
		end + 4*(x2-x1).abs + 4*(y2-y1).abs - 2
	end
	def move_toward_player(px=nil, py=nil, tries = 350)
		px ||= $game_player.x
		py ||= $game_player.y
		target_dist = passable?(px, py, 0) ? 0 : 1

		row = $game_map.width + 1
		best_candidate = [-distance_heuristic(@x, @y, px, py), @x, @y, 0]
		seen_cost = {@x+@y*row=>0}
		seen_from = {@x+@y*row=>best_candidate}
		frontier = [best_candidate]

		while frontier.length > 0 and tries > 0
			tries -= 1
			_, mx, my = frontier.sort!.pop
			if (mx-px).abs + (my-py).abs == target_dist
				best_candidate = seen_from[mx+my*row]
				break
			end

			new_cost = seen_cost[mx+my*row]-4
			[2, 4, 6, 8].each do |md|
				nx, ny = new_coords(mx, my, md)
				idx = nx+ny*row
				next if seen_cost[idx]
				next if !passable?(mx, my, md)
				new_est = new_cost - distance_heuristic(nx, ny, px, py)
				candidate = [new_est, mx, my, md]
				best_candidate = candidate if new_est >= best_candidate[0]
				seen_cost[idx] = new_cost
				seen_from[idx] = candidate
				frontier.push([new_est, nx, ny])
			end
		end

		_, mx, my, md = best_candidate
		while mx != @x or my != @y
			_, mx, my, md = seen_from[mx+my*row]
		end

		if md == 0
			turn_toward_player(px, py)
			move_forward if !passable?(@x, @y, @direction)
		else
			move_forward(md)
		end
	end
	#--------------------------------------------------------------------------
	# * Move away from Player
	#--------------------------------------------------------------------------
	def move_away_from_player
		# Get difference in player coordinates
		sx = @x - $game_player.x
		sy = @y - $game_player.y
		# If coordinates are equal
		if sx == 0 and sy == 0
			return
		end
		# Get absolute value of difference
		abs_sx = sx.abs
		abs_sy = sy.abs
		# If horizontal and vertical distances are equal
		if abs_sx == abs_sy
			# Increase one of them randomly by 1
			rand(2) == 0 ? abs_sx += 1 : abs_sy += 1
		end
		# If horizontal distance is longer
		if abs_sx > abs_sy
			# Move away from player, prioritize left and right directions
			sx > 0 ? move_right : move_left
			if not moving? and sy != 0
				sy > 0 ? move_down : move_up
			end
			# If vertical distance is longer
		else
			# Move away from player, prioritize up and down directions
			sy > 0 ? move_down : move_up
			if not moving? and sx != 0
				sx > 0 ? move_right : move_left
			end
		end
	end
	#--------------------------------------------------------------------------
	# * 1 Step Forward
	#--------------------------------------------------------------------------
	def move_forward(dir=nil, turn_enabled = false)
		dir ||= @direction
		case dir
		when 0: return
		when 2, 4, 6, 8:
			new_x, new_y = new_coords(@x, @y, dir)
			if passable?(@x, @y, dir)
				turn_generic(dir)
				@x, @y = new_x, new_y
				increase_steps
			else
				turn_generic(dir) if turn_enabled
				check_event_trigger_touch(new_x, new_y)
			end
		when 1: return move_diagonal(4, 2)
		when 3: return move_diagonal(6, 2)
		when 7: return move_diagonal(4, 8)
		when 9: return move_diagonal(6, 8)
		end
	end
	#--------------------------------------------------------------------------
	# * 1 Step Backward
	#--------------------------------------------------------------------------
	def move_backward(dir=nil)
		# Remember direction fix situation
		last_direction_fix = @direction_fix
		# Force directino fix
		@direction_fix = true
		# Branch by direction
		move_forward(10-@direction, false)
		# Return direction fix situation back to normal
		@direction_fix = last_direction_fix
	end
	#--------------------------------------------------------------------------
	# * Jump
	#     x_plus : x-coordinate plus value
	#     y_plus : y-coordinate plus value
	#--------------------------------------------------------------------------
	def jump(x_plus, y_plus)
		# If plus value is not (0,0)
		if x_plus != 0 or y_plus != 0
			# If horizontal distnace is longer
			if x_plus.abs > y_plus.abs
				# Change direction to left or right
				x_plus < 0 ? turn_left : turn_right
				# If vertical distance is longer, or equal
			else
				# Change direction to up or down
				y_plus < 0 ? turn_up : turn_down
			end
		end
		# Calculate new coordinates
		new_x = @x + x_plus
		new_y = @y + y_plus
		# If plus value is (0,0) or jump destination is passable
		if (x_plus == 0 and y_plus == 0) or passable?(new_x, new_y, 0)
			# Straighten position
			straighten
			# Update coordinates
			@x = new_x
			@y = new_y
			# Calculate distance
			distance = Math.sqrt(x_plus * x_plus + y_plus * y_plus).round
			# Set jump count
			@jump_peak = 10 + distance - @move_speed
			@jump_count = @jump_peak * 2
			# Clear stop count
			@stop_count = 0
		end
	end
	#--------------------------------------------------------------------------
	# * Turn Down
	# * Turn Left
	# * Turn Right
	# * Turn Up
	#--------------------------------------------------------------------------
	def turn_generic(dir)
		return if @direction_fix
		@direction = dir
		@stop_count = 0
	end
	def turn_down
		turn_generic(2)
	end
	def turn_left
		turn_generic(4)
	end
	def turn_right
		turn_generic(6)
	end
	def turn_up
		turn_generic(8)
	end
	#--------------------------------------------------------------------------
	# * Turn 90° Right
	#--------------------------------------------------------------------------
	def turn_right_90
		case @direction
		when 2
			turn_left
		when 4
			turn_up
		when 6
			turn_down
		when 8
			turn_right
		end
	end
	#--------------------------------------------------------------------------
	# * Turn 90° Left
	#--------------------------------------------------------------------------
	def turn_left_90
		case @direction
		when 2
			turn_right
		when 4
			turn_down
		when 6
			turn_up
		when 8
			turn_left
		end
	end
	#--------------------------------------------------------------------------
	# * Turn 180°
	#--------------------------------------------------------------------------
	def turn_180
		turn_generic(10-@direction)
	end
	#--------------------------------------------------------------------------
	# * Turn 90° Right or Left
	#--------------------------------------------------------------------------
	def turn_right_or_left_90
		if rand(2) == 0
			turn_right_90
		else
			turn_left_90
		end
	end
	#--------------------------------------------------------------------------
	# * Turn at Random
	#--------------------------------------------------------------------------
	def turn_random
		turn_generic(2+range(4)*2)
	end
	#--------------------------------------------------------------------------
	# * Turn Towards Player
	#--------------------------------------------------------------------------
	def turn_toward_player(px=nil, py=nil, reverse = false)
		px ||= $game_player.x
		py ||= $game_player.y
		# Get difference in player coordinates
		sx = @x - px
		sy = @y - py
		# If coordinates are equal
		if sx == 0 and sy == 0
			return
		end
		turn_dir = sx.abs > sy.abs ? (sx > 0 ? 4 : 6) : (sy > 0 ? 8 : 2)
		turn_generic(reverse ? 10-turn_dir : turn_dir)
	end
	#--------------------------------------------------------------------------
	# * Turn Away from Player
	#--------------------------------------------------------------------------
	def turn_away_from_player
		turn_toward_player(nil, nil, true)
	end
end
