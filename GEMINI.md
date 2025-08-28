# Gemini Assistant Guidelines for Roblox Development

This document provides guidelines for the Gemini AI assistant to ensure its contributions are consistent with the project's standards, architecture, and conventions.

## 1. Project Overview

- **Project Name:** AFK Clicker
- **Objective:** A Roblox game where players earn points by being AFK (Away From Keyboard). It includes features like leaderboards, daily rewards, and an in-game shop.
- **Technology:** The project is built with Luau and uses the Rojo toolchain to sync files from the local file system into a Roblox place.

## 2. Core Principles & Conventions

### 2.1. Rojo Project Structure

The project strictly follows a Rojo-based workflow. The `default.project.json` file defines the mapping between the `src` directory and the Roblox game hierarchy.

- **NEVER** modify files outside the `src` directory unless it's for configuration (e.g., `selene.toml`).
- **ALWAYS** create new files in the correct location within `src` to match the desired in-game hierarchy (e.g., a new server script goes into `src/ServerScriptService`).
- Pay close attention to `.client.luau` (for `LocalScript`) and `.server.luau` (for `Script`) extensions. ModuleScripts should just be `.luau`.

### 2.2. Language and Style

- **Language:** All code is written in **Luau** with `--!strict` type checking enabled.
- **Style Guide:** Adhere to the official [Roblox Lua Style Guide](https://roblox.github.io/lua-style-guide/).
- **Linting:** The project uses **Selene** for linting. Before finalizing any code changes, run `selene .` and fix all reported issues.
- **Naming Conventions:**
    - `PascalCase` for classes, modules, and UI elements (e.g., `AFKPointEngine`, `MainButton`).
    - `camelCase` for functions, methods, and variables (e.g., `calculatePoints`, `playerData`).
    - `_private` prefix for methods not intended for external use.

### 2.3. Modularity and Single Responsibility

- Create small, reusable modules with a single, clear purpose.
- Use `RobustRequire` (in `src/ReplicatedStorage/Utils/`) for safely loading modules.
- Avoid monolithic scripts. Break down complex systems into smaller, interconnected modules (e.g., `AFKPointEngine`, `AFKPointConfig`, `AFKPointUtils`).

## 3. Tooling & Workflow

- **Tool Management:** `aftman.toml` manages project tools like Rojo and Selene.
- **Linting Workflow:**
    1. Make code changes.
    2. Run `selene .` in the terminal.
    3. Fix any errors or warnings reported by Selene.
- **Testing:** The project contains a test runner (`TestRunner.server.luau`). For any new core logic, especially in engines or utility modules, create a corresponding test file (e.g., `MyModule.spec.luau`) and add it to the test runner.

## 4. Key Modules & Architecture

Familiarize yourself with these critical modules before making changes.

### 4.1. Core Utilities (`src/ReplicatedStorage/Utils/`)

- **`Maid.luau`:** A utility class for cleaning up connections, instances, and other objects. **ALWAYS** use a Maid for objects with a lifecycle to prevent memory leaks.
- **`RemoteSignal.luau`:** The primary tool for client-server communication. Use this instead of creating new `RemoteEvent` or `RemoteFunction` instances manually.
- **`Ticker.luau`:** A centralized heartbeat/update loop manager. Use this for running code on a timer or every frame instead of creating new `RunService` connections.
- **`UIController.luau`:** A framework for managing UI components and their state. Use this for all new UI development.

### 4.2. Game Systems

- **AFK System:**
    - **Engine:** `src/ServerScriptService/AFKSystem/AFKPointEngine.luau` (server-side logic).
    - **Client:** `src/StarterPlayerScripts/AFKPointClient.client.luau` (client-side logic).
    - **Configuration:** `src/ReplicatedStorage/AFKSystem/AFKPointConfig.luau`.
- **Daily Rewards System:**
    - **Engine:** `src/ServerScriptService/DailysSystem/DailyRewardEngine.luau`.
    - **Client:** `src/StarterPlayerScripts/DailysUI/DailyRewardClient.luau`.
- **Leaderboards:**
    - **Data Handling:** `src/ServerScriptService/LeaderboardData.luau`.
    - **UI Population:** `src/ReplicatedStorage/Utils/LeaderboardUtils.luau`.

## 5. Task Guidelines

When given a task (e.g., fix a bug, add a feature):

1.  **Understand:** Use `read_file` and `glob` to locate and understand the relevant modules, configurations, and UI files.
2.  **Plan:** Briefly outline the files you will modify and the approach you will take, referencing the conventions in this document.
3.  **Implement:** Write or modify the code, strictly adhering to the project's style and architectural patterns. Use key modules like `Maid` and `RemoteSignal` where appropriate.
4.  **Verify:** After implementation, confirm that the code is clean by running `selene .`. If you added core logic, mention that a test should be written.
5.  **Commit (If Requested):** Propose a commit message following the conventional commit format (e.g., `feat(Dailys): Add streak bonus to rewards`).
