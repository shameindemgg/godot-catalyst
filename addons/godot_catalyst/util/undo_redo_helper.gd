@tool
class_name CatalystUndoRedoHelper
extends RefCounted
## Helper to wrap editor operations with UndoRedo for full undo support.


static func get_undo_redo() -> EditorUndoRedoManager:
	return EditorInterface.get_editor_undo_redo()


static func do_action(action_name: String, do_callable: Callable, undo_callable: Callable) -> void:
	# Godot 4.6: EditorUndoRedoManager.add_do_method now requires (Object, StringName, ...args).
	# Decompose the Callables via get_object / get_method / get_bound_arguments and re-dispatch.
	var ur := get_undo_redo()
	ur.create_action(action_name)
	var do_args: Array = [do_callable.get_object(), do_callable.get_method()]
	do_args.append_array(do_callable.get_bound_arguments())
	ur.add_do_method.callv(do_args)
	var undo_args: Array = [undo_callable.get_object(), undo_callable.get_method()]
	undo_args.append_array(undo_callable.get_bound_arguments())
	ur.add_undo_method.callv(undo_args)
	ur.commit_action()
