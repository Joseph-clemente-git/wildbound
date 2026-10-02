# UI/UX review — applying the `ui-ux-game` skill

This review checks Wildbound's interface against the `ui-ux-game` skill's principles,
patterns, onboarding flow and accessibility checklist.

## Principles → findings → changes

| Principle | Before | After |
| --- | --- | --- |
| **Less is more** | Full-width lodge bar; six station labels always on; every system's nav visible to the player | Compact chips around the edges; only introduced stations are labelled; navigation appears with the story |
| **Feedback is instant** | Buttons only clicked; health snapped; coins changed silently; toasts overlapped | Press dip on every button; trailing damage bar; coin count-up with chime; stacked, grouped notifications |
| **Teach by doing** | 12-beat opening; tutorial taught through text hints | 8-beat opening; in-world wind-up warnings (! / !! / ◆); the right button pulses in the tutorial trial |
| **Consistency** | Selected tabs used the amber primary-action style | Separate tab style; amber is reserved for actions and objectives; one meaning per colour |
| **Accessibility** | Volume, control size and handedness only | See the checklist below; first-launch comfort setup |
| **Mobile-first** | Touch targets ≥ 64 px, safe areas | Unchanged, plus readable bar labels at every text size |
| **State always visible** | No marker on the first objective; new systems unannounced | Marker over the champion; NEW and attention badges; objective ring on the ground |

## Patterns used

- **HUD overlay**: lodge chips and battle bars with numbers; the 3D world stays the visual priority.
- **Tab navigation with badges**: lodge navigation (NEW, ● attention), plus tabs in settings, panels and the Codex.
- **Modal dialog**: confirmations, settings, comfort setup, pause.
- **Toast notification**: `Notify` autoload — stacked, auto-dismissed, duplicates grouped, history kept in the Journal.
- **Progress bar**: experience, mastery, energy and bond, with words and values on top.
- **Health bar with damage trail** and **resource bar with low threshold** (from `hud-components.ts`).

## Onboarding flow

1. **First interaction**: "Meet Bruno", with a marker over the dog, then tapping him.
2. **First reward**: training results, the growth chime and coins counting up.
3. **First choice**: picking what the mentor should develop.
4. **First failure**: a defeat is a knockout, never worse, and the result screen offers "Rest & recover".
5. **First system unlock**: new navigation appears with a NEW badge until opened.

## Accessibility checklist status

**Visual**
- [x] Colour-blind palettes: deuteranopia, protanopia, tritanopia.
- [x] Information is never colour-only: bars carry text, telegraphs differ by shape, badges use words or symbols.
- [x] Text scaling (90–150%), applied live through the shared theme.
- [x] High contrast mode.
- [x] Screen shake intensity slider, including off.
- [x] Flash toggle (Reduce flashes).
- [x] Adjustable battle-control opacity and control size.
- [x] Reduce motion.
- [x] Visual cues for interactables: ground rings, objective ring, markers.

**Audio**
- [x] Separate volume sliders: master, music/ambience, effects.
- [x] Subtitles for all dialogue, with speaker names; story text follows the text size.
- [x] Haptics paired with hits (Vibration toggle).

**Motor**
- [x] Toggle vs hold for Block.
- [x] Left-handed layout.
- [x] Scalable controls.
- [x] Pause any time.
- [x] Combat assist (longer telegraphs, wider perfect windows), changeable any time without penalty.

**Cognitive**
- [x] Replayable Guide in the Codex, plus "Replay the opening".
- [x] Persistent objective and quest progress.
- [x] Notification history (Journal).
- [x] Consistent layout.
- [x] Generous autosave.

**Setup**
- [x] Accessibility options are offered on first launch ("Before we begin") and are reachable from the title screen.

**Not yet done** (recommended next steps)
- [ ] Full key/gamepad remapping UI.
- [ ] Mono audio.
- [ ] Captions for non-dialogue sounds.
- [ ] Text-to-speech.
- [ ] Export/import of settings profiles.
