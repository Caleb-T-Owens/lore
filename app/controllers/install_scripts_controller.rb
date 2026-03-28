class InstallScriptsController < ApplicationController
  def show
    render plain: install_script, content_type: "application/x-sh"
  end

  private

  def install_script
    cli_body = File.read(Rails.root.join("bin", "lore")).sub(
      /^LORE_HOST_DEFAULT=.*$/,
      %(LORE_HOST_DEFAULT="${LORE_HOST:-#{Lore::Application.config.x.lore.host}}")
    )

    <<~SCRIPT
      #!/usr/bin/env bash
      set -euo pipefail

      install_dir="${HOME}/.local/bin"
      target_path="${install_dir}/lore"

      mkdir -p "$install_dir"
      cat > "$target_path" <<'__LORE_CLI__'
      #{cli_body}__LORE_CLI__
      chmod +x "$target_path"

      printf 'Installed lore to %s\n' "$target_path"
      case ":${PATH}:" in
        *":${install_dir}:"*) ;;
        *) printf 'Add %s to PATH if it is not already available.\n' "$install_dir" ;;
      esac
    SCRIPT
  end
end
