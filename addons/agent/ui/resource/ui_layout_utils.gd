class_name AgentUiLayoutUtils
extends RefCounted


static func is_narrow(width: float) -> bool:
	return width < AgentUiTokens.NARROW_BREAKPOINT


static func get_host_rect(host: Node) -> Rect2i:
	if host == null or not is_instance_valid(host):
		return Rect2i()
	if host is Viewport:
		return Rect2i((host as Viewport).get_visible_rect())
	if host is Control:
		var viewport := (host as Control).get_viewport()
		if viewport != null:
			return viewport.get_visible_rect()
	var tree := host.get_tree()
	if tree != null and tree.root != null:
		return Rect2i(Vector2i.ZERO, tree.root.size)
	return Rect2i()


static func fit_popup_size(preferred: Vector2i, host: Rect2i, max_ratio: float = AgentUiTokens.POPUP_MAX_SCREEN_RATIO) -> Vector2i:
	if host.size.x <= 0 or host.size.y <= 0:
		return preferred
	var margin := AgentUiTokens.POPUP_MARGIN * 2
	var max_size := Vector2i(
		int(float(host.size.x - margin) * max_ratio),
		int(float(host.size.y - margin) * max_ratio)
	)
	return Vector2i(
		min(preferred.x, max(max_size.x, 200)),
		min(preferred.y, max(max_size.y, 150))
	)


static func clamp_popup_rect(preferred: Rect2i, host: Rect2i, margin: int = AgentUiTokens.POPUP_MARGIN) -> Rect2i:
	var result := preferred
	var safe := Rect2i(
		host.position + Vector2i(margin, margin),
		host.size - Vector2i(margin * 2, margin * 2)
	)
	if safe.size.x <= 0 or safe.size.y <= 0:
		return result
	result.size.x = min(result.size.x, safe.size.x)
	result.size.y = min(result.size.y, safe.size.y)
	result.position.x = clampi(result.position.x, safe.position.x, safe.position.x + safe.size.x - result.size.x)
	result.position.y = clampi(result.position.y, safe.position.y, safe.position.y + safe.size.y - result.size.y)
	return result


static func popup_centered_clamped(window: Window, preferred_size: Vector2i, host: Node) -> void:
	if window == null or not is_instance_valid(window):
		return
	var host_rect := get_host_rect(host)
	var resolved_size := preferred_size
	if resolved_size.x <= 0 or resolved_size.y <= 0:
		resolved_size = window.size
	if resolved_size.x <= 0:
		resolved_size.x = 480
	if resolved_size.y <= 0:
		resolved_size.y = 320
	var fitted_size := fit_popup_size(resolved_size, host_rect)
	var centered_pos := host_rect.position + (host_rect.size - fitted_size) / 2
	var popup_rect := clamp_popup_rect(Rect2i(centered_pos, fitted_size), host_rect)
	window.size = popup_rect.size
	window.popup(Rect2i(popup_rect.position, popup_rect.size))


static func popup_at_clamped(window: Window, preferred_pos: Vector2i, preferred_size: Vector2i, host: Node) -> void:
	if window == null or not is_instance_valid(window):
		return
	var host_rect := get_host_rect(host)
	var fitted_size := fit_popup_size(preferred_size, host_rect)
	var popup_rect := clamp_popup_rect(Rect2i(preferred_pos, fitted_size), host_rect)
	window.size = popup_rect.size
	window.popup(Rect2i(popup_rect.position, popup_rect.size))
