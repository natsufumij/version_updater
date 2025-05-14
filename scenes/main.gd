extends Node2D

func _ready() -> void:
	var texture = load("res://assets/charging.png")
	$CanvasLayer/TextureRect.texture = texture
