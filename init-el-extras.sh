#!/usr/bin/env sh

# Language servers and debuggers for init.el's extras
# (clojure, cobol, cpp, elixir, erlang, go, haskell, html, java, python, rust,
# scheme, typescript, zig).
# Runtimes come from mise's global tool set (mise.toml, installed by init.sh:
# java, clojure, go, python, node, rust, zig + zls); Fedora's own rust-analyzer
# package is used instead of `rustup component add` since mise's rust plugin
# doesn't expose rustup on PATH. Tree-sitter grammars are installed inside
# Emacs (M-x treesit-install-language-grammar).

# mise + local bin on PATH, so go/npm/mise resolve when piped into sh
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"

# cpp: clangd + gdb (gdb speaks DAP natively since 14.1). clangd lives in the
# clang-tools-extra subpackage on Fedora, not a standalone package.
sudo dnf install -y clang-tools-extra
sudo dnf install -y gdb

# rust/zig debugging: lldb-dap — the dape configs launch it by that name.
# Fedora's llvm-derived `lldb` package already ships /usr/bin/lldb-dap; the
# fallback symlink only kicks in if a future build only ships the
# version-suffixed lldb-dap-<N> binary.
sudo dnf install -y lldb
if ! command -v lldb-dap >/dev/null 2>&1; then
    set -- /usr/bin/lldb-dap-*
    [ -x "$1" ] && sudo ln -sf "$1" /usr/local/bin/lldb-dap
fi

# python: pylsp + debugpy for the system python (venv projects add their own
# debugpy). debugpy isn't packaged in Fedora's repos, so pip installs it.
# pip ignores the system trust store by default (bundles its own certifi CA
# file), unlike curl/dnf/go — init.sh's add-certs-pip.sh already points pip's
# own config at the system bundle before this script runs, if a Zscaler root
# CA is present.
sudo dnf install -y python3-lsp-server python3-pip
python3 -m pip install --user --upgrade debugpy

# clojure: clojure-lsp (CIDER itself needs only the JVM + lein, via mise)
command -v clojure-lsp >/dev/null 2>&1 || curl -fsSL https://raw.githubusercontent.com/clojure-lsp/clojure-lsp/master/install | sudo bash

# scheme: Guile (the geiser default) + Chez for SICP.
# Fedora's guile30 package only ships versioned binaries (guile3.0/guild3.0,
# no plain `guile` via update-alternatives), so symlink the unversioned names
# geiser-guile expects. Chez's Fedora package matches upstream exactly
# (/usr/bin/scheme), which is also geiser-chez-binary's own default — no
# override needed here, unlike distros that rename it to `chezscheme`.
sudo dnf install -y guile30 chez-scheme
mkdir -p "$HOME/.local/bin"
ln -sf /usr/bin/guile3.0 "$HOME/.local/bin/guile"
ln -sf /usr/bin/guild3.0 "$HOME/.local/bin/guild"

# elixir / erlang (BEAM): runtimes come from mise.toml via init.sh (which also
# installs the OTP build deps erlang needs to compile); the erl/elixir shims
# are already on PATH above.

# elixir: ElixirLS — its `language_server.sh' (found by eglot) and
# `debug_adapter.sh' (used by extras/elixir.el's dape config) go on PATH via
# ~/.local/bin. The release zip is flat, so it unzips straight into
# ~/.local/share/elixir-ls; guarded like jdtls — remove that dir to re-pull.
sudo dnf install -y unzip
mkdir -p "$HOME/.local/share/elixir-ls" "$HOME/.local/bin"
if [ ! -x "$HOME/.local/share/elixir-ls/language_server.sh" ]; then
    curl -fsSL "$(curl -fsSL https://api.github.com/repos/elixir-lsp/elixir-ls/releases/latest | grep -o 'https://[^"]*elixir-ls-v[^"]*\.zip' | head -n 1)" -o "$HOME/.local/share/elixir-ls/elixir-ls.zip"
    unzip -q -o "$HOME/.local/share/elixir-ls/elixir-ls.zip" -d "$HOME/.local/share/elixir-ls"
    rm -f "$HOME/.local/share/elixir-ls/elixir-ls.zip"
    chmod +x "$HOME/.local/share/elixir-ls/language_server.sh" "$HOME/.local/share/elixir-ls/debug_adapter.sh"
fi
ln -sf "$HOME/.local/share/elixir-ls/language_server.sh" "$HOME/.local/bin/language_server.sh"
ln -sf "$HOME/.local/share/elixir-ls/debug_adapter.sh" "$HOME/.local/bin/debug_adapter.sh"

# erlang: erlang_ls — prebuilt binary matched to the installed OTP major (the
# release ships one per OTP 24-27) into ~/.local/bin; fall back to the newest
# linux build if that major isn't published yet. Not packaged in Fedora repos.
if [ ! -x "$HOME/.local/bin/erlang_ls" ] && ! command -v erlang_ls >/dev/null 2>&1; then
    OTP=$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)])' -s init stop 2>/dev/null | tr -dc 0-9)
    ELS_RELEASES=$(curl -fsSL https://api.github.com/repos/erlang-ls/erlang_ls/releases/latest)
    ELS_URL=$(printf '%s' "$ELS_RELEASES" | grep -o "https://[^\"]*erlang_ls-linux-${OTP}\.tar\.gz" | head -n 1)
    [ -n "$ELS_URL" ] || ELS_URL=$(printf '%s' "$ELS_RELEASES" | grep -o 'https://[^"]*erlang_ls-linux-[0-9]*\.tar\.gz' | sort -V | tail -n 1)
    [ -n "$ELS_URL" ] && curl -fsSL "$ELS_URL" | tar -xz -C "$HOME/.local/bin"
fi

# go: gopls + delve, installed to ~/go/bin (add it to PATH if not already there)
go install golang.org/x/tools/gopls@latest
go install github.com/go-delve/delve/cmd/dlv@latest

# java: jdtls (Eclipse JDT language server) + the java-debug plugin jar that
# extras/java.el loads into it for dape debugging. Both are guarded:
# re-extracting a newer jdtls snapshot (or re-downloading a newer plugin) over
# an old one leaves two versions of the same bundles side by side.
mkdir -p "$HOME/.local/share/jdtls" "$HOME/.local/share/java-debug" "$HOME/.local/bin"
[ -x "$HOME/.local/share/jdtls/bin/jdtls" ] || curl -fsSL https://download.eclipse.org/jdtls/snapshots/jdt-language-server-latest.tar.gz | tar -xz -C "$HOME/.local/share/jdtls"
ln -sf "$HOME/.local/share/jdtls/bin/jdtls" "$HOME/.local/bin/jdtls"
if ! ls "$HOME"/.local/share/java-debug/com.microsoft.java.debug.plugin-*.jar >/dev/null 2>&1; then
    JAVA_DEBUG_VERSION=$(curl -fsSL https://repo1.maven.org/maven2/com/microsoft/java/com.microsoft.java.debug.plugin/maven-metadata.xml | grep -o '<latest>[^<]*' | cut -d '>' -f 2)
    curl -fsSL "https://repo1.maven.org/maven2/com/microsoft/java/com.microsoft.java.debug.plugin/$JAVA_DEBUG_VERSION/com.microsoft.java.debug.plugin-$JAVA_DEBUG_VERSION.jar" -o "$HOME/.local/share/java-debug/com.microsoft.java.debug.plugin-$JAVA_DEBUG_VERSION.jar"
fi

# rust: rust-analyzer is its own Fedora package — no rustup needed, unlike
# distros where `rustup component add rust-analyzer` is the documented route.
sudo dnf install -y rust-analyzer

# typescript: the language server + the vscode-js-debug adapter dape looks for
# in ~/.config/emacs/debug-adapters/js-debug
npm install -g typescript typescript-language-server
mkdir -p "$HOME/.config/emacs/debug-adapters"
[ -d "$HOME/.config/emacs/debug-adapters/js-debug" ] || curl -fsSL "$(curl -fsSL https://api.github.com/repos/microsoft/vscode-js-debug/releases/latest | grep -o 'https://[^"]*js-debug-dap[^"]*\.tar\.gz' | head -n 1)" | tar -xz -C "$HOME/.config/emacs/debug-adapters"

# html/css: both language servers ship in one npm package — eglot's built-in
# table already maps html-mode to vscode-html-language-server and css-mode /
# css-ts-mode to vscode-css-language-server, so nothing else is wired.
npm install -g vscode-langservers-extracted

# cobol: GnuCOBOL's cobc/cobcrun. Fedora splits the compiler (`gnucobol`, cobc)
# from the runtime (`libcob`, cobcrun) — gnucobol depends on libcob, so
# installing it alone pulls cobcrun in too.
sudo dnf install -y gnucobol

# cobol LSP: superbol-free is NOT installed here, because it is packaged
# nowhere — not on opam, the 1.0.0 release ships no binaries, and the VSIX
# bundles the server as JavaScript rather than a native binary. Building it
# means an OCaml 4.14.2 opam switch (`sudo dnf install -y opam` on Fedora),
# which does not belong in an unattended bootstrap; the recipe is in this
# repo's README. Nothing breaks until you run it: extras/cobol.el checks
# `executable-find' at buffer-open time, so COBOL editing stays quiet and
# compiler-only, then picks up the server with no edit.

# haskell: also not automated. haskell-language-server isn't in Fedora's
# repos either, and the documented installer pulls an entire GHC toolchain, so
# run it yourself when you want the layer:
#   curl -fsSL https://get-ghcup.haskell.org | \
#     BOOTSTRAP_HASKELL_NONINTERACTIVE=1 BOOTSTRAP_HASKELL_INSTALL_HLS=1 sh
# extras/haskell.el then needs nothing more — eglot's built-in table already
# maps haskell-mode to `haskell-language-server-wrapper --lsp'.

# zig: compiler + zls come from mise.toml via init.sh

