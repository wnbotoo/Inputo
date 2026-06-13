# Third-Party Notices

This file tracks direct dependency license notes for the repository. It is not a substitute for dependency lockfile review before a release.

## JavaScript

The Web composer workspace at `packages/web-composer` currently declares these direct JavaScript package dependencies:

| Package | Purpose |
| --- | --- |
| `react` | Web composer UI runtime |
| `react-dom` | React DOM rendering |
| `@vitejs/plugin-react` | Vite React build integration |
| `@types/node` | TypeScript Node.js type definitions |
| `@types/react` | TypeScript React type definitions |
| `@types/react-dom` | TypeScript React DOM type definitions |
| `typescript` | TypeScript compiler |
| `vite` | Web composer development and build tool |
| `vitest` | Web composer test runner |

Before publishing a release, review the full transitive dependency tree from `packages/web-composer/pnpm-lock.yaml` and update this file if any dependency requires attribution beyond its package metadata.

## Swift

`apps/macos/InputoModules` currently uses only Apple platform SDKs and the Swift standard library. Add notices here if external SwiftPM dependencies are introduced.
