# Branching campaign art

The request contains 63 assets: 15 story scenes, 27 endings, and 21 portraits.

The original 47 renders were unavailable in the restored workspace. Their IDs are listed in [missing_prior_renders.json](missing_prior_renders.json); this is historical evidence, not a list of downloadable files. All 42 story and ending renders, including Quiet Foreclosure, still require recovery.

The Owner authorized regeneration of five missing neutral portraits, their 15 expression variants, and a stronger redo of Director Hale hollow in [resume_art_prompt.md](resume_art_prompt.md). Follow [resume_queue.json](resume_queue.json) in order. Exactly one image request may be active. Save the native PNG, verify it, update [manifest.json](manifest.json), then commit and push that single picture before starting the next. Expressions must use their own neutral file as the sole reference.

Native dimensions, SHA-256, reference hashes and verification observations are recorded per item in the manifest. `regenerated_neutral` identifies newly recreated neutral references; `generated` identifies completed variants. `completed_in_prior_chat_file_unavailable` means the old render is still missing. File paths are relative to this directory and reference paths to the repository root.

[Original prompts](source_prompts.txt) are preserved. These are green-background source assets for Owner and Ava review. Do not import into the game yet.

## Completed sequential resume

All 21 queued pictures are present: five regenerated neutrals, 15 expressions, and Hale hollow redo. Each has its own pushed picture commit. No generation calls failed. See [REVIEW.md](REVIEW.md) for the full ID/status/dimensions table, visual issues, 42 still-missing scene/ending IDs, and checkpoint history. Owner and Ava review is still required before game import.
