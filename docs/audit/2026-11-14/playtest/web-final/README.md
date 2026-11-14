# Final release actual manual-save proof

PASS: actual Menu → Save, first observed green “Game saved.” success toast → immediate same-script page reload, actual title Continue, then explicit Load of the manual slot. No turn was advanced. `manual_1.json` exists after reload and its entire authoritative simulation equals the initial actual-play S1turn2 save. Its saved envelope bytes remain identical after Continue and explicit Load. The paired comparison JSON records checksums and timing.

The initial fixture is a normal SaveSerializer save produced by earlier actual S1 play, seeded before this fresh browser context's first app load. Subsequent actions are actual mouse/keyboard inputs; no runtime game/state methods or production instrumentation were used. The artifact is the lead's full final release at `/workspace/starfire-evidence/audit-final/build/web`, fingerprinted here.

The acknowledgment detector samples a real screenshot region containing the toast. It reloads on the first observed green-success sample without a post-ack wait, added screenshot or human inspection. The success crop visibly says “Game saved.”. Timing includes coarse software-GL screenshot readback: polls around12.6s and21s do NOT establish exact save latency or a21-second UI response. The reported detection→reload call gap only documents same-script ordering.

Accepted resumed/load frames prove active UI/date and successful parsing, not completed terrain rendering: the 3D viewport is still gray in those captures. The independent reviewer inspected that limit. No browser console/page error occurred. Browser, context and private HTTP server closed cleanly. This is desktop Chromium software rendering, not a physical-device performance test.
