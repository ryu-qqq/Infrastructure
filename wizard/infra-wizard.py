#!/usr/bin/env python3
"""
Infrastructure Wizard - Automated Terraform Code Generator

This wizard helps generate infrastructure code following company standards.
It creates Terraform configurations, updates atlantis.yaml, and creates PRs.

Usage:
    ./wizard/infra-wizard.py
    python3 wizard/infra-wizard.py

Author: Platform Team
License: Internal Use Only
"""

import sys
import os
import json
from pathlib import Path
from datetime import datetime

import click
from rich.console import Console
from rich.panel import Panel
from rich.table import Table
from rich import print as rprint

# Import wizard modules
from generator import CodeGenerator
from atlantis_updater import AtlantisUpdater
from git_helper import GitHelper

# Initialize Rich console
console = Console()


def get_project_root():
    """Get the project root directory."""
    return Path(__file__).parent.parent.absolute()


def load_template_metadata(template_name):
    """Load metadata.json for a template."""
    metadata_path = get_project_root() / "terraform" / "templates" / template_name / "metadata.json"

    if not metadata_path.exists():
        console.print(f"[red]❌ Template not found: {template_name}[/red]")
        sys.exit(1)

    with open(metadata_path, 'r') as f:
        return json.load(f)


def print_banner():
    """Print wizard banner."""
    banner = """
🔧 Infrastructure Wizard
========================
Automated Terraform code generator for company infrastructure standards
"""
    console.print(Panel(banner, style="bold blue"))


def select_template():
    """Let user select which template to use."""
    templates_dir = get_project_root() / "terraform" / "templates"

    if not templates_dir.exists():
        console.print("[red]❌ Templates directory not found[/red]")
        sys.exit(1)

    # Get available templates
    templates = [d.name for d in templates_dir.iterdir() if d.is_dir()]

    if not templates:
        console.print("[red]❌ No templates found[/red]")
        sys.exit(1)

    # Display available templates
    table = Table(title="Available Templates")
    table.add_column("#", style="cyan")
    table.add_column("Template", style="green")
    table.add_column("Description", style="white")

    for idx, template in enumerate(templates, 1):
        metadata = load_template_metadata(template)
        table.add_row(str(idx), template, metadata.get('description', 'No description'))

    console.print(table)

    # Get user selection
    while True:
        try:
            choice = click.prompt("\n선택 (번호 입력)", type=int)
            if 1 <= choice <= len(templates):
                return templates[choice - 1]
            console.print("[red]❌ 잘못된 번호입니다[/red]")
        except (ValueError, click.exceptions.Abort):
            console.print("[red]❌ 잘못된 입력입니다[/red]")
            sys.exit(1)


def collect_parameters(metadata):
    """Collect required and optional parameters from user."""
    params = {}

    console.print("\n[bold]📋 필수 파라미터 입력[/bold]\n")

    # Required parameters
    for param in metadata['required_parameters']:
        name = param['name']
        param_type = param['type']
        description = param.get('description', '')
        default = param.get('default')

        if param_type == 'select':
            # Choice from options
            options = param['options']
            console.print(f"\n{description}")
            for idx, option in enumerate(options, 1):
                marker = " (기본값)" if option == default else ""
                console.print(f"  {idx}) {option}{marker}")

            while True:
                choice_input = click.prompt(
                    f"{name}",
                    default=str(options.index(default) + 1) if default else "",
                    show_default=True
                )
                try:
                    choice_idx = int(choice_input) - 1
                    if 0 <= choice_idx < len(options):
                        params[name] = options[choice_idx]
                        break
                except ValueError:
                    pass
                console.print("[red]❌ 잘못된 선택입니다[/red]")

        elif param_type == 'number':
            params[name] = click.prompt(
                f"{name} ({description})",
                type=int,
                default=default,
                show_default=True
            )

        else:  # string
            value = click.prompt(
                f"{name} ({description})",
                default=default if default else "",
                show_default=bool(default)
            )

            # Validation
            if 'validation' in param:
                import re
                if not re.match(param['validation'], value):
                    console.print(f"[red]❌ 잘못된 형식입니다. 패턴: {param['validation']}[/red]")
                    sys.exit(1)

            params[name] = value

    return params


def collect_optional_components(metadata):
    """Collect optional component choices from user."""
    components = {}

    if 'optional_components' not in metadata:
        return components

    console.print("\n[bold]🔧 선택적 컴포넌트 구성[/bold]\n")

    for component_key, component_config in metadata['optional_components'].items():
        if component_config['type'] == 'boolean':
            # Simple yes/no question
            answer = click.confirm(
                component_config.get('question', f"{component_key} 필요하신가요?"),
                default=component_config.get('default', False)
            )
            components[component_key] = answer

        elif component_config['type'] == 'choice':
            # Multiple choice
            console.print(f"\n{component_config.get('question', component_key)}")

            options = component_config['options']
            for idx, option in enumerate(options, 1):
                label = option['label']
                desc = option.get('description', '')
                cost = option.get('cost_impact', '')
                cost_str = f" (비용: {cost})" if cost else ""
                console.print(f"  {idx}) {label}{cost_str}")
                if desc:
                    console.print(f"      → {desc}")

            while True:
                choice_input = click.prompt(f"\n선택 (1-{len(options)})", type=int)
                if 1 <= choice_input <= len(options):
                    selected_option = options[choice_input - 1]
                    components[component_key] = selected_option['value']

                    # Collect additional parameters if needed
                    if 'additional_parameters' in selected_option:
                        console.print(f"\n[yellow]📝 {selected_option['label']} 추가 설정[/yellow]")
                        # TODO: Implement additional parameter collection

                    break
                console.print("[red]❌ 잘못된 선택입니다[/red]")

    return components


def display_summary(template_name, params, components):
    """Display configuration summary."""
    console.print("\n[bold]📊 생성 요약[/bold]\n")

    # Service info
    table = Table(title="서비스 정보")
    table.add_column("항목", style="cyan")
    table.add_column("값", style="green")

    for key, value in params.items():
        table.add_row(key, str(value))

    console.print(table)

    # Components
    if components:
        comp_table = Table(title="선택된 컴포넌트")
        comp_table.add_column("컴포넌트", style="cyan")
        comp_table.add_column("설정", style="green")

        for key, value in components.items():
            comp_table.add_row(key, str(value))

        console.print(comp_table)

    # Confirm
    if not click.confirm("\n계속하시겠습니까?", default=True):
        console.print("[yellow]⚠️  위자드를 취소했습니다.[/yellow]")
        sys.exit(0)


@click.command()
@click.option('--template', help='Template name to use')
@click.option('--dry-run', is_flag=True, help='Show what would be generated without creating files')
@click.option('--no-pr', is_flag=True, help='Skip PR creation (only generate code and commit)')
def main(template, dry_run, no_pr):
    """Infrastructure Wizard - Generate Terraform code automatically."""

    try:
        # Print banner
        print_banner()

        # Get project root
        project_root = get_project_root()

        # Initialize helpers
        generator = CodeGenerator(project_root)
        atlantis_updater = AtlantisUpdater(project_root / "atlantis.yaml")
        git_helper = GitHelper(project_root)

        # Select template
        if not template:
            template_name = select_template()
        else:
            template_name = template

        console.print(f"\n✅ 템플릿 선택: [green]{template_name}[/green]\n")

        # Load template metadata
        metadata = load_template_metadata(template_name)

        # Collect parameters
        params = collect_parameters(metadata)

        # Collect optional components
        components = collect_optional_components(metadata)

        # Display summary
        display_summary(template_name, params, components)

        # Get service details
        service_name = params.get('service_name')
        environment = params.get('environment', 'prod')

        # Generate output directory path
        output_dir = generator.get_service_directory(service_name)
        service_dir = f"terraform/services/{service_name}"

        # Step 1: Generate Terraform code
        console.print(f"\n[bold cyan]{'='*60}[/bold cyan]")
        console.print(f"[bold cyan]Step 1/4: 코드 생성[/bold cyan]")
        console.print(f"[bold cyan]{'='*60}[/bold cyan]")

        generated_files = generator.generate_code(
            template_name=template_name,
            params=params,
            components=components,
            output_dir=output_dir,
            dry_run=dry_run
        )

        # Step 2: Update atlantis.yaml
        console.print(f"\n[bold cyan]{'='*60}[/bold cyan]")
        console.print(f"[bold cyan]Step 2/4: atlantis.yaml 업데이트[/bold cyan]")
        console.print(f"[bold cyan]{'='*60}[/bold cyan]")

        atlantis_updated = atlantis_updater.add_service(
            service_name=service_name,
            service_dir=service_dir,
            environment=environment,
            dry_run=dry_run
        )

        if not dry_run:
            # Step 3: Create Git branch and commit
            console.print(f"\n[bold cyan]{'='*60}[/bold cyan]")
            console.print(f"[bold cyan]Step 3/4: Git 커밋[/bold cyan]")
            console.print(f"[bold cyan]{'='*60}[/bold cyan]")

            # Create feature branch
            branch_name = git_helper.create_feature_branch(service_name)

            # Stage files
            files_to_stage = [
                output_dir / filename for filename in generated_files.keys()
            ]
            files_to_stage.append(project_root / "atlantis.yaml")

            git_helper.stage_files(files_to_stage)

            # Create commit
            git_helper.create_commit(
                service_name=service_name,
                service_dir=service_dir,
                components=components,
                dry_run=False
            )

            # Step 4: Create PR (optional)
            if not no_pr:
                console.print(f"\n[bold cyan]{'='*60}[/bold cyan]")
                console.print(f"[bold cyan]Step 4/4: GitHub PR 생성[/bold cyan]")
                console.print(f"[bold cyan]{'='*60}[/bold cyan]")

                pr_url = git_helper.create_pr_with_gh(
                    service_name=service_name,
                    components=components,
                    base_branch="main",
                    dry_run=False
                )

                # Final summary
                console.print(f"\n[bold green]{'='*60}[/bold green]")
                console.print(f"[bold green]✅ 위자드 완료![/bold green]")
                console.print(f"[bold green]{'='*60}[/bold green]")

                console.print(f"\n[bold]생성된 리소스:[/bold]")
                console.print(f"  📁 디렉토리: {service_dir}/")
                console.print(f"  📄 파일: {len(generated_files)}개")
                console.print(f"  🔀 브랜치: {branch_name}")

                if pr_url:
                    console.print(f"\n[bold cyan]🚀 다음 단계:[/bold cyan]")
                    console.print(f"  1. PR 열기: {pr_url}")
                    console.print(f"  2. Atlantis plan 결과 확인 (1-2분 소요)")
                    console.print(f"  3. 플랜 검토 후 PR 승인")
                    console.print(f"  4. 머지 → Atlantis가 자동으로 apply")
                else:
                    console.print(f"\n[yellow]⚠️  PR 자동 생성 실패 - 수동으로 생성해주세요[/yellow]")
                    console.print(f"  브랜치: {branch_name}")

            else:
                console.print(f"\n[bold green]✅ 코드 생성 및 커밋 완료![/bold green]")
                console.print(f"  브랜치: {branch_name}")
                console.print(f"\n[yellow]--no-pr 옵션: PR을 수동으로 생성해주세요[/yellow]")

        else:
            console.print("\n[yellow]🔍 --dry-run 모드: 실제 파일을 생성하지 않았습니다[/yellow]")
            console.print(f"\n생성될 위치: {service_dir}/")
            console.print(f"생성될 파일: {len(generated_files)}개")

        console.print("\n")

    except KeyboardInterrupt:
        console.print("\n\n[yellow]⚠️  사용자가 취소했습니다.[/yellow]")
        sys.exit(0)
    except Exception as e:
        console.print(f"\n[red]❌ 오류 발생: {str(e)}[/red]")
        if '--debug' in sys.argv:
            raise
        sys.exit(1)


if __name__ == '__main__':
    main()
