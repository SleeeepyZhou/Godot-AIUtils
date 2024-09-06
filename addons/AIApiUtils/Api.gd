extends Node
# 工具接口
var utils = preload("res://addons/AIApiUtils/ApiUtils.gd").new()

enum IMAGE_Q {HIGH, LOW, AUTO}

func reset():
	utils.reset()

func save(api_url : String, api_key : String):
	utils.api_save([api_url, api_key])

func run_api(prompt : String, api_mod : int = 0, image_path : String = "", \
			format_id : int = -1, image_quality : int = IMAGE_Q.AUTO, timeout : int = 10):
	
	pass

func get_modlist():
	return utils.API_TYPE

func get_format_list():
	return utils.format_list
