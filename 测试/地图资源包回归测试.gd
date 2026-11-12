extends SceneTree

## 不依赖素材或服务端；动态挂载一个只有占位文本的 PCK，覆盖索引和本地图目录两条分支。
## python 测试/跑地图资源包回归.py --godot /path/to/godot

var failures := 0
var checks := 0


func _initialize() -> void:
	var result := _run()
	if result != OK:
		_expect(false, "创建/挂载 PCK 夹具失败：%s" % error_string(result))
	print("地图资源包回归：%s（%d 项检查，红 %d 项）" % ["通过" if failures == 0 else "不通过", checks, failures])
	quit(1 if failures > 0 else 0)


func _run() -> Error:
	var fixture_name := "map-asset-pck-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var source_path := "user://%s.txt" % fixture_name
	var pack_path := "user://%s.pck" % fixture_name
	var source := FileAccess.open(source_path, FileAccess.WRITE)
	if source == null:
		return FileAccess.get_open_error()
	source.store_string("map resource PCK fixture")
	source.close()
	var asset_root := "res://素材/地图/%s" % fixture_name
	var indexed := asset_root.path_join("地图物件/索引目录")
	var local := asset_root.path_join("地图物件/本地图目录")
	var packer := PCKPacker.new()
	var result := packer.pck_start(pack_path)
	if result == OK:
		result = packer.add_file(indexed.path_join("fixture.txt"), source_path)
	if result == OK:
		result = packer.add_file(local.path_join("fixture.txt"), source_path)
	if result == OK:
		result = packer.flush()
	packer = null
	if result != OK:
		_cleanup(source_path, pack_path)
		return result
	if not ProjectSettings.load_resource_pack(pack_path):
		_cleanup(source_path, pack_path)
		return ERR_CANT_OPEN

	# 资源只存在于 PCK，不应依赖工作区是否补齐游戏素材。
	_expect(DirAccess.dir_exists_absolute(indexed), "PCK 内的 res:// 目录存在")
	_expect(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(indexed)), "同名物理目录不存在，确实覆盖 PCK 虚拟路径")
	var maps = load("res://脚本/地图/地图资源.gd")
	var old_loaded: bool = maps._loaded
	var old_folders: Dictionary = maps._map_folders
	var old_paths: Dictionary = maps._asset_paths
	maps._loaded = true
	maps._map_folders = {"pck-test-map": fixture_name}
	maps._asset_paths = {"地图物件/索引目录": indexed}
	_expect(maps.find_asset_directory("pck-test-map", "地图物件", "索引目录") == indexed, "从素材索引定位 PCK 目录")
	_expect(maps.find_asset_directory("pck-test-map", "地图物件", "本地图目录") == local, "索引未命中时从本地图定位 PCK 目录")
	maps._asset_paths = {"地图物件/本地图目录": asset_root.path_join("不存在的索引目录")}
	_expect(maps.find_asset_directory("pck-test-map", "地图物件", "本地图目录") == local, "失效索引应回退到本地图目录")
	_expect(maps.find_asset_directory("pck-test-map", "地图物件", "不存在") == "", "不存在的目录保持返回空字符串")
	_expect(FileAccess.get_file_as_string(indexed.path_join("fixture.txt")) == "map resource PCK fixture", "定位后的目录可读取包内文件")
	maps._loaded = old_loaded
	maps._map_folders = old_folders
	maps._asset_paths = old_paths
	_cleanup(source_path, pack_path)
	return OK


func _expect(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["通过" if passed else "失败", message])


func _cleanup(source_path: String, pack_path: String) -> void:
	DirAccess.remove_absolute(source_path)
	DirAccess.remove_absolute(pack_path)
