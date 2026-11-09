extends Node
## Pont vers Claude Code (technique « B », version de test, un seul joueur) : lance
## tools/craft/claude_craft.py dans un fil séparé pour ne pas figer le jeu, puis émet `finished`.
## Réponse : {"ok": true, "item": {...}} ou {"ok": false, "error": "..."}.

signal finished(job: String, result: Dictionary)

var _thread: Thread
var _job := ""
## Commande Python (réglable si `python` n'est pas dans le PATH)
var python_cmd := "python"


func busy() -> bool:
	return _thread != null


## Faux si l'IA est indisponible ici (export, mobile) : le jeu utilisera un nom de secours.
func available() -> bool:
	var desktop := OS.has_feature("windows") or OS.has_feature("linuxbsd") or OS.has_feature("macos")
	return desktop and FileAccess.file_exists(_script())


func _script() -> String:
	return ProjectSettings.globalize_path("res://tools/craft/claude_craft.py")


func request(job: String, req: Dictionary) -> bool:
	if busy():
		return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://craft"))
	var req_path := ProjectSettings.globalize_path("user://craft/requete.json")
	var out_path := ProjectSettings.globalize_path("user://craft/reponse.json")
	var f := FileAccess.open(req_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(req, "  "))
	f.close()
	if FileAccess.file_exists(out_path):
		DirAccess.remove_absolute(out_path)
	_job = job
	_thread = Thread.new()
	_thread.start(_run.bind(req_path, out_path))
	return true


func _run(req_path: String, out_path: String) -> void:
	var output := []
	var code := OS.execute(python_cmd, [_script(), req_path, out_path], output, true, false)
	var res: Dictionary = {"ok": false, "error": "Python introuvable (%s, code %d)." % [python_cmd, code]}
	if FileAccess.file_exists(out_path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(out_path))
		if d is Dictionary:
			res = d
	_finish.call_deferred(res)


func _finish(res: Dictionary) -> void:
	_thread.wait_to_finish()
	_thread = null
	finished.emit(_job, res)


func _exit_tree() -> void:
	if _thread:
		_thread.wait_to_finish()
