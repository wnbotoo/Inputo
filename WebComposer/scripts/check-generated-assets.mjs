import { spawnSync } from "node:child_process";
import { existsSync, mkdtempSync, readdirSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const workspaceDir = resolve(scriptDir, "..");
const repoRoot = resolve(workspaceDir, "..");
const bundledAssetsDir = join(
  repoRoot,
  "InputoModules",
  "Sources",
  "InputoComposerFeature",
  "Resources",
  "WebComposer"
);
const tempRoot = mkdtempSync(join(tmpdir(), "inputo-webcomposer-assets-"));
const generatedDir = join(tempRoot, "WebComposer");
const viteBin = join(
  workspaceDir,
  "node_modules",
  ".bin",
  process.platform === "win32" ? "vite.cmd" : "vite"
);

if (!existsSync(viteBin)) {
  fail(`Missing local Vite binary. Run npm install in ${workspaceDir} first.`);
}

const build = spawnSync(
  viteBin,
  ["build", "--outDir", generatedDir, "--emptyOutDir"],
  {
    cwd: workspaceDir,
    stdio: "inherit"
  }
);

if (build.status !== 0) {
  fail(`Vite build failed with exit code ${build.status ?? "unknown"}.`);
}

const bundledFiles = listFiles(bundledAssetsDir);
const generatedFiles = listFiles(generatedDir);
const mismatches = [];

if (bundledFiles.join("\n") !== generatedFiles.join("\n")) {
  mismatches.push(
    `file list differs\nbundled: ${bundledFiles.join(", ")}\ngenerated: ${generatedFiles.join(", ")}`
  );
}

for (const file of generatedFiles) {
  const generatedPath = join(generatedDir, file);
  const bundledPath = join(bundledAssetsDir, file);
  if (!existsSync(bundledPath)) {
    continue;
  }
  const generated = readFileSync(generatedPath);
  const bundled = readFileSync(bundledPath);
  if (!generated.equals(bundled)) {
    mismatches.push(file);
  }
}

if (mismatches.length > 0) {
  console.error("Generated WebComposer assets do not match checked-in bundled assets:");
  for (const mismatch of mismatches) {
    console.error(`- ${mismatch}`);
  }
  console.error("");
  console.error("Run `npm run build` in WebComposer and commit the regenerated assets.");
  console.error(`Generated comparison output was left at ${generatedDir}`);
  process.exit(1);
}

rmSync(tempRoot, { recursive: true, force: true });
console.log(`Generated WebComposer assets match ${relative(repoRoot, bundledAssetsDir)}.`);

function listFiles(root) {
  return walk(root)
    .map((path) => relative(root, path))
    .sort();
}

function walk(root) {
  const entries = readdirSync(root, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const path = join(root, entry.name);
    if (entry.isDirectory()) {
      files.push(...walk(path));
    } else if (entry.isFile()) {
      files.push(path);
    } else {
      fail(`Unsupported asset entry: ${basename(path)}`);
    }
  }
  return files;
}

function fail(message) {
  console.error(message);
  process.exit(1);
}
