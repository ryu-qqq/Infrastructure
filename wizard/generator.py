"""
Code Generator Module

Handles Jinja2 template rendering and file generation.
"""

import os
from pathlib import Path
from datetime import datetime
from typing import Dict, Any

from jinja2 import Environment, FileSystemLoader, Template
from rich.console import Console

console = Console()


class CodeGenerator:
    """Generate Terraform code from Jinja2 templates."""

    def __init__(self, project_root: Path):
        """
        Initialize code generator.

        Args:
            project_root: Path to project root directory
        """
        self.project_root = project_root
        self.templates_dir = project_root / "terraform" / "templates"

    def get_template_env(self, template_name: str) -> Environment:
        """
        Get Jinja2 environment for a template.

        Args:
            template_name: Name of template (e.g., 'ecs-service')

        Returns:
            Jinja2 Environment configured for the template
        """
        template_path = self.templates_dir / template_name

        if not template_path.exists():
            raise FileNotFoundError(f"Template not found: {template_name}")

        return Environment(
            loader=FileSystemLoader(str(template_path)),
            trim_blocks=True,
            lstrip_blocks=True,
            keep_trailing_newline=True
        )

    def render_template(self, template_file: str, env: Environment, context: Dict[str, Any]) -> str:
        """
        Render a Jinja2 template.

        Args:
            template_file: Template filename (e.g., 'main.tf.j2')
            env: Jinja2 environment
            context: Template context variables

        Returns:
            Rendered template content
        """
        template = env.get_template(template_file)
        return template.render(**context)

    def prepare_context(self, params: Dict[str, Any], components: Dict[str, Any]) -> Dict[str, Any]:
        """
        Prepare template context from parameters and components.

        Args:
            params: Required parameters
            components: Optional components

        Returns:
            Complete context dictionary for template rendering
        """
        context = {
            **params,
            **components,
            'generation_date': datetime.now().strftime('%Y-%m-%d'),
            'generation_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        }

        # Add component flags
        context['include_alb'] = components.get('load_balancer', False)
        context['database'] = components.get('database', 'none')
        context['cache'] = components.get('cache', 'none')
        context['storage'] = components.get('storage', 'none')

        return context

    def generate_code(
        self,
        template_name: str,
        params: Dict[str, Any],
        components: Dict[str, Any],
        output_dir: Path,
        dry_run: bool = False
    ) -> Dict[str, str]:
        """
        Generate Terraform code from template.

        Args:
            template_name: Template to use (e.g., 'ecs-service')
            params: Required parameters
            components: Optional components
            output_dir: Where to write generated files
            dry_run: If True, don't write files

        Returns:
            Dictionary mapping filenames to generated content
        """
        console.print(f"\n[bold]🔧 코드 생성 중...[/bold]")
        console.print(f"템플릿: {template_name}")
        console.print(f"출력 위치: {output_dir}")

        # Get Jinja2 environment
        env = self.get_template_env(template_name)

        # Prepare context
        context = self.prepare_context(params, components)

        # Get all template files
        template_path = self.templates_dir / template_name
        template_files = list(template_path.glob("*.j2"))

        if not template_files:
            raise FileNotFoundError(f"No .j2 template files found in {template_path}")

        generated_files = {}

        # Render each template
        for template_file in template_files:
            # Get output filename (remove .j2 extension)
            output_filename = template_file.stem

            console.print(f"  📄 렌더링: {output_filename}")

            try:
                # Render template
                content = self.render_template(template_file.name, env, context)

                # Skip empty files (conditional templates)
                if content.strip():
                    generated_files[output_filename] = content
                else:
                    console.print(f"    ⏭️  건너뛰기 (조건부 템플릿)")

            except Exception as e:
                console.print(f"    [red]❌ 오류: {str(e)}[/red]")
                raise

        # Write files
        if not dry_run:
            console.print(f"\n[bold]💾 파일 저장 중...[/bold]")

            # Create output directory
            output_dir.mkdir(parents=True, exist_ok=True)

            for filename, content in generated_files.items():
                file_path = output_dir / filename

                with open(file_path, 'w') as f:
                    f.write(content)

                console.print(f"  ✅ {filename}")

            console.print(f"\n[green]✅ {len(generated_files)}개 파일 생성 완료[/green]")
        else:
            console.print(f"\n[yellow]🔍 Dry-run 모드: 파일을 생성하지 않았습니다[/yellow]")
            console.print(f"생성될 파일: {len(generated_files)}개")
            for filename in generated_files.keys():
                console.print(f"  - {filename}")

        return generated_files

    def get_service_directory(self, service_name: str) -> Path:
        """
        Get the output directory for a service.

        Args:
            service_name: Service name

        Returns:
            Path to service directory
        """
        return self.project_root / "terraform" / "services" / service_name
