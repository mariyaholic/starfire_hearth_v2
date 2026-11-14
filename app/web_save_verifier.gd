class_name WebSaveVerifier
extends RefCounted
## Godot's Web FileAccess sync is asynchronous. This verifies the exact auto-save bytes in
## IndexedDB after the browser transaction completes; it never writes browser storage itself.

const TIMEOUT_MS: int = 15000


static func committed(path: String, expected: String) -> bool:
	if not OS.has_feature("web") or not OS.is_userfs_persistent():
		return false
	var id: String = str(Time.get_ticks_usec())
	var config: String = JSON.stringify({"path": ProjectSettings.globalize_path(path), "text": expected, "id": id})
	var script: String = """
	(function (config) {
	  const previous = window.__starfireSaveVerification;
	  if (previous) { previous.cancelled = true; if (previous.db) previous.db.close(); }
	  const state = {id: config.id, status: 'pending', cancelled: false, db: null};
	  window.__starfireSaveVerification = state;
	  function finish(status) {
	    if (state.cancelled) return;
	    state.status = status;
	    if (state.db) state.db.close();
	  }
	  try {
	    if (!window.indexedDB || !window.TextEncoder) { finish('error'); return false; }
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
	        if (state.cancelled || window.__starfireSaveVerification !== state || state.status !== 'pending') return;
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
	            if (state.cancelled || window.__starfireSaveVerification !== state) return;
	            if (matches) finish('committed'); else requestAnimationFrame(poll);
	          };
	          transaction.onerror = function () { finish('error'); };
	          transaction.onabort = function () { finish('error'); };
	        } catch (_) { finish('error'); }
	      }
	      poll();
	    };
	    return true;
	  } catch (_) { finish('error'); return false; }
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
		var status: String = str(JavaScriptBridge.eval("window.__starfireSaveVerification && window.__starfireSaveVerification.id === %s ? window.__starfireSaveVerification.status : 'error'" % JSON.stringify(id), true))
		if status == "committed":
			success = true
			break
		if status == "error":
			break
	JavaScriptBridge.eval("(function(){var s=window.__starfireSaveVerification;if(s && s.id === %s){s.cancelled=true;if(s.db)s.db.close();delete window.__starfireSaveVerification;}})()" % JSON.stringify(id), true)
	return success
