extends Area2D

"""
Wang enemy scene, stays invisible while roaming, short chasing range
reveals self once close by player, cannot be detected by heartbeat
while invisible
"""

# Constant variables
# speed when roaming
export var speed_idle = 85
# speed when chasing player
export var speed_chase = 60
# start chasing player if distance squared is smaller than this
export var chase_player_distance_squared = 15000
# determines the upper and lower boundary of the random tick number
# during which enemy can roam to a random location before changing
# its roam location again
# tick number's actual time length subject to delta variable
export var roam_ticker_upper = 1500
export var roam_ticker_lower = 1000

# allow for easier access to nodes
onready var navigation = get_node("/root/Game/Navigation")
onready var player = get_node("/root/Game/Player")
onready var audio = get_node("/root/Game/Audio")
onready var game = get_node("/root/Game")
var rng = RandomNumberGenerator.new()
# the current speed of the enemy, equals either speed_chase or
# speed_idle, also used as an indicator of whether the enemy
# is chasing the player or not
var speed = 0
# a list of pixel positions that assemble into a path that the
# enemy is moving towards, could be a random roam location or the
# player's location
var path = []
# a number in range from roam_ticker_upper to roam_ticker_lower,
# substracts 1 every update tick, and if equals 0 update a random
# roam path
var roam_ticker = 0 
# if set to true, will stop all updates
var freeze = false
# updates every frame, if player is located by Mei, will set to
# true, enemy will chase to player's location regardless of distance
var player_located = false
# the Line2D assigned to enemy when scene is instantiated, displays
# path for debugging
var line2d


func _ready():
	rng.randomize()
	game.connect("global_freeze", self, "_on_game_global_freeze")
	# stays invisible by default
	self.modulate.a = 0


# called every frame. 'delta' is the elapsed time since the previous frame.
# determine if enemy should chase player, and update player health if in collision
func _process(delta):
	if freeze:
		return
	# check if collides with player
	for body in get_overlapping_bodies():
		if body.name == "Player":
			player.update_health(-70)
	# if player is within chase range and is not in tunnel
	if position.distance_squared_to(player.position) < chase_player_distance_squared and player.position.y > 0:
		# chase player with chasing speed
		speed = speed_chase
		path = navigation.a_star_path(position, player.position)
		# update visibility when close to player
		# linear function has alpha = 1 (visible) when distance_squared = 10,000
		# has alpha = 0 (invisible) when distance_squared = 12,000
		self.modulate.a = min(1, max(0, -1.0 / 2000 * position.distance_squared_to(player.position) + 6))
	else:
		# unless chasing player in close distance, wang is going to stay in
		# idling speed, which is higher than its chasing speed, that's why
		# it is modeled slightly differently than gui or wang
		speed = speed_idle
		if player_located and player.position.y > 0:
			# if mei has located player and player is not in tunnel
			path = navigation.a_star_path(position, player.position)
			# reset play_located every frame
			player_located = false
			# unlike all other enemies, wang will try to follow to
			# player's last seen location, so no reset of roam ticker
			# is needed
		else:
			# if player is in tunnel, or player is not seen by Mei
			# and player is not in range of chasing, update roam
			# ticker and change roam path if ticker ticks to 0
			if roam_ticker == 0:
				_rand_roam_path()
			else:
				roam_ticker -= 1


# move enemy towards the next location in path
func _physics_process(delta):
	if freeze:
		return
	# velocity by default is a zero vector
	var velocity = Vector2.ZERO
	# if the next path point is too close to enemy's current position
	# the point is considered arrive, remove it from path so that
	# enemy can travel to next point
	while(path.size() > 0 and position.distance_squared_to(path[0]) < 1):
		# if it is the last point of path and enemy is chasing player
		# the last point is the player's location, don't remove this point
		# because you want the enemy to get locked on the player
		if path.size() == 1 and speed == speed_chase:
			break
		path.remove(0)  # if path point is too close, consider it arrived
	# use adjusted path to determine velocity
	if(path.size() > 0):
		# update velocity to next location in path
		velocity = position.direction_to(path[0])
	else:
		# if path size = 0, enemy has arrived at the final destination
		# of path, if enemy is roaming, change another roam destination
		if speed == speed_idle:
			_rand_roam_path()
	# move position according to velocity and delta
	position += velocity * delta * speed
	# update adjusted path in Line2D, for debugging only
	line2d.points = path


# returns the A* path from current position to a random path tile
# on the map
func _rand_roam_path():
	path = navigation.a_star_path(position, navigation.tile_to_pixel(navigation.rand_path_tile()))
	roam_ticker = rng.randi_range(roam_ticker_lower, roam_ticker_upper)


# when global freeze signal is emitted from Game, stop all updates
func _on_game_global_freeze(freeze):
	self.freeze = freeze


# when enemy noise finishes playing, tell Game/Audio to play another noise
func _on_Noise_finished():
	audio.on_enemy_noise_finished()
