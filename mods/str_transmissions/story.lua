-- Order of the signals (ids from messages.lua). Reply labels are what the machine sends, so they are plain.
return {
	-- Relics dug or destroyed before the first signal (rolled once per player), then per later signal
	first = {8, 12},
	step = 5,
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
	},
	-- A point opens when a signal in `after` arrives; `decode` options need that signal fully decoded.
	-- With no reply by its step `silent` is sent; a later reply gets its answer at the next step.
	-- `watch` sends `id` once `relics` more are dug or destroyed after the answer arrives.
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
		{id = "reply_3", after = {"sig_8a", "sig_8b"}, silent = "sig_9x", options = {
			{label = "We did not know", answer = "sig_9a", decode = true},
			{label = "This is Company land", answer = "sig_9b", decode = true},
			{label = "We will stop", answer = "sig_9c", decode = true, watch = {relics = 5, id = "sig_9y"}},
		}},
	},
}
