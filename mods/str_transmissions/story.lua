-- Order of the signals (ids from messages.lua). Reply labels are what the machine sends, so they are plain.
return {
	-- Relics dug or destroyed before the first signal (rolled once per player), then per later signal
	first = {8, 12},
	step = 5,
	-- Once a signal in `from` is received, steps go by real time (offline too) instead of relics: each comes
	-- `seconds` after the last signal received, an unreplied point's silent variant after `silent`;
	-- due steps wait until the machine is underground
	timed = {from = {"sig_8a", "sig_8b"}, seconds = 600, silent = 1800},
	-- One entry per relic step: a message id, the answer to a reply point, or a pick by relic fate
	sequence = {
		{id = "noise_1"},
		{id = "count_1"},
		{id = "primes_1"},
		{answer = "reply_1"},
		{id = "sig_5"},
		{id = "sig_6"},
		{answer = "reply_2"},
		{fate = {destroyed = "sig_8a", dug = "sig_8b"}},
		{answer = "reply_3"},
		{id = "sig_10"},
		{hold = {yes = "sig_11h", no = "sig_11"}},
		{id = "sig_12"},
		{answer = "reply_4"},
	},
	-- A point opens when a signal in `after` arrives; `decode` options need that signal fully decoded.
	-- With no reply by its step `silent` is sent; a later reply gets its answer at the next step.
	-- `watch` sends `id` once `relics` more are dug or destroyed after the answer arrives.
	-- `hold` options need the Company's departure hold, `gone` ones fewer relics in hold and storage than cities owed.
	-- An `instant` point's answer arrives a few seconds after the reply, not at a relic step.
	-- `later` sends `id` `seconds` of real time (offline too) after the answer arrives.
	replies = {
		{id = "reply_1", after = {"primes_1"}, silent = "sig_4x", options = {
			{label = "Who is this?", answer = "sig_4b"},
			{label = "Jim, is that you?", answer = "sig_4c"},
			{label = "19 23 29", answer = "sig_4a", decode = true},
		}},
		{id = "reply_2", after = {"sig_6"}, silent = "sig_7x", options = {
			{label = "What are you?", answer = "sig_7a", decode = true},
			{label = "Where are you?", answer = "sig_7b", decode = true},
			{label = "Get off this channel", answer = "sig_7c", decode = true},
		}},
		{id = "reply_3", after = {"sig_8a", "sig_8b"}, silent = "sig_9x", instant = true, options = {
			{label = "We did not know", answer = "sig_9a", decode = true},
			{label = "This is Company land", answer = "sig_9b", decode = true},
			{label = "We will stop", answer = "sig_9c", decode = true, watch = {relics = 5, id = "sig_9y"}},
		}},
		{id = "reply_4", after = {"sig_12"}, silent = "sig_13x", instant = true, options = {
			{label = "Help me leave", answer = "sig_13", decode = true, hold = true},
		}},
		{id = "reply_5", after = {"sig_13"}, instant = true, options = {
			{label = "I cannot, they are gone", answer = "sig_14", decode = true, gone = true},
		}},
		{id = "reply_6", after = {"sig_15"}, instant = true, options = {
			{label = "Help me get home", answer = "sig_15w", decode = true, later = {seconds = 1200, id = "sig_16"}},
		}},
	},
	-- Placing relics back: `start` sets the cities owed, each relic dug or destroyed after it adds to them,
	-- `warning` is sent on the first; `build` allows building cities; `done` is sent when none are owed
	cities = {
		start = "sig_13", warning = "sig_13y", build = "sig_14", done = "sig_15",
		owed = 5, add = {dug = 1, destroyed = 2},
		build_cost = {tungsten_carbide = 5},
		build_variants = {"strange_2", "strange_3", "strange_4", "strange_5"},
	},
}
