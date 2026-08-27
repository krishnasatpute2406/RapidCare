"""
Multi-Agent Orchestrator for Rapidcare

Agents:
 - Architect (Ollama: llama3.2)
 - Coder (Google GenAI: gemini-2.5-flash, Flask and Flutter/Dart phases)
 - Auditor (Ollama: deepseek-coder)
 - Repair (Gemini / Ollama)
 - Tester (local syntax check)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
import textwrap
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Optional, Tuple

import ollama
from dotenv import load_dotenv
from google import genai

# Load environment variables
load_dotenv()
GOOGLE_API_KEY = os.getenv("GOOGLE_API_KEY")

# Initialize official Google GenAI Client
genai_client = genai.Client(api_key=GOOGLE_API_KEY) if GOOGLE_API_KEY else None

_AI_BRANCH_NAME: Optional[str] = None
_AI_BASE_BRANCH: Optional[str] = None


@dataclass
class AgentResult:
    success: bool
    content: str
    meta: Optional[Dict] = None


def _git(*args: str, check: bool = True) -> subprocess.CompletedProcess:
    """Run a local Git command from the orchestrator repository."""
    repository_root = Path(__file__).resolve().parent
    result = subprocess.run(
        ['git', *args],
        cwd=repository_root,
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"git {' '.join(args)} failed: {detail}")
    return result


def _sanitize_branch_name(task_description: str) -> str:
    slug = re.sub(r'[^a-z0-9]+', '-', task_description.lower()).strip('-')
    return (slug or 'task')[:60].rstrip('-')


def init_ai_branch(task_description: str) -> str:
    """Create or reuse a local AI branch from the branch already checked out."""
    global _AI_BRANCH_NAME, _AI_BASE_BRANCH

    if _AI_BRANCH_NAME:
        raise RuntimeError(f'AI branch already active: {_AI_BRANCH_NAME}')

    _AI_BASE_BRANCH = _git('branch', '--show-current').stdout.strip() or 'HEAD'

    branch_prefix = f'ai-manager/{_sanitize_branch_name(task_description)}'
    branch_exists = _git(
        'show-ref', '--verify', '--quiet', f'refs/heads/{branch_prefix}', check=False
    ).returncode == 0
    if branch_exists:
        branch_name = branch_prefix
        _git('switch', branch_name)
        action = 'Reusing'
    else:
        branch_name = branch_prefix
        _git('switch', '-c', branch_name)
        action = 'Created'

    _AI_BRANCH_NAME = branch_name
    print(f'\n[AI Manager] {action} local safety branch from {_AI_BASE_BRANCH}: {branch_name}')
    return branch_name


def human_approval_gate() -> bool:
    """Show the local diff summary and require explicit human approval."""
    if not _AI_BRANCH_NAME:
        raise RuntimeError('Human approval requires an active AI manager branch.')

    print('\n[AI Manager] Pending changes:')
    diff = _git('diff', '--stat', check=False)
    print(diff.stdout.strip() or '(No tracked-file diff; untracked files are not included in git diff --stat.)')
    response = input('Do you want to approve and commit these changes? (y/n): ')
    return response.strip().lower() in {'y', 'yes'}


def finalize_ai_changes(task_description: str) -> bool:
    """Commit approved changes, merge them into the base branch, or roll back."""
    global _AI_BRANCH_NAME, _AI_BASE_BRANCH

    if not _AI_BRANCH_NAME or not _AI_BASE_BRANCH:
        raise RuntimeError('No active AI manager branch to finalize.')

    branch_name = _AI_BRANCH_NAME
    base_branch = _AI_BASE_BRANCH
    approved = human_approval_gate()

    if not approved:
        _git('switch', base_branch)
        _git('branch', '-D', branch_name)
        print(f'[AI Manager] Changes rejected; deleted {branch_name}.')
        _AI_BRANCH_NAME = None
        _AI_BASE_BRANCH = None
        return False

    _git('add', '.')
    normalized_task = re.sub(r'\s+', ' ', task_description).strip()
    commit_message = f'AI Manager: {normalized_task}'
    _git('commit', '--allow-empty', '-m', commit_message[:200])
    _git('switch', base_branch)
    _git('merge', '--no-ff', branch_name, '-m', f'Merge {branch_name}')
    _git('branch', '-d', branch_name)
    print(f'[AI Manager] Approved changes merged into {base_branch}.')
    _AI_BRANCH_NAME = None
    _AI_BASE_BRANCH = None
    return True


def _rollback_ai_branch() -> None:
    """Return to the base branch and remove an uncommitted AI branch."""
    global _AI_BRANCH_NAME, _AI_BASE_BRANCH

    if not _AI_BRANCH_NAME or not _AI_BASE_BRANCH:
        return
    branch_name = _AI_BRANCH_NAME
    base_branch = _AI_BASE_BRANCH
    _git('switch', base_branch)
    _git('branch', '-D', branch_name)
    _AI_BRANCH_NAME = None
    _AI_BASE_BRANCH = None


def _safe_call_ollama(model: str, prompt: str) -> str:
    """Call local Ollama model using the official python library."""
    try:
        response = ollama.chat(
            model=model,
            messages=[{"role": "user", "content": prompt}]
        )
        return response["message"]["content"]
    except Exception as exc:
        # Fallback to Ollama CLI subprocess if SDK call encounters issues
        try:
            p = subprocess.run(
                ["ollama", "run", model, prompt],
                capture_output=True,
                text=True,
                timeout=90
            )
            if p.returncode == 0:
                return p.stdout.strip()
            return f"OLLAMA_CLI_ERROR: {p.stderr.strip()}"
        except Exception as sub_exc:
            return f"OLLAMA_ERROR: {exc} | SUBPROCESS_ERROR: {sub_exc}"


def _safe_call_genai(model: str, prompt: str) -> str:
    """Call Google GenAI SDK using official gemini-2.5-flash endpoint."""
    if not genai_client:
        return "GENAI_ERROR: GOOGLE_API_KEY is not configured in .env"
    try:
        response = genai_client.models.generate_content(
            model=model,
            contents=prompt
        )
        return response.text
    except Exception as exc:
        return f"GENAI_ERROR: {exc}"


def _collect_project_context() -> str:
    """Collect the existing project layout and integration points for the Architect."""
    project_root = Path(__file__).resolve().parent
    context_sections = []

    for directory_name in ('rapidcare_backend', 'rapidcare_app'):
        directory = project_root / directory_name
        if not directory.is_dir():
            context_sections.append(f'{directory_name}/ is missing from the repository root.')
            continue

        paths = sorted(
            path.relative_to(project_root).as_posix()
            for path in directory.rglob('*')
            if path.is_file() and '__pycache__' not in path.parts and '.dart_tool' not in path.parts
        )
        context_sections.append(f'Existing {directory_name}/ files:\n' + '\n'.join(f'- {path}' for path in paths))

        key_files = [
            path for path in paths
            if path in {
                'rapidcare_backend/models.py',
                'rapidcare_backend/app.py',
                'rapidcare_backend/__init__.py',
                'rapidcare_app/lib/main.dart',
            }
        ]
        for relative_path in key_files:
            source_path = project_root / relative_path
            try:
                source = source_path.read_text(encoding='utf-8')
            except OSError as exc:
                source = f'[Unable to read file: {exc}]'
            context_sections.append(f'Contents of {relative_path}:\n```\n{source}\n```')

    return '\n\n'.join(context_sections)


def architect_agent(feature_prompt: str) -> AgentResult:
    print("\n🤖 [Architect] Generating API blueprint and DB schema...")
    model = os.getenv("OLLAMA_ARCHITECT_MODEL", "llama3.2")
    existing_project_context = _collect_project_context()

    prompt = textwrap.dedent(f"""
    You are the System Architect for the RapidCare Flask and Flutter system.
    Feature request: {feature_prompt}

    Before generating any blueprint, schema, or code recommendation, inspect the existing project context below.
    Treat it as authoritative evidence of the active layout and conventions:
    {existing_project_context}

    Apply these non-negotiable architecture rules:
    - First scan the complete directory structures of both rapidcare_backend/ and rapidcare_app/ as listed above.
    - Read the existing model files, Flask app entry points, package initializers, API blueprints, and Flutter main/entry points before proposing changes.
    - Identify active SQLAlchemy schemas, package imports, route prefixes, blueprint registration, application-factory patterns, and Flutter service/widget conventions from the existing files.
    - Integrate with the established project layout. Do not invent a parallel application, package, or directory tree.
    - Never create redundant or shadow model files, such as a random models.py, schema.py, or model directory outside the active rapidcare_backend/models.py unless the repository context proves that location is already an established convention.
    - Append or modify the active model and entry-point files when required, and name the exact existing file path that owns each change.
    - Design a modular, production-ready file structure with clear ownership boundaries.
    - Explicitly list the existing directory tree and every file path that must be created or updated before defining schemas.
    - Use the existing backend layout where applicable, including rapidcare_backend/models.py, rapidcare_backend/api/, and rapidcare_backend/app.py.
    - Define a separate Flutter layout under rapidcare_app/lib/, including models/, services/ or api/, and screens/.
    - Keep database models, API blueprints, application initialization, configuration, Dart models, API services, widgets, and tests separated by responsibility.
    - Identify blueprint registration points, database initialization, environment variables, transaction boundaries, and frontend API configuration.
    - Specify platform-aware API base URL behavior: http://10.0.2.2:<port> for Android emulators and http://localhost:<port> for Flutter web and desktop.

    Produce:
    1) A file and directory structure section with exact relative paths for both rapidcare_backend/ and rapidcare_app/.
    2) An API specification (endpoints, methods, authentication, validation, and request/response JSON).
    3) SQLAlchemy database schema definitions, relationships, constraints, indexes, and transaction requirements.

    Return your output strictly as a JSON object with keys 'file_structure', 'api_spec', and 'db_schema'.
    """)

    resp = _safe_call_ollama(model, prompt)
    print("🤖 [Architect] Blueprint completed.")
    return AgentResult(success=True, content=resp)


def coder_agent(api_and_schema: str) -> AgentResult:
    print("\n🤖 [Coder] Writing Flask implementation code...")
    model = os.getenv("GENAI_CODER_MODEL", "gemini-2.5-flash")

    prompt = textwrap.dedent(f"""
    You are the Lead Developer for the RapidCare Flask backend.
    Convert the backend portion of the following blueprint into production Python Flask code.

    Follow these non-negotiable implementation rules:
    - Preserve the proposed backend file structure and place each responsibility in its exact path.
    - Return complete, drop-in file contents with explicit imports, Flask blueprint definitions, SQLAlchemy model definitions, database initialization, and application registration where required.
    - Implement every declared method, validation rule, error response, transaction boundary, and relationship; never emit stubs.
    - Do not use placeholder comments, TODOs, ellipses, pseudocode, empty methods, or omitted sections.
    - Read configuration from environment variables through the existing configuration boundary; do not hard-code secrets or deployment-specific credentials.
    - Ensure database writes are transactional and roll back on every handled failure path.
    - Keep app.py, models.py, API blueprints, configuration, and tests as separate files rather than combining unrelated concerns.
    - Use paths relative to the repository root, such as rapidcare_backend/models.py and rapidcare_backend/api/bed_allocation.py.

    Architect Specification:
    {api_and_schema}

        Return ONLY a valid JSON object mapping exact relative backend filenames to their full file string contents.
    Example:
    {{
            "rapidcare_backend/app.py": "from flask import Flask\\n...complete file...",
            "rapidcare_backend/models.py": "from flask_sqlalchemy import SQLAlchemy\\n...complete file..."
    }}
    """)

    resp = _safe_call_genai(model, prompt)
    print("🤖 [Coder] Code generated.")
    return AgentResult(success=True, content=resp)


def frontend_coder_agent(api_and_schema: str) -> AgentResult:
        print("\n🤖 [Coder] Writing Flutter and Dart frontend code...")
        model = os.getenv("GENAI_CODER_MODEL", "gemini-2.5-flash")

        prompt = textwrap.dedent(f"""
        You are the Lead Flutter Developer for RapidCare.
        Generate the production Flutter frontend for the API blueprint below.

        Follow these non-negotiable implementation rules:
        - Return complete Dart files in a strict modular structure: rapidcare_app/lib/models/, rapidcare_app/lib/services/ or rapidcare_app/lib/api/, and rapidcare_app/lib/screens/.
        - Generate typed model classes with explicit imports and JSON serialization using factory FromJson/toJson methods or an equivalent complete approach.
        - Match Dart JSON keys and nullability exactly to the Flask response payloads, including success, message, allocation, hospital_id, patient_id, bed_type, emergency_request_id, status, and allocated_at where applicable.
        - Generate an API service that uses platform-aware base URLs: 10.0.2.2 for Android emulators, localhost for web and desktop, and an injectable override for tests or deployments.
        - Use a supported Flutter HTTP client, explicit content-type and authorization headers, timeout handling, non-2xx error handling, and JSON decoding.
        - Generate at least one complete StatefulWidget screen that collects allocation input, submits it through the service, handles loading/success/error states, and never uses placeholder UI.
        - Do not use TODOs, placeholder comments, ellipses, pseudocode, empty methods, dynamic JSON without conversion, hard-coded secrets, or omitted code.
        - Keep models, API services, screens, and app wiring in separate files. Do not modify backend files in this phase.

        Architect Specification:
        {api_and_schema}

        Return ONLY a valid JSON object mapping exact relative Dart filenames to their complete file string contents.
        Example:
        {{
            "rapidcare_app/lib/models/bed_allocation.dart": "import 'dart:convert';\\n...complete Dart file...",
            "rapidcare_app/lib/services/api_service.dart": "import 'package:http/http.dart' as http;\\n...complete Dart file...",
            "rapidcare_app/lib/screens/bed_allocation_screen.dart": "import 'package:flutter/material.dart';\\n...complete StatefulWidget file..."
        }}
        """)

        resp = _safe_call_genai(model, prompt)
        print("🤖 [Coder] Flutter frontend generated.")
        return AgentResult(success=True, content=resp)


def auditor_agent(generated_files_json: str) -> AgentResult:
    print("\n🤖 [Auditor] Auditing backend and Flutter code for security & bugs...")
    model = os.getenv("OLLAMA_AUDITOR_MODEL", "deepseek-coder")

    prompt = textwrap.dedent(f"""
    You are the Security Auditor. Review these source files as a production Flask maintainer.

    Strictly audit all of the following:
    - Missing imports, undefined names, incomplete implementations, edge-case crashes, and resource leaks.
    - Environment variable loading, required-secret handling, unsafe defaults, credential exposure, and configuration separation.
    - Transactional safety for every database write, including rollback behavior on validation, integrity, and unexpected failures.
    - Race conditions around allocation/decrement operations, idempotency guarantees, constraints, and retry behavior.
    - Clean blueprint registration, route prefixes, application-factory integration, database initialization, and circular imports.
    - Authentication and authorization, input validation, response consistency, information disclosure, and injection risks.
    - Modularity and exact file-structure separation: models in model files, routes in blueprints, and startup wiring in app.py.
    - Flutter/Dart model serialization, exact Flask payload compatibility, platform-aware base URLs, HTTP timeouts, auth headers, and non-2xx error handling.

    Files:
    {generated_files_json}

    Provide an audit summary listing each finding with severity, exact filename, affected symbol or route, impact, and a concrete remediation.
    If no issue exists in a category, state that it was checked and passed.
    """)

    resp = _safe_call_ollama(model, prompt)
    print("🤖 [Auditor] Security audit complete.")
    return AgentResult(success=True, content=resp)


def repair_agent(code_json: str, audit_and_errors: str) -> AgentResult:
    print("\n🤖 [Repair] Patching issues and refactoring code...")
    model = os.getenv("REPAIR_MODEL", "gemini-2.5-flash")

    prompt = textwrap.dedent(f"""
    You are the Repair Agent. Fix the provided code using the auditor findings and execution error logs.

    Follow these strict repair rules:
    - Locate every finding in the exact relative file path and repair only the affected component.
    - Return a drop-in replacement containing the complete corrected contents of each affected file, never a partial snippet, diff, or pseudocode.
    - Preserve existing public APIs, unrelated modules, file structure, and behavior unless the reported issue requires a change.
    - Include all required imports and keep models, blueprints, configuration, and app initialization in their existing ownership boundaries.
    - Add or preserve environment-variable handling, transactional rollback behavior, validation, and idempotency required by the audit.
    - Do not rewrite unrelated components, rename files, move responsibilities, add TODOs, or leave placeholders.

    Current Code:
    {code_json}

    Auditor Report / Error Log:
    {audit_and_errors}

    Return ONLY a valid JSON mapping of exact relative filenames to corrected, complete file contents. Include only files that require changes.
    """)

    resp = _safe_call_genai(model, prompt)
    if resp.startswith("GENAI_ERROR"):
        print("⚠️ Gemini repair failed. Falling back to local Ollama...")
        resp = _safe_call_ollama("llama3.2", prompt)

    print("🤖 [Repair] Code patched.")
    return AgentResult(success=True, content=resp)


def tester_agent(files: Dict[str, str]) -> Tuple[bool, str]:
    print("\n🧪 [Tester] Executing Python and Dart structural syntax checks...")
    temp_dir = Path(tempfile.mkdtemp(prefix="rapidcare_test_"))
    try:
        for filename, content in files.items():
            relative_path = Path(filename)
            if relative_path.is_absolute() or '..' in relative_path.parts:
                return False, f"Unsafe generated file path: {filename}"
            target_file = temp_dir / relative_path
            target_file.parent.mkdir(parents=True, exist_ok=True)
            target_file.write_text(content, encoding="utf-8")

        python_files = list(temp_dir.rglob('*.py'))
        dart_files = list(temp_dir.rglob('*.dart'))
        if not python_files and not dart_files:
            return False, "No Python or Dart files found to test."

        if python_files:
            python_proc = subprocess.run(
                ["python", "-m", "py_compile", *[str(path) for path in python_files]],
                capture_output=True,
                text=True,
            )
            if python_proc.returncode != 0:
                print("🧪 [Tester] Fail - Python syntax errors detected.")
                return False, python_proc.stderr or python_proc.stdout

        dart_executable = shutil.which('dart')
        if dart_files and not dart_executable:
            return False, "Dart files found, but the dart executable is unavailable."
        for dart_file in dart_files:
            dart_proc = subprocess.run(
                [dart_executable, 'format', '--output=none', str(dart_file)],
                capture_output=True,
                text=True,
            )
            if dart_proc.returncode != 0:
                print("🧪 [Tester] Fail - Dart syntax errors detected.")
                return False, dart_proc.stderr or dart_proc.stdout

        print("🧪 [Tester] Pass - Python and Dart structural syntax checks passed!")
        return True, "Python and Dart syntax OK"
    except Exception as exc:
        return False, str(exc)
    finally:
        shutil.rmtree(temp_dir, ignore_errors=True)


def _parse_json_mapping(text: str) -> Dict[str, str]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        cleaned = re.sub(r"^```[a-zA-Z]*\n", "", cleaned)
        cleaned = cleaned.rstrip("`\n").strip()

    try:
        parsed = json.loads(cleaned)
        if isinstance(parsed, dict):
            if "files" in parsed and isinstance(parsed["files"], dict):
                return parsed["files"]
            return {k: (v if isinstance(v, str) else json.dumps(v)) for k, v in parsed.items()}
    except Exception:
        match = re.search(r"(\{(?:.|\n)*\})", cleaned)
        if match:
            try:
                parsed = json.loads(match.group(1))
                if isinstance(parsed, dict):
                    return {k: (v if isinstance(v, str) else json.dumps(v)) for k, v in parsed.items()}
            except Exception:
                pass

    return {"app.py": cleaned}


def manager_loop(feature_request: str, max_retries: int = 3) -> None:
    print(f"🚀 Starting Multi-Agent Pipeline for Task: '{feature_request}'")
    init_ai_branch(feature_request)

    arch_res = architect_agent(feature_request)
    coder_res = coder_agent(arch_res.content)
    current_files = _parse_json_mapping(coder_res.content)
    frontend_res = frontend_coder_agent(arch_res.content)
    current_files.update(_parse_json_mapping(frontend_res.content))

    auditor_res = auditor_agent(json.dumps(current_files))
    audit_report = auditor_res.content

    attempts = 0
    while True:
        success, output = tester_agent(current_files)
        if success:
            approved = finalize_ai_changes(feature_request)
            if not approved:
                print("\n❌ [Manager] Changes were rejected; temporary branch was removed.")
                break
            print("\n🎉 [Manager] Pipeline completed successfully!")
            print("\nGenerated Code Files:")
            for filename, body in current_files.items():
                print(f" 📄 {filename} ({len(body)} chars)")
            break

        attempts += 1
        if attempts > max_retries:
            _rollback_ai_branch()
            print(f"\n❌ [Manager] Failed after {max_retries} attempts.")
            print("Last Error:\n", output)
            break

        print(f"\n🔁 [Manager] Repair attempt {attempts}/{max_retries}...")
        repair_res = repair_agent(
            json.dumps(current_files),
            json.dumps({"audit_findings": audit_report, "test_error": output})
        )
        repaired_files = _parse_json_mapping(repair_res.content)
        current_files.update(repaired_files)


def main():
    parser = argparse.ArgumentParser(description="RapidCare Multi-Agent System")
    parser.add_argument(
        "--task",
        default="Build an emergency hospital bed allocation API route in Flask",
        help="Feature prompt to build"
    )
    parser.add_argument("--retries", type=int, default=3, help="Max repair retries")
    args = parser.parse_args()

    manager_loop(args.task, max_retries=args.retries)


if __name__ == "__main__":
    main()