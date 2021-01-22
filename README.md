# NGP
NGP (New Game Project) is a multiplayer wrapper for [Godot](https://godotengine.org/) games with the power to load different games without restarting the wrapper. Executable file is available in the releases page.

It was mainly created to make creating and playing multiplayer games quick and easy, as it comes built in with a system to host and join other people (with a join-code and key instead of IP directly), and makes it so games don't have to set up a server connection in order to use the multiplayer features Godot provides.

## Carts

You cannot launch Godot-based executables with NGP directly; instead, Godot projects must be packaged into pck files and put into `%appdata%\Godot\app_userdata\NGP\packs` with certain methods and a `data.cfg` so NGP launches them correctly. For those that are making a project for NGP, you can use `rpc()` and any other high level multiplayer function to communicate between players. I personally recommend that you surround calls with `if len(players) > 1:` so that you don't have to worry about calling them when not connected to a server.

### Format

When creating a Godot project for NGP to load, you'll have to create a `data.cfg` file and place it in the root of your project folder. The `data.cfg` file should look something like this:

```
[root]
carts=[
	"MyAwesomeGame",
	"MySecondAwesomeGame"
]
id="some/path"
major=1
minor=0

[MyAwesomeGame]
title="My Awesome Game"
author="You"
desc="Really neat description goes here"

[MySecondAwesomeGame]
title="2nd Awesome Game"
author="You"
desc="Another really neat description goes here"
```

There should be a root scene for each cart. In this case, there should be two files named `MyAwesomeGame.tscn` and `MySecondAwesomeGame.tscn` in `res://some/path/`. They are launched individually when wanted through the NGP by the user.

NGP will also provide data to the scene and call functions if the scene has certain variables and functions declared:

**Variables:**

`sid` - The current player's id as known by the server. 1 means the player is not connected to a server or the player is hosting. It is best to initialize this to 1.
`players` - A list of player ids who are connected to the server.
`pnames` - A dictionary mapping player ids to player names. Use this to get the usernames of connected players.

**Functions:**

`_player_join(id)` - Called by NGP when a new player joins.
`_player_leave(id)` - Called by NGP when a player leaves.
`_update_name(id)` - Called by NGP when a player changes their username while connected to the server.

## Games?

If you make a cart with NGP, post it on github and submit an issue for it! I will close bad carts or tag good ones there. Making games is hard, so I haven't quite put the effort into finishing a cart for it yet.