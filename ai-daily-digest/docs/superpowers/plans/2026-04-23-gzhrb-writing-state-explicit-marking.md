# GZHRB Writing State Explicit Marking Implementation Plan

**Goal:** Add explicit `khazix` / `wechat` completion marking, append-only execution logs, and a dedicated inspection entrypoint while keeping file evidence as the final readiness truth.

**Architecture:** Extend workitem JSON with richer `writing_state` metadata and `execution_log`, add two marking scripts plus one inspection script, and enhance the validator to report both declared and evidence-derived state.

**Tech Stack:** PowerShell 5.1 scripts, UTF-8 JSON file IO, existing workitem JSON structure, PowerShell tests under `scripts/tests`

---

### Task 1: Extend Workitem Initialization Shape

**Files:**
- Modify: `scripts/prepare-gzhrb-writing-workspace.ps1`
- Modify: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`

- [ ] Add failing assertions for expanded `writing_state` fields and empty `execution_log`
- [ ] Run the test and confirm failure
- [ ] Implement minimal JSON initialization changes
- [ ] Re-run the test and confirm pass

### Task 2: Add Explicit Marking Tests First

**Files:**
- Create: `scripts/tests/mark-gzhrb-writing-state.tests.ps1`

- [ ] Add failing tests for `mark-gzhrb-khazix-complete.ps1`
- [ ] Add failing tests for `mark-gzhrb-wechat-complete.ps1`
- [ ] Cover refusal when evidence is missing or placeholder
- [ ] Run the test and confirm failure before implementation

### Task 3: Implement Explicit Marking Scripts

**Files:**
- Create: `scripts/mark-gzhrb-khazix-complete.ps1`
- Create: `scripts/mark-gzhrb-wechat-complete.ps1`
- Modify: `scripts/validate-gzhrb-writing-state.ps1` if shared helpers are needed

- [ ] Implement shared workitem read/write helpers if needed
- [ ] Implement `mark-gzhrb-khazix-complete.ps1`
- [ ] Implement `mark-gzhrb-wechat-complete.ps1`
- [ ] Ensure each script appends an execution log entry
- [ ] Run marking tests and confirm pass

### Task 4: Enhance Validator Output

**Files:**
- Modify: `scripts/validate-gzhrb-writing-state.ps1`
- Modify: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`

- [ ] Add failing assertions for `declared_stage`, `evidence_stage`, `state_matches_evidence`, `writing_state`, and log tail output
- [ ] Run the validator test and confirm failure
- [ ] Implement minimal output expansion
- [ ] Re-run the validator test and confirm pass

### Task 5: Add Inspection Entrypoint

**Files:**
- Create: `scripts/inspect-gzhrb-writing-state.ps1`
- Create: `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`

- [ ] Add failing inspection test for readable output / JSON shape
- [ ] Run the inspection test and confirm failure
- [ ] Implement inspection script by reusing validator output
- [ ] Re-run the inspection test and confirm pass

### Task 6: Keep Post-Writing Gate Correct

**Files:**
- Modify only if needed: `scripts/run-gzhrb-postwriting-pipeline.ps1`
- Verify: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

- [ ] Confirm post-writing still uses evidence-derived readiness
- [ ] If output fields changed, update the script minimally
- [ ] Re-run the pipeline test and confirm pass

### Task 7: Verify Whole Enhancement

**Files:**
- Verify: `scripts/tests/prepare-gzhrb-writing-workspace.tests.ps1`
- Verify: `scripts/tests/mark-gzhrb-writing-state.tests.ps1`
- Verify: `scripts/tests/validate-gzhrb-writing-state.tests.ps1`
- Verify: `scripts/tests/inspect-gzhrb-writing-state.tests.ps1`
- Verify: `scripts/tests/run-gzhrb-postwriting-pipeline.tests.ps1`

- [ ] Run all five tests
- [ ] Review targeted diff only
- [ ] Confirm no unintended path or stage regressions
