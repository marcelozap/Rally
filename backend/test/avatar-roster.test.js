import assert from "node:assert/strict";
import test from "node:test";
import { preserveAthletePreset } from "../src/avatar-roster.js";

test("legacy avatar upload retains the saved player while updating clothing", () => {
  const stored = { athletePresetRaw: "femaleBlack", equippedTopID: "old.top" };
  const uploaded = { equippedTopID: "new.top", playerName: "Returning player" };

  const merged = preserveAthletePreset(stored, uploaded);

  assert.deepEqual(merged, { ...uploaded, athletePresetRaw: "femaleBlack" });
  assert.equal(stored.equippedTopID, "old.top");
  assert.equal(uploaded.athletePresetRaw, undefined);
});

test("an explicit player selection replaces the stored selection", () => {
  const uploaded = { athletePresetRaw: "maleAsian", equippedTopID: "new.top" };

  assert.deepEqual(
    preserveAthletePreset({ athletePresetRaw: "femaleEuropean" }, uploaded),
    uploaded
  );
});

test("null from a legacy client cannot clear an existing player", () => {
  assert.equal(
    preserveAthletePreset({ athletePresetRaw: "femaleAsian" }, { athletePresetRaw: null }).athletePresetRaw,
    "femaleAsian"
  );
});

test("an older stored avatar without a preset remains compatible", () => {
  const uploaded = { equippedShoesID: "new.shoes" };
  assert.deepEqual(preserveAthletePreset({}, uploaded), uploaded);
  assert.deepEqual(preserveAthletePreset(undefined, uploaded), uploaded);
});

test("a progress-only upload does not invent an avatar", () => {
  assert.equal(preserveAthletePreset({ athletePresetRaw: "maleBlack" }, undefined), undefined);
});

test("older model-aware clients cannot erase later skin and hair choices", () => {
  const stored = {
    athletePresetRaw: "femaleBlack",
    skinToneOverrideRaw: "tan",
    hairColorOverrideHex: "#D9B477",
  };
  const uploaded = {
    athletePresetRaw: "maleAsian",
    equippedTopID: "new.top",
    hairColorOverrideHex: null,
  };
  assert.deepEqual(preserveAthletePreset(stored, uploaded), {
    ...uploaded,
    skinToneOverrideRaw: "tan",
    hairColorOverrideHex: "#D9B477",
  });
});

test("explicit color choices replace the saved colors without changing the model", () => {
  const stored = { athletePresetRaw: "maleEuropean", skinToneOverrideRaw: "tan", hairColorOverrideHex: "#080809" };
  const uploaded = { skinToneOverrideRaw: "rich", hairColorOverrideHex: "#B3ADB0" };
  assert.deepEqual(preserveAthletePreset(stored, uploaded), {
    ...uploaded,
    athletePresetRaw: "maleEuropean",
  });
});
