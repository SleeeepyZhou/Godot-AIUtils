@tool
extends Node

## 数据预处理

# 图片压缩及转码
const IMAGE_TYPE = ["JPG", "PNG", "BMP", "GIF", "TIF", "TIFF", "JPEG", "WEBP"]
func zip_image(path : String, quality : String = "auto") -> Image:
	var image = Image.load_from_file(path)
	var width = image.get_size().x
	var height = image.get_size().y
	
	var target : int = 512
	var aspect_ratio : float = float(width) / height
	var new_width = width
	var new_height = height
	if quality == "high":
		target = 1024
	elif quality == "low":
		target = 512
	elif quality == "auto":
		if width >= 1024 or height >= 1024:
			target = 1024
	if width > target or height > target:
		if width > height:
			new_width = target
			new_height = int(new_width / aspect_ratio)
		else:
			new_height = target
			new_width = int(new_height * aspect_ratio)
	image.resize(new_width, new_height)
	return image
func image_to_base64(path : String, quality : String = "auto") -> String:
	var image = zip_image(path, quality)
	return Marshalls.raw_to_base64(image.save_jpg_to_buffer(0.90))

# 提示词
func addition_prompt(text : String, image_path : String = "") -> String: # 提示词，图片路径
	if '{' not in text or '}' not in text:
		return text
	var file_name = image_path.get_file().rstrip("." + image_path.get_extension()) + ".txt"
	var dir_path = text.substr(text.find("{")+1, text.find("}")-text.find("{")-1)
	var full_path = (dir_path + "/" + file_name).simplify_path()
	var file = FileAccess.open(full_path, FileAccess.READ)
	var file_content := ""
	if file:
		file_content = file.get_as_text()
		file.close()
	return text.replace("{" + dir_path + "}", file_content)

# 用户数据
const SAVEPATH = "user://data.api"
func reset():
	var access = DirAccess.open(SAVEPATH.get_base_dir())
	access.remove(SAVEPATH)
func api_save(data : Array = ["https://api.openai.com/v1/chat/completions", ""]):
	var save_data = FileAccess.open(SAVEPATH, FileAccess.WRITE)
	save_data.store_var(data)
	save_data.close()
func readsave():
	var save_data
	if FileAccess.file_exists(SAVEPATH):
		var data = FileAccess.open(SAVEPATH, FileAccess.READ).get_var()
		if not data:
			return
		save_data = data
	else:
		api_save()
		save_data = readsave()
	return save_data


## API工具

# 线程池
var maxhttp : int = 10
var is_run : bool = false

# API运行
@export var api_url : String
@export var api_key : String
@export var api_mod : int = 0
@export_enum("high", "low", "auto") var img_quality : String = "auto"
@export var time_out : int = 10

const API_TYPE = ["gpt-4o-2024-08-06", "gpt-4o-mini", "qwen-vl-plus", \
					"qwen-vl-max", "claude", "gemini-1.5-pro-exp-0801"]

var API_FUNC : Array[Callable] = [Callable(self,"openai_api"), 
								Callable(self,"openai_api"),
								Callable(self,"qwen_api"), 
								Callable(self,"qwen_api"), 
								Callable(self,"claude_api"),
								Callable(self,"gemini_api")]

func run_api(prompt : String, image_path : String = "", out : int = 10) -> String:
	var apidata : Array[String] = [api_url, api_key]
	api_save(apidata)
	if image_path.is_empty():
		return "There are no pictures."
	var base64image = image_to_base64(image_path, img_quality)
	var current_prompt = addition_prompt(prompt, image_path)
	time_out = out
	var result = await API_FUNC[api_mod].call(current_prompt, base64image)
	return result

# 标准化收发
func get_result(head : PackedStringArray, data : String, url : String = "") -> Array:
	retry_times = 0
	if url.is_empty():
		url = api_url
	var response : String = await request_retry(head, data, url)
	if "Error:" in response:
		return [false, response]
	else:
		var json_result = JSON.parse_string(response)
		return [true, json_result]
# 重试方法
const RETRY_ATTEMPTS = 5
var retry_times : int = 0
const status_list = [429, 500, 502, 503, 504]
func request_retry(head : PackedStringArray, data : String, url : String) -> String:
	# 建立请求
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = time_out
	var error = http_request.request(url, head, HTTPClient.METHOD_POST, data)
	if error != OK:
		return "Error: " + error_string(error)
	
	# 发起成功
	var received = await http_request.request_completed
	http_request.queue_free()
	if received[0] != 0:
		return "Error: " + ClassDB.class_get_enum_constants("HTTPRequest", "Result")[received[0]]
	
	# 重试策略
	if retry_times > RETRY_ATTEMPTS:
		return "Error: Retry count exceeded"
	elif received[1] != 200 and status_list.has(received[1]) and retry_times <= RETRY_ATTEMPTS:
		retry_times += 1
		await get_tree().create_timer(2 ** (retry_times - 1)).timeout
		return await request_retry(head, data, url)
	elif received[1] == 200:
		var result : String = received[3].get_string_from_utf8()
		if "error" in result:
			return "APIError: " + result
		else:
			return result
	else:
		return "Error: Unknown error"


## 各家API模块

var formatrespon : bool = false
var format : Dictionary = {}
'''
{"type": "json_schema",
"json_schema": {"name": "image_analysis_response",
				"strict": true,
				"schema": {"type": "object",
							"properties": {"category": { "type": "string" },
											"subject": { "type": "string" },
											"appearance": {"type": "object",
															"properties": {"costume": { "type": "string" },
																			"prop": { "type": "string" },
																			"expression": { "type": "string" }},
															"required": ["costume", "prop", "expression"],
															"additionalProperties": false},
											},
							"required": ["category", "subject", "appearance"],
							"additionalProperties": false}
				}
}
'''

func openai_api(inputprompt : String, base64image : String):
	var temp_data = {
		"model": API_TYPE[api_mod],
		"messages": [
				{
				"role": "user",
				"content":
						[{"type": "image_url", 
						"image_url":
							{"url": "data:image/jpeg;base64," + base64image,
							"detail": img_quality}
						},
						{"type": "text", "text": inputprompt}]
				}
					],
		"max_tokens": 300
		}
	var headers : PackedStringArray = ["Content-Type: application/json", 
										"Authorization: Bearer " + api_key]
	if formatrespon and !is_run:
		format = %SchemaBox.send()
		if !format.is_empty():
			temp_data["response_format"] = format
	var data = JSON.stringify(temp_data)
	is_run = true
	
	var result = await get_result(headers, data)
	if result[0]:
		var answer : String = ""
		var json_result = result[1]
		if json_result != null:
			# 安全地尝试
			if json_result.has("choices") and json_result["choices"].size() > 0 and\
					json_result["choices"][0].has("message") and\
					json_result["choices"][0]["message"].has("content"):
				var format_respon = JSON.parse_string(json_result["choices"][0]["message"]["content"])
				if format.is_empty() and !format_respon:
					answer = json_result["choices"][0]["message"]["content"]
				else:
					answer = get_openai_format_answer(format_respon)
			else:
				answer = str(json_result)
		return answer
	elif !result[0]:
		return result[1]
var batchmod = false
func get_openai_format_answer(json : Dictionary, tab : int = 0) -> String:
	var answer : String = ""
	if batchmod:
		for key in json:
			var unit_answer : String
			if json[key] is Dictionary:
				unit_answer = get_openai_format_answer(json[key])
			else:
				unit_answer = str(json[key]) + ", "
			answer = unit_answer + answer
	else:
		for key in json:
			var unit_answer : String
			if json[key] is Dictionary:
				unit_answer = "\n" + get_openai_format_answer(json[key], tab + 1)
			else:
				unit_answer = str(json[key])
			var _tab : String
			var tabar : Array = []
			tabar.resize(tab)
			tabar.fill("\t")
			_tab = "".join(tabar)
			answer = answer + _tab + key + ": " + unit_answer + ", \n"
		while answer.ends_with(", \n"):
			answer = answer.substr(0, len(answer) - 3)
	return answer


func gemini_api(inputprompt : String, base64image : String):
	var tempprompt = inputprompt
	#var gemini_format
	#if formatrespon and !is_run:
		#format = %SchemaBox.send()
		#if !format.is_empty():
			#gemini_format = format["json_schema"]["schema"]  "properties"  "required"
	#is_run = true
	if !("Return output in json format:" in inputprompt):
		tempprompt += "Return output in json format: {description: description, \
						features: [feature1, feature2, feature3, etc]}"
	var data = JSON.stringify(
			{
			"contents": [
				{"parts": [
						{"text": tempprompt},
						{"inline_data": {"mime_type": "image/jpeg",
										"data": base64image}}
							]}
						]
			})
	var headers : PackedStringArray = ["Content-Type: application/json"]
	var url : String = api_url + "/models/gemini-1.5-pro-exp-0801:generateContent?key=" + api_key
	# https://generativelanguage.googleapis.com/v1beta
	var result = await get_result(headers, data, url)
	if result[0]:
		var answer : String = ""
		var json_result = result[1]
		if json_result != null:
			# 安全地尝试
			if (json_result.has("candidates") and json_result["candidates"].size() > 0) and\
					json_result["candidates"][0].has("content") and\
					(json_result["candidates"][0]["content"].has("parts") and \
					json_result["candidates"][0]["content"]["parts"].size() > 0) and \
					json_result["candidates"][0]["content"]["parts"][0].has("text"):
				var format_respon = JSON.parse_string(json_result["candidates"][0]["content"]["parts"][0]["text"])
				if format.is_empty() and !format_respon:
					answer = json_result["candidates"][0]["content"]["parts"][0]["text"]
				else:
					answer = get_gemini_format_answer(format_respon)
			else:
				answer = str(json_result)
		return answer
	elif !result[0]:
		return result[1]
func get_gemini_format_answer(json : Dictionary):
	var answer : String = ""
	for key in json:
		var unit_answer : String
		if json[key] is Dictionary:
			unit_answer = get_gemini_format_answer(json[key])
		else:
			unit_answer = str(json[key]) + ", "
		answer = (unit_answer + answer).format(" ","[").format(" ", "]")
	return answer


func qwen_api(inputprompt : String, base64image : String) -> String:
	var data = JSON.stringify({
		"model": API_TYPE[api_mod],
		"input": {
			"messages": [
				{"role": "system",
				"content": [{"text": "You are a helpful assistant."}]},
				{"role": "user",
				"content": [{"image": "data:image/jpeg;base64," + base64image},
							{"text": inputprompt}]}
						]
				}
								})
	var headers : PackedStringArray = ["Authorization: Bearer " + api_key,
										"Content-Type: application/json"]
	
	var result = await get_result(headers, data)
	var answer = ""
	if result[0]:
		var json_result = result[1]
		if json_result != null:
			# 安全地尝试
			if json_result.has("output") and\
				json_result["output"].has("choices") and\
				json_result["output"]["choices"].size() > 0 and\
				json_result["output"]["choices"][0].has("message") and\
				json_result["output"]["choices"][0]["message"].has("content") and\
				json_result["output"]["choices"][0]["message"]["content"].size() > 0 and\
				json_result["output"]["choices"][0]["message"]["content"][0].has("text"):
				answer = json_result["output"]["choices"][0]["message"]["content"][0]["text"]
			else:
				answer = str(json_result)
	elif !result[0]:
		answer = result[1]
	return answer


func claude_api(inputprompt : String, base64image : String) -> String:
	var data = JSON.stringify({
		"model": "claude_api",
		"max_tokens": 300,
		"messages": [{
					"role": "user", 
					"content": [{
							"type": "image", 
							"source": {"type": "base64",
									"media_type": "image/jpeg",
									"data": base64image}
								},
								{
							"type": "text", 
							"text": inputprompt
								}]
					}]
							})
	var headers : PackedStringArray = ["Content-Type: application/json",
			"x-api-key:" + api_key,
			"anthropic-version: 2023-06-01"]
	
	var result = await get_result(headers, data)
	if result[0]:
		var answer : String = ""
		var json_result = result[1]
		if json_result != null:
			# 安全地尝试
			if json_result.has("content") and\
				json_result["content"].size() > 0 and\
				json_result["content"][0].has("text"):
				answer = json_result["content"][0]["text"]
			else:
				answer = str(json_result)
		return answer
	else:
		return result[1]
