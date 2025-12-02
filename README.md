# claude-review.nvim

Neovim plugin that integrates Claude Code CLI for code review with native diagnostics.

## Requirements

- Neovim >= 0.8
- [Claude Code CLI](https://github.com/anthropics/claude-code) installed and in PATH
- Git (for diff review)

## Installation

### lazy.nvim

```lua
{
  "claude-review.nvim",
  dir = "/Users/james/pro/lua/cc-review/claude-review.nvim",
  config = function()
    require("claude-review").setup({
      -- enable_code_actions = true, -- default: true, integrates with vim.lsp.buf.code_action()
    })
  end,
}
```

### packer.nvim

```lua
use {
  "/Users/james/pro/lua/cc-review/claude-review.nvim",
  config = function()
    require("claude-review").setup()
  end,
}
```

## Usage

### Commands

- `:ClaudeReview` - Review current buffer
- `:ClaudeReviewDiff [ref]` - Review diff from git ref (default: HEAD)
- `:ClaudeReviewDismiss` - Dismiss diagnostic at cursor
- `:ClaudeReviewDismissBuffer` - Clear all diagnostics in current buffer
- `:ClaudeReviewDismissAll` - Clear all diagnostics across all buffers
- `:ClaudeReviewApplyFix` - Apply suggested fix at cursor
- `:ClaudeReviewPreviewFix` - Preview suggested fix at cursor
- `:ClaudeReviewDebug` - Toggle debug sidebar showing request/response

### Navigation

Use Neovim's built-in diagnostic navigation:
- `]d` - Next diagnostic
- `[d` - Previous diagnostic

### Example Workflow

```vim
" Review current file
:ClaudeReview

" Review changes since main branch
:ClaudeReviewDiff main

" Navigate to diagnostic
]d

" Apply fix using code actions (recommended)
:lua vim.lsp.buf.code_action()

" Or apply fix directly
:ClaudeReviewApplyFix

" Preview what the fix will do
:ClaudeReviewPreviewFix

" Dismiss diagnostic at cursor
:ClaudeReviewDismiss

" Clear all diagnostics
:ClaudeReviewDismissAll
```

### Key Mappings (optional)

Add to your config:

```lua
vim.keymap.set("n", "<leader>cr", "<cmd>ClaudeReview<cr>", { desc = "Claude review" })
vim.keymap.set("n", "<leader>cd", "<cmd>ClaudeReviewDiff<cr>", { desc = "Claude review diff" })
vim.keymap.set("n", "<leader>cx", "<cmd>ClaudeReviewDismiss<cr>", { desc = "Dismiss diagnostic" })
vim.keymap.set("n", "<leader>ca", "<cmd>ClaudeReviewApplyFix<cr>", { desc = "Apply fix" })
vim.keymap.set("n", "<leader>cp", "<cmd>ClaudeReviewPreviewFix<cr>", { desc = "Preview fix" })
vim.keymap.set("n", "<leader>cD", "<cmd>ClaudeReviewDebug<cr>", { desc = "Toggle debug sidebar" })
```

## How It Works

1. Plugin passes file path to Claude Code CLI with structured prompt
2. Claude reads the file directly and analyzes it
3. Response is parsed for JSON diagnostic format
4. Diagnostics are set using `vim.diagnostic` API
5. Navigate with standard Neovim diagnostic commands

## Configuration

Currently auto-configures on load. Future options may include:
- Custom severity mappings
- Custom review prompts
- Additional review modes
