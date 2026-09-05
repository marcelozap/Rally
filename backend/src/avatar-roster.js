/** Older clients must not erase model or color choices they do not understand. */
export function preserveAthletePreset(serverAvatar, clientAvatar) {
  if (!clientAvatar || typeof clientAvatar !== "object") {
    return clientAvatar;
  }

  const preserved = {};
  for (const key of ["athletePresetRaw", "skinToneOverrideRaw", "hairColorOverrideHex"]) {
    if (clientAvatar[key] == null && serverAvatar?.[key] != null) {
      preserved[key] = serverAvatar[key];
    }
  }
  return { ...clientAvatar, ...preserved };
}
