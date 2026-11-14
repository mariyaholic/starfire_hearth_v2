class_name WebSaveVerifier
extends RefCounted
## Godot's Web FileAccess sync is asynchronous. This verifies exact save bytes in
## IndexedDB after the browser transaction completes; it never writes browser storage itself.

const TIMEOUT_MS: int = 15000
const MAX_PENDING: int = 8
static var _next_id: int = 0


static func committed(path: String, expected: String) -> bool:
	if not OS.has_feature("web") or not OS.is_userfs_persistent():
		return false
	_next_id += 1
	var id: String = "%d-%d" % [Time.get_ticks_usec(), _next_id]
	var config: String = JSON.stringify({"path": ProjectSettings.globalize_path(path), "text": expected, "id": id, "limit": MAX_PENDING})
	var script: String = """
	(function (config) {
	  const operations = window.__starfireSaveVerifications ||= Object.create(null);
	  if (Object.keys(operations).length >= config.limit) return false;
	  const state = {id: config.id, status: 'pending', cancelled: false, db: null};
	  operations[config.id] = state;
	  function finish(status) {
	    if (state.cancelled) return;
	    state.status = status;
	    if (state.db) state.db.close();
	  }
	  try {
	    if (!window.indexedDB || !window.TextEncoder) { finish('error'); return true; }
	    const expected = new TextEncoder().encode(config.text);
	    const request = indexedDB.open('/userfs');
	    request.onupgradeneeded = function () { request.transaction.abort(); };
	    request.onerror = function () { finish('error'); };
	    request.onblocked = function () { finish('error'); };
	    request.onsuccess = function () {
	      const db = request.result;
	      if (state.cancelled || state.status !== 'pending') { db.close(); return; }
	      state.db = db;
	      if (!db.objectStoreNames.contains('FILE_DATA')) { finish('error'); return; }
	      function poll() {
	        if (state.cancelled || operations[config.id] !== state || state.status !== 'pending') return;
	        try {
	          const transaction = db.transaction('FILE_DATA', 'readonly');
	          const read = transaction.objectStore('FILE_DATA').get(config.path);
	          let matches = false;
	          read.onsuccess = function () {
	            try {
	              const record = read.result;
	              const actual = record && record.contents;
	              matches = !!actual && actual.byteLength === expected.byteLength;
	              if (matches) {
	                const bytes = new Uint8Array(actual.buffer, actual.byteOffset, actual.byteLength);
	                for (let i = 0; i < expected.length; i++) {
	                  if (bytes[i] !== expected[i]) { matches = false; break; }
	                }
	              }
	            } catch (_) { matches = false; }
	          };
	          transaction.oncomplete = function () {
	            if (state.cancelled || operations[config.id] !== state) return;
	            if (matches) finish('committed'); else requestAnimationFrame(poll);
	          };
	          transaction.onerror = function () { finish('error'); };
	          transaction.onabort = function () { finish('error'); };
	        } catch (_) { finish('error'); }
	      }
	      poll();
	    };
	    return true;
	  } catch (_) { finish('error'); return true; }
	})(%s)
	""" % config
	# FileAccess already marks the filesystem dirty. Re-requesting the flush ensures that a
	# write made during an earlier sync is included in a subsequent sync.
	JavaScriptBridge.force_fs_sync()
	if not bool(JavaScriptBridge.eval(script, true)):
		return false
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MS
	var success: bool = false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		var status: String = str(JavaScriptBridge.eval("window.__starfireSaveVerifications && window.__starfireSaveVerifications[%s] ? window.__starfireSaveVerifications[%s].status : 'error'" % [JSON.stringify(id), JSON.stringify(id)], true))
		if status == "committed":
			success = true
			break
		if status == "error":
			break
	JavaScriptBridge.eval("(function(){var all=window.__starfireSaveVerifications;var id=%s;var s=all && all[id];if(s){s.cancelled=true;if(s.db)s.db.close();delete all[id];}})()" % JSON.stringify(id), true)
	return success
