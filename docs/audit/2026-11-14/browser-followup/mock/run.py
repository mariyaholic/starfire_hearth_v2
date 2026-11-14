"""Independent mock-only harness failure accounting; no real browser or render."""
import json, os, pathlib, subprocess
root = pathlib.Path(__file__).resolve().parent
repo = pathlib.Path('/workspace/starfire_hearth_v2')
summaries = []
for case in ['pass', 'capture', 'hash', 'error']:
    out = root / case
    env = os.environ | {'PLAYWRIGHT_DIR': str(root/'node_modules'), 'MOCK_CASE': case,
                        'MOCK_AUDIT': str(root/f'{case}-audit.json')}
    process = subprocess.run(['node', 'tools/web_smoke.mjs', '--build', 'build/web-smoke',
                              '--out', str(out), '--expect-hash', '911cdd430061'],
                             cwd=repo, env=env, text=True, capture_output=True, timeout=10)
    (root/f'{case}.log').write_text(process.stdout + process.stderr)
    results = [json.loads((out/f'web_{profile}_result.json').read_text())
               for profile in ['pc', 'phone', 'ipad']]
    audit = json.loads((root/f'{case}-audit.json').read_text())
    assert process.returncode == (0 if case == 'pass' else 1), (case, process.returncode, process.stdout, process.stderr)
    assert audit['launches'] == 3 and audit['contexts'] == 6 and audit['closed'] == 6, audit
    assert audit['maxActive'] == 1 and audit['active'] == 0 and len(audit['screenshots']) == 6, audit
    assert all(not result['problems'] for result in results[:2]), results
    if case != 'pass':
        assert results[2]['problems'], results[2]
    if case == 'capture':
        assert results[2]['diagnostics'][0]['stage'] == 'game screenshot', results[2]
    summaries.append({'case': case, 'assertions_passed': True, 'exit_code': process.returncode,
                      'browsers_launched': audit['launches'], 'contexts_closed': audit['closed'],
                      'max_live_contexts': audit['maxActive'], 'capture_attempts': len(audit['screenshots']),
                      'ipad_problem_count': len(results[2]['problems'])})
summary = {'method': 'mock Playwright module; no real browser, screenshots or gameplay', 'cases': summaries}
(root/'result.json').write_text(json.dumps(summary, indent=2) + '\n')
print(json.dumps(summary, indent=2))
