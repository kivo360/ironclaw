import JSON5 from "json5";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import type { RuntimeEnv } from "../runtime.js";
import { resolveBundledSkillsDir } from "../agents/skills/bundled-dir.js";
import { DEFAULT_AGENT_WORKSPACE_DIR, ensureAgentWorkspace } from "../agents/workspace.js";
import { type OpenClawConfig, createConfigIO, writeConfigFile } from "../config/config.js";
import { formatConfigPath, logConfigUpdated } from "../config/logging.js";
import { resolveSessionTranscriptsDir } from "../config/sessions.js";
import { defaultRuntime } from "../runtime.js";
import { shortenHomePath } from "../utils.js";

async function readConfigFileRaw(configPath: string): Promise<{
  exists: boolean;
  parsed: OpenClawConfig;
}> {
  try {
    const raw = await fs.readFile(configPath, "utf-8");
    const parsed = JSON5.parse(raw);
    if (parsed && typeof parsed === "object") {
      return { exists: true, parsed: parsed as OpenClawConfig };
    }
    return { exists: true, parsed: {} };
  } catch {
    return { exists: false, parsed: {} };
  }
}

export async function setupCommand(
  opts?: { workspace?: string },
  runtime: RuntimeEnv = defaultRuntime,
) {
  const desiredWorkspace =
    typeof opts?.workspace === "string" && opts.workspace.trim()
      ? opts.workspace.trim()
      : undefined;

  const io = createConfigIO();
  const configPath = io.configPath;
  const existingRaw = await readConfigFileRaw(configPath);
  const cfg = existingRaw.parsed;
  const defaults = cfg.agents?.defaults ?? {};

  const workspace = desiredWorkspace ?? defaults.workspace ?? DEFAULT_AGENT_WORKSPACE_DIR;

  const next: OpenClawConfig = {
    ...cfg,
    agents: {
      ...cfg.agents,
      defaults: {
        ...defaults,
        workspace,
      },
    },
  };

  if (!existingRaw.exists || defaults.workspace !== workspace) {
    await writeConfigFile(next);
    if (!existingRaw.exists) {
      runtime.log(`Wrote ${formatConfigPath(configPath)}`);
    } else {
      logConfigUpdated(runtime, { path: configPath, suffix: "(set agents.defaults.workspace)" });
    }
  } else {
    runtime.log(`Config OK: ${formatConfigPath(configPath)}`);
  }

  const ws = await ensureAgentWorkspace({
    dir: workspace,
    ensureBootstrapFiles: !next.agents?.defaults?.skipBootstrap,
  });
  runtime.log(`Workspace OK: ${shortenHomePath(ws.dir)}`);

  const bundledSkillsDir = resolveBundledSkillsDir();
  if (bundledSkillsDir) {
    const userSkillsDir = path.join(os.homedir(), ".openclaw", "skills");
    try {
      const stat = await fs.lstat(userSkillsDir).catch(() => null);
      if (!stat) {
        await fs.mkdir(path.dirname(userSkillsDir), { recursive: true });
        await fs.symlink(bundledSkillsDir, userSkillsDir, "dir");
        runtime.log(
          `Skills OK: ${shortenHomePath(userSkillsDir)} → ${shortenHomePath(bundledSkillsDir)}`,
        );
      } else {
        runtime.log(`Skills OK: ${shortenHomePath(userSkillsDir)}`);
      }
    } catch {
      runtime.log(`Skills: skipped symlink (${shortenHomePath(userSkillsDir)})`);
    }
  }

  const sessionsDir = resolveSessionTranscriptsDir();
  await fs.mkdir(sessionsDir, { recursive: true });
  runtime.log(`Sessions OK: ${shortenHomePath(sessionsDir)}`);
}
