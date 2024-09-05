extends Node

var utils = preload("res://addons/AIApiUtils/ApiUtils.gd").new()

func setzero():
	utils.reset()

func save():
	utils.api_save()
