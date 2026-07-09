@tool
extends SceneTree

func _initialize() -> void:
	var stream := MockChatStream.new()
	add_child(stream)

	stream.queue_text_response("hello", "thinking step")
	stream.use_thinking = true

	var finished := false
	var received_text := ""
	var received_think := ""

	stream.think.connect(func(msg: String): received_think += msg)
	stream.message.connect(func(msg: String): received_text += msg)
	stream.generate_finish.connect(func(_reason, _tokens): finished = true)

	stream.post_message([])

	assert(finished, "mock stream should finish")
	assert(received_text == "hello", "mock stream should emit text")
	assert(received_think == "thinking step", "mock stream should emit thinking")

	quit(0)
