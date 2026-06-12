## Summary

<!-- What changed, and why? -->

## Verification

<!-- List commands run and manual QA performed. -->

- [ ] `swift test --package-path apps/macos/InputoModules`
- [ ] `xcodebuild -project apps/macos/Inputo.xcodeproj -scheme Inputo -configuration Debug -derivedDataPath .build/XcodeDerivedData CODE_SIGNING_ALLOWED=NO build`
- [ ] `npm --prefix packages/web-composer run verify` when Web composer source or bundled assets changed
- [ ] Manual QA notes added for UI, clipboard, provider, permission, anchor, or bridge behavior

## Privacy and Security

- [ ] No API keys, prompts, generated confidential text, local paths, or sensitive screenshots are included
- [ ] Privacy boundaries are unchanged, or documentation was updated
- [ ] Clipboard writes, app activation, file access, provider calls, and native tools still require explicit user intent where applicable

## Docs

- [ ] README/docs updated, or this change does not affect user-facing behavior, architecture, commands, paths, or privacy boundaries
