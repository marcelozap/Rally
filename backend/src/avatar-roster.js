/** Older clients must not erase a player selected by a roster-aware client. */
export function preserveAthletePreset(serverAvatar, clientAvatar) {
  if (
    !clientAvatar ||
    typeof clientAvatar !== "object" ||
    clientAvatar.athletePresetRaw != null ||
    !serverAvatar?.athletePresetRaw
  ) {
    return clientAvatar;
  }

  return { ...clientAvatar, athletePresetRaw: serverAvatar.athletePresetRaw };
}
